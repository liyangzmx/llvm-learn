#!/usr/bin/env python3
"""Check extraction coverage and Markdown integrity; does not compile LLVM/IR."""
from pathlib import Path
import hashlib
import json
import re
import sys

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / 'origin/manifest.json').read_text())
errors = []
warnings = []
seen = []
counts = {}
# Independent transcription of the printed table of contents (PDF 10-13).
TOC = {
    1: (5, {}), 2: (4, {1: 3, 2: 2, 3: 5}),
    3: (5, {1: 3, 2: 2, 3: 3}), 4: (4, {1: 2, 2: 3, 3: 2}),
    5: (3, {2: 2}), 6: (4, {1: 2, 2: 2, 3: 3}),
    7: (5, {2: 5, 4: 6}),
    8: (12, {1: 2, 2: 2, 3: 3, 4: 3, 7: 6, 8: 2, 10: 2}),
    9: (11, {1: 3}),
    10: (9, {1: 2, 2: 15, 3: 2, 4: 2, 5: 5, 6: 5}),
    11: (6, {1: 3, 2: 3, 4: 4, 5: 2}), 12: (3, {2: 2}),
    13: (3, {1: 4, 2: 5}),
}

assert hashlib.sha256((ROOT / manifest['source']).read_bytes()).hexdigest() == manifest['sha256'], 'Source PDF changed'
for section in manifest['sections']:
    origin = ROOT / 'origin' / section['file']
    source = origin.read_text()
    pages = [int(n) for n in re.findall(r'<!-- PDF page (\d+);', source)]
    expected = list(range(section['pdf_start'], section['pdf_end'] + 1))
    if pages != expected:
        errors.append(f'{origin.name}: page markers {pages} != {expected}')
    seen += pages
    key = section['key']
    if re.fullmatch(r'ch\d+|appendix-[abc]', key):
        revised = ROOT / section['file']
        record = ROOT / 'review' / f'{key}.md'
        if not revised.exists() or not record.exists():
            errors.append(f'{key}: missing corrected chapter or review record')
            continue
        target = revised.read_text()
        source_sections = set(re.findall(r'^#{2,4} ((?:\d+|[ABC])\.\d+(?:\.\d+)?)\b', source, re.M))
        target_sections = set(re.findall(r'^#{2,4} ((?:\d+|[ABC])\.\d+(?:\.\d+)?)\b', target, re.M))
        if key.startswith('ch'):
            n = int(key[2:])
            main_count, children = TOC[n]
            toc_sections = {f'{n}.{i}' for i in range(1, main_count + 1)}
            toc_sections.update(f'{n}.{i}.{j}' for i, count in children.items() for j in range(1, count + 1))
            for kind, sections in [('original', source_sections), ('corrected', target_sections)]:
                if toc_sections - sections:
                    errors.append(f'{key}: {kind} missing printed TOC sections {sorted(toc_sections - sections)}')
        if source_sections - target_sections:
            errors.append(f'{key}: missing section headings {sorted(source_sections - target_sections)}')
        listings = lambda text: set(re.findall(r'代码清单\s*([\dABC]+[-－–]\d+)', text))
        # All references also count, so this is a preservation check, not a claim
        # of semantic validation or proof that a listing was executed.
        prefix = key[2:] if key.startswith('ch') else key[-1].upper()
        own = lambda values: {value for value in values if re.match(re.escape(prefix) + r'[-－–]', value)}
        original_listings = own(listings(source))
        revised_listings = own(listings(target))
        missing = original_listings - revised_listings
        if missing:
            errors.append(f'{key}: missing listing identifiers {sorted(missing)}')
        counts[key] = {'section_headings': len(target_sections), 'listing_identifiers': len(original_listings), 'source_chars': len(source), 'corrected_chars': len(target)}
        # The revised chapters are now independently authored teaching material.
        # Keep topic/listing coverage checks, but do not require the length of the
        # original prose or historical dumps to survive an authorized rewrite.
if seen != list(range(1, manifest['page_count'] + 1)):
    errors.append('PDF page coverage is not exactly 1..435')

documents = (list(ROOT.glob('*.md')) + list((ROOT / 'origin').glob('*.md'))
             + list((ROOT / 'review').glob('*.md')) + list((ROOT / 'experiments').rglob('*.md')))
links = 0
images = set()
for document in documents:
    text = document.read_text()
    if '\ufffd' in text:
        warnings.append(f'{document.name}: replacement glyph present; compare source image')
    inside = False
    for line in text.splitlines():
        if re.match(r'^\s*```', line):
            inside = not inside
    if inside:
        errors.append(f'{document.name}: unclosed code fence')
    if text.count('<details>') != text.count('</details>'):
        errors.append(f'{document.name}: unbalanced details tags')
    text_without_code = re.sub(r'^```[^\n]*\n.*?^```\s*$', '', text, flags=re.M | re.S)
    for match in re.finditer(r'(!?)\[[^\]\n]*\]\((<?[^\n]*?>?)\)', text_without_code):
        image, target = match.groups()
        target = target.strip('<>')
        if re.match(r'[a-z]+://|^#|^mailto:', target):
            continue
        target = target.split('#')[0]
        target = re.sub(r':\d+$', '', target)
        path = Path(target) if target.startswith('/') else document.parent / target
        links += 1
        if not path.exists():
            errors.append(f'{document.relative_to(ROOT)}: missing link {target}')
        elif image:
            images.add(path.resolve())
for path in images:
    try:
        with Image.open(path) as im:
            if im.width <= 0 or im.height <= 0:
                errors.append(f'{path.name}: empty image')
            im.verify()
    except Exception as exc:
        errors.append(f'{path.name}: invalid image: {exc}')

report = {'pdf_pages': len(seen), 'documents_checked': len(documents), 'local_links_checked': links, 'linked_images_checked': len(images), 'chapters': counts, 'errors': errors, 'warnings': warnings, 'scope': 'Structural checks only. No LLVM build, IR parsing/execution, or semantic test was run.'}
(ROOT / 'review/validation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(report, ensure_ascii=False, indent=2))
sys.exit(bool(errors))
