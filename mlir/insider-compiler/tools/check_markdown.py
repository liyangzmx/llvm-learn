#!/usr/bin/env python3
"""Check chapter page coverage, fences and local links; does not claim semantic QA."""
import html
import json
import re
import sys
from pathlib import Path
import unicodedata
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / "ocr/manifest.json").read_text())
errors = []
report = []
EXPECTED_LISTINGS = {1: 8, 2: 2, 3: 37, 4: 19, 5: 17, 6: 14, 7: 17, 8: 2, 9: 40, 10: 20, 11: 14, 12: 12, 13: 59, 14: 13, 15: 0}
EXPECTED_FIGURES = {1: 4, 2: 1, 3: 8, 4: 2, 5: 2, 6: 4, 7: 4, 8: 1, 9: 9, 10: 10, 11: 7, 12: 2, 13: 6, 14: 1, 15: 3}
EXPECTED_TABLES = {3: 1, 6: 1, 9: 2, 11: 1, 13: 13, 14: 10, 15: 5}
EXPECTED_FOOTNOTES = {14: 5, 15: 7}
EXPECTED_NOTICES = {14: 13, 15: 5}


def prose(content):
    """Omit fenced examples before inspecting document links and headings."""
    fence = None
    lines = []
    for line in content.splitlines():
        match = re.match(r"^(`{3,}|~{3,})(.*)$", line)
        if match:
            delimiter, info = match.groups()
            if fence is None:
                fence = (delimiter[0], len(delimiter))
            elif delimiter[0] == fence[0] and len(delimiter) >= fence[1] and not info.strip():
                fence = None
            continue
        if fence is None:
            lines.append(line)
    return "\n".join(lines)


def anchors(content):
    """Collect explicit anchors and the ordinary GitHub heading IDs used here."""
    content = prose(content)
    ids = set(re.findall(r'<(?:a|h[1-6])\b[^>]*\b(?:id|name)=["\']([^"\']+)', content))
    duplicates = {}
    for heading in re.findall(r"^#{1,6}\s+(.+?)\s*#*\s*$", content, re.M):
        heading = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", heading)
        heading = html.unescape(re.sub(r"<[^>]*>", "", heading)).lower()
        slug = "".join(c for c in heading if c in "-_" or not unicodedata.category(c).startswith(("P", "S")))
        slug = re.sub(r"\s", "-", slug)
        count = duplicates.get(slug, 0)
        duplicates[slug] = count + 1
        ids.add(f"{slug}-{count}" if count else slug)
    return ids


for chapter, source in manifest["chapters"].items():
    file = ROOT / f"insider-compiler-ch{chapter}.md"
    if source is None:
        report.append({"chapter": int(chapter), "status": "missing_source"})
        continue
    if not file.exists():
        errors.append(f"Missing chapter: {file.name}")
        continue
    errors_before = len(errors)
    content = file.read_text()
    markers = re.findall(r"<!-- source: ([^,]+), PDF p\. (\d+) -->", content)
    pages = [int(page) for pdf, page in markers if pdf == source["source"]]
    expected = list(range(source["pdf_pages"][0], source["pdf_pages"][1] + 1))
    if pages != expected:
        errors.append(f"{file.name}: page markers {pages}; expected {expected}")
    if any(pdf != source["source"] for pdf, page in markers):
        errors.append(f"{file.name}: unexpected source PDF in marker")
    fence = None
    languages = []
    body_lines = []
    for n, line in enumerate(content.splitlines(), 1):
        match = re.match(r"^(`{3,}|~{3,})(.*)$", line)
        if match:
            delimiter, info = match.groups()
            if fence is None:
                fence = (delimiter[0], len(delimiter), n)
                languages.append(info.strip())
            elif delimiter[0] == fence[0] and len(delimiter) >= fence[1] and not info.strip():
                fence = None
            continue
        if fence is None:
            body_lines.append(line)
    if fence:
        errors.append(f"{file.name}: unclosed code fence from line {fence[2]}")
    chapter_number = int(chapter)
    listings = sorted({int(n) for n in re.findall(r"^\*\*代码清单\s*" + chapter + r"-(\d+)", content, re.M)})
    figures = sorted({int(n) for n in re.findall(r"^\*\*图\s*" + chapter + r"-(\d+)", content, re.M)})
    for label, numbers, count in (("listings", listings, EXPECTED_LISTINGS[chapter_number]),
                                  ("figures", figures, EXPECTED_FIGURES[chapter_number])):
        if numbers != list(range(1, count + 1)):
            errors.append(f"{file.name}: {label} {numbers}; expected 1–{count}")
    tables = sorted({int(n) for n in re.findall(r"^\*\*表\s*" + chapter + r"-(\d+)", content, re.M)})
    if chapter_number in EXPECTED_TABLES and tables != list(range(1, EXPECTED_TABLES[chapter_number] + 1)):
        errors.append(f"{file.name}: tables {tables}; expected 1–{EXPECTED_TABLES[chapter_number]}")
    table_width = None
    for line in prose(content).splitlines():
        normalized = re.sub(r"`[^`]*`", "CODE", line.strip())
        if normalized.startswith("|") and normalized.endswith("|"):
            width = len(re.split(r"(?<!\\)\|", normalized)) - 2
            if table_width is not None and width != table_width:
                errors.append(f"{file.name}: table row has {width} columns; expected {table_width}: {line[:100]}")
            table_width = width if table_width is None else table_width
        else:
            table_width = None
    ordinary_text = re.sub(r"`[^`\n]+`", "", prose(content))
    definitions = set(re.findall(r"^\[\^([^\]]+)\]:", ordinary_text, re.M))
    references = set(re.findall(r"\[\^([^\]]+)\](?!:)", ordinary_text))
    if references - definitions:
        errors.append(f"{file.name}: undefined footnotes {sorted(references - definitions)}")
    if chapter_number in EXPECTED_FOOTNOTES and len(definitions) != EXPECTED_FOOTNOTES[chapter_number]:
        errors.append(f"{file.name}: footnotes {len(definitions)}; expected {EXPECTED_FOOTNOTES[chapter_number]}")
    notices = len(re.findall(r"^>\s*(?:\*\*)?注意", content, re.M))
    if chapter_number in EXPECTED_NOTICES and notices != EXPECTED_NOTICES[chapter_number]:
        errors.append(f"{file.name}: notices {notices}; expected {EXPECTED_NOTICES[chapter_number]}")
    report.append({"chapter": int(chapter),
                   "status": "coverage_and_fence_checks_passed" if len(errors) == errors_before else "incomplete",
                   "pdf_pages": pages, "expected_page_count": len(expected), "bytes": file.stat().st_size,
                   "code_blocks": len(languages), "numbered_listings": len(listings),
                   "mermaid_blocks": languages.count("mermaid"), "numbered_figures": len(figures),
                   "numbered_tables": len(tables),
                   "footnotes": len(definitions), "notice_blocks": notices})

supplement_report = []
for key, source in manifest.get("supplements", {}).items():
    file = ROOT / source["file"]
    if not file.exists():
        errors.append(f"Missing supplement: {file.name}")
        continue
    errors_before = len(errors)
    content = file.read_text()
    markers = re.findall(r"<!-- source: ([^,]+), PDF p\. (\d+) -->", content)
    expected = [(source["source"], str(n)) for n in range(source["pdf_pages"][0], source["pdf_pages"][1] + 1)]
    passed = markers == expected
    if not passed:
        errors.append(f"{file.name}: incomplete or incorrect source markers")
    fence = None
    languages = []
    for n, line in enumerate(content.splitlines(), 1):
        match = re.match(r"^(`{3,}|~{3,})(.*)$", line)
        if not match:
            continue
        delimiter, info = match.groups()
        if fence is None:
            fence = (delimiter[0], len(delimiter), n)
            languages.append(info.strip())
        elif delimiter[0] == fence[0] and len(delimiter) >= fence[1] and not info.strip():
            fence = None
    if fence:
        errors.append(f"{file.name}: unclosed code fence from line {fence[2]}")
        passed = False
    ordinary_text = re.sub(r"`[^`\n]+`", "", prose(content))
    definitions = set(re.findall(r"^\[\^([^\]]+)\]:", ordinary_text, re.M))
    references = set(re.findall(r"\[\^([^\]]+)\](?!:)", ordinary_text))
    if references - definitions:
        errors.append(f"{file.name}: undefined footnotes {sorted(references - definitions)}")
        passed = False
    if "expected_footnotes" in source and len(definitions) != source["expected_footnotes"]:
        errors.append(f"{file.name}: footnotes {len(definitions)}; expected {source['expected_footnotes']}")
    counts = {}
    for kind, label in (("listings", "代码清单"), ("figures", "图"), ("tables", "表")):
        prefix = re.escape(source.get("numbering_prefix", ""))
        numbers = sorted({int(n) for n in re.findall(r"^\*\*" + label + r"\s*" + prefix + r"-(\d+)", content, re.M)})
        counts[kind] = len(numbers)
        if "expected_" + kind in source and numbers != list(range(1, source["expected_" + kind] + 1)):
            errors.append(f"{file.name}: {kind} {numbers}; expected 1–{source['expected_' + kind]}")
    supplement_report.append({"section": key, "file": file.name,
                              "status": "coverage_and_fence_checks_passed" if len(errors) == errors_before else "incomplete",
                              "pdf_pages": [int(page) for pdf, page in markers],
                              "mermaid_blocks": languages.count("mermaid"), "footnotes": len(definitions),
                              "numbered_listings": counts["listings"],
                              "numbered_figures": counts["figures"], "numbered_tables": counts["tables"]})

# Every supplied scan page must belong to exactly one chapter or supplement.
source_coverage = []
for source in manifest["sources"]:
    pdf = Path(source["pdf"]).name
    owners = {n: [] for n in range(1, source["page_count"] + 1)}
    for key, section in list(manifest["chapters"].items()) + list(manifest.get("supplements", {}).items()):
        if section and section["source"] == pdf:
            for page in range(section["pdf_pages"][0], section["pdf_pages"][1] + 1):
                owners.setdefault(page, []).append(key)
    invalid = {str(n): keys for n, keys in owners.items() if len(keys) != 1 or not 1 <= n <= source["page_count"]}
    if invalid:
        errors.append(f"{pdf}: scan page partition errors {invalid}")
    source_coverage.append({"pdf": pdf, "page_count": source["page_count"],
                            "status": "passed" if not invalid else "incomplete"})

# Include issue records and index documents; ignore code-fence content.
for file in ROOT.rglob("*.md"):
    content = prose(file.read_text())
    for target in re.findall(r"\]\(([^\n]+?)\)", content):
        target = target.strip().strip("<>")
        if target.startswith(("http:", "https:", "mailto:")):
            continue
        path = unquote(target.split("#", 1)[0])
        path = re.sub(r":\d+$", "", path)
        destination = (file.parent / path) if path else file
        if not destination.exists():
            errors.append(f"{file.relative_to(ROOT)}: missing local link target {target}")
        elif "#" in target and destination.suffix == ".md":
            anchor = unquote(target.split("#", 1)[1])
            if anchor and anchor not in anchors(destination.read_text()):
                errors.append(f"{file.relative_to(ROOT)}: missing local anchor {target}")

result = {"scope": "Structural checks only; visual/source review recorded separately in chapter issues.",
          "chapters": report, "supplements": supplement_report,
          "source_coverage": source_coverage, "errors": errors}
print(json.dumps(result, ensure_ascii=False, indent=2))
sys.exit(bool(errors))
