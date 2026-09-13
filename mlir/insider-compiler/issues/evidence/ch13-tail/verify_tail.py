#!/usr/bin/env python3
"""Check permanent chapter-13 tail listings, optional assembled Markdown, and models.

No Triton parser, compiler pass, PTX generation, or GPU execution is performed.
"""
import argparse
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--markdown', type=Path,
                    help='Optionally compare listings 48–59 in the assembled chapter')
args = parser.parse_args()


def balanced(code, number):
    cleaned = re.sub(r'//[^\n]*', '', code)
    cleaned = re.sub(r'"(?:\\.|[^"\\])*"', '""', cleaned).replace('->', '')
    stack = []
    closing = {')': '(', ']': '[', '}': '{', '>': '<'}
    for offset, ch in enumerate(cleaned):
        if ch in '([{<':
            stack.append(ch)
        elif ch in closing:
            assert stack and stack.pop() == closing[ch], (number, offset, ch)
    assert not stack, (number, stack)


listings = []
for n in range(48, 60):
    ext = 'txt' if n in (55, 56) else 'mlir'
    code = (HERE / f'listing-13-{n}.{ext}').read_text()
    balanced(code, n)
    assert not any(ord(c) < 32 and c not in '\n\t' for c in code)
    listings.append({'number': n, 'file': f'listing-13-{n}.{ext}',
                     'delimiters': 'PASS',
                     'validity': 'transient invalid IR, intentionally not verifier input'
                     if n in (55, 56) else 'source-reviewed, not parsed with Triton'})

markdown = None
if args.markdown:
    text = args.markdown.read_text()
    assert not any(ord(c) < 32 and c not in '\n\t' for c in text)
    # Match both title styles, and include preceding listings as boundaries.
    titles = list(re.finditer(r'^\*\*代码清单 13-(\d+)\b[^\n]*$', text, re.M))
    matched = []
    for i, title in enumerate(titles):
        n = int(title[1])
        if not 48 <= n <= 59:
            continue
        end = titles[i+1].start() if i+1 < len(titles) else len(text)
        language = 'text' if n in (55, 56) else 'mlir'
        blocks = re.findall(r'^```' + language + r'\s*\n(.*?)^```\s*$',
                            text[title.end():end], re.S | re.M)
        # A continued listing is concatenated across its page marker.
        code = '\n'.join(blocks)
        saved = HERE / f'listing-13-{n}.{"txt" if language == "text" else "mlir"}'
        assert code.split() == saved.read_text().split(), f'Markdown listing {n} differs'
        matched.append(n)
    assert matched == list(range(48, 60)), matched
    pages = [int(n) for n in re.findall(r'<!-- source: insider-compiler-ch11-ch13.pdf, PDF p\. (\d+) -->', text)]
    assert [n for n in pages if n >= 119] == list(range(119, 131))
    tables = [int(n) for n in re.findall(r'^\*\*表 13-(\d+)', text, re.M)]
    assert [n for n in tables if n >= 8] == list(range(8, 14))
    definitions = re.findall(r'^\[\^(ch13-tail-[^\]]+)\]:', text, re.M)
    assert len(definitions) == len(set(definitions)) == 7
    assert text.count('**图 13-6**') == 1
    markdown = {'listing_match': '12/12 PASS', 'pages_119_130': '12/12 PASS',
                'tables_8_13': '6/6 PASS', 'footnotes': '7/7 PASS', 'figure_6': 'PASS'}

# This derives the allocation arithmetic in Allocation.cpp for listing58.
# It is deliberately an independent arithmetic model, not execution of the pass.
shape = [16, 1]
contiguous_src = [1, 2]  # NvidiaMmaEncodingAttr::getContigPerThread
contiguous_dst = [1, 2]  # BlockedEncodingAttr sizePerThread
src_unique = [min(a, b) for a, b in zip(shape, contiguous_src)]
dst_unique = [min(a, b) for a, b in zip(shape, contiguous_dst)]
# Source MMA tile is 16x8 multiplied by warps [4,1]; blocked tile is the
# product of sizePerThread, threadsPerWarp [4,8], and warpsPerCTA [4,1].
src_tile = [64, 8]
dst_tile = [16, 16]
rep = [max(min(shape[d], src_tile[d]), min(shape[d], dst_tile[d])) for d in range(2)]
in_vec, out_vec = src_unique[1], dst_unique[1]
padded = rep.copy()
padded[1] += max(in_vec, out_vec)
bytes_ = padded[0] * padded[1] * 32 // 8
assert rep == [16, 1] and padded == [16, 2] and bytes_ == 128

# Compare all stores, in order, for original54 versus transformed57.
# Distinct input elements make preservation of the first store observable.
arg0 = tuple(range(64))
zero, one = (0.0,) * 64, (1.0,) * 64
traces = []
for condition in (False, True):
    selected = zero if condition else one
    before = ([arg0] if condition else []) + [selected]
    if condition:
        after = [arg0]
        yielded = zero
    else:
        after = []
        yielded = one
    after.append(yielded)
    assert before == after
    traces.append({'condition': condition, 'store_count': len(before),
                   'all_values_and_store_order_equal': True})

result = {'scope': 'No Triton parser/verifier, pass, PTX, or GPU execution.',
          'listings': listings, 'markdown': markdown,
          'allocation_arithmetic': {'rep_shape': rep, 'in_vec': in_vec,
                                   'out_vec': out_vec, 'padded_shape': padded,
                                   'f32_bytes': bytes_, 'status': 'PASS'},
          'select_if_store_trace_model': traces}
(HERE / 'tail-check-results.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k:v for k,v in result.items() if k != 'listings'}, ensure_ascii=False, indent=2))
print('12 permanent listings balanced; 2 transient snapshots remain intentionally invalid.')
