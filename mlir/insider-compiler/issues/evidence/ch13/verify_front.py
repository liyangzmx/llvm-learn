#!/usr/bin/env python3
"""Extract chapter 13's first 36 listings; check Python syntax and IR delimiters.

This is deliberately not a Triton parser/verifier or a GPU execution test.
"""
import ast
import json
import re
import sys
from pathlib import Path

here = Path(__file__).resolve().parent
chapter = here.parents[2] / 'insider-compiler-ch13.md'
text = chapter.read_text()
# Both styles occur in the book: the title may be inside or outside bold.
# Recognize subsequent chapters' slices too, so listing 36 ends at listing 37.
listings = list(re.finditer(r'^\*\*代码清单 13-(\d+)\b[^\n]*$', text, re.M))
checks = []
output = here / 'front-listings'
output.mkdir(exist_ok=True)
for i, listing in enumerate(listings):
    number = int(listing.group(1))
    if number > 36:
        continue
    end = listings[i + 1].start() if i + 1 < len(listings) else len(text)
    chunk = text[listing.end():end]
    language = 'python' if number in (1, 2) else 'text' if number == 11 else 'mlir'
    blocks = re.findall(r'^```' + language + r'\s*\n(.*?)^```\s*$', chunk, re.S | re.M)
    assert blocks, f'No {language} code in listing {number}'
    if number == 11:
        blocks = blocks[:1]
    code = '\n'.join(blocks)
    ext = 'py' if language == 'python' else 'txt' if language == 'text' else 'mlir'
    (output / f'listing-13-{number:02}.{ext}').write_text(code)
    result = {'listing': number, 'language': language, 'parts': len(blocks)}
    if language == 'python':
        tree = ast.parse(code)
        compile(tree, f'listing-13-{number:02}.py', 'exec')
        result['check'] = 'Python AST and compile() syntax PASS; not imported or executed'
    elif language == 'mlir':
        cleaned = re.sub(r'//[^\n]*', '', code)
        cleaned = re.sub(r'"(?:\\.|[^"\\])*"', '""', cleaned)
        cleaned = cleaned.replace('->', '')
        stack = []
        matching = {')': '(', ']': '[', '}': '{', '>': '<'}
        for offset, ch in enumerate(cleaned):
            if ch in '([{<':
                stack.append((ch, offset))
            elif ch in matching:
                assert stack, f'listing {number}: unexpected {ch} at {offset}'
                opening, _ = stack.pop()
                assert opening == matching[ch], f'listing {number}: {opening} / {ch} at {offset}'
        assert not stack, f'listing {number}: unterminated delimiters {stack}'
        result['check'] = 'Lexical delimiter balance PASS; no Triton parser/verifier run'
        # Check complete function examples for missing SSA names. This only
        # proves textual definition coverage, not scope, dominance or types.
        if number not in set(range(12, 20)) | {23, 24}:
            uses = set(re.findall(r'%[A-Za-z0-9_.$-]+', cleaned))
            definitions = set(re.findall(r'(%[A-Za-z0-9_.$-]+)(?::\d+)?\s*=', cleaned))
            for function in re.finditer(r'tt\.func\b[^\(]*\(', cleaned):
                start = end = function.end()
                depth = 1
                while depth:
                    ch = cleaned[end]
                    depth += (ch == '(') - (ch == ')')
                    end += 1
                definitions.update(re.findall(r'(%[A-Za-z0-9_.$-]+)\s*:', cleaned[start:end - 1]))
            for block in re.finditer(r'\^[A-Za-z0-9_.$-]+\(([^)]*)\)', cleaned):
                definitions.update(re.findall(r'(%[A-Za-z0-9_.$-]+)\s*:', block.group(1)))
            missing = sorted(uses - definitions)
            assert not missing, f'listing {number}: SSA names without definitions: {missing}'
            result['ssa_name_coverage'] = {'status': 'PASS', 'names': len(uses)}
        else:
            result['ssa_name_coverage'] = {'status': 'Not checked: operation fragment with external inputs'}
    else:
        result['check'] = 'Abstract layout mapping extracted'
    checks.append(result)
assert [c['listing'] for c in checks] == list(range(1, 37))

# Derive blocked mapping from sizePerThread=(2,2), threadsPerWarp=(8,4),
# warpsPerCTA=(1,2), order=(1,0); verify all explicit rows of table 13-3.
def owner(row, col):
    warp = col // 8
    lane = (row // 2) * 4 + (col % 8) // 2
    return 32 * warp + lane
expected = {
    0: [0,0,1,1,2,2,3,3,32,32,33,33,34,34,35,35],
    1: [0,0,1,1,2,2,3,3,32,32,33,33,34,34,35,35],
    2: [4,4,5,5,6,6,7,7,36,36,37,37,38,38,39,39],
    3: [4,4,5,5,6,6,7,7,36,36,37,37,38,38,39,39],
    14: [28,28,29,29,30,30,31,31,60,60,61,61,62,62,63,63],
    15: [28,28,29,29,30,30,31,31,60,60,61,61,62,62,63,63],
}
for row, values in expected.items():
    assert [owner(row, col) for col in range(16)] == values
counts = {thread: 0 for thread in range(64)}
for row in range(16):
    for col in range(16):
        counts[owner(row, col)] += 1
assert set(counts.values()) == {4}

# Check shared swizzle's bijectivity, self-inverse property, all printed cells.
def swizzle(row, col, vec=2, per_phase=2, max_phase=8):
    phase = (row // per_phase) % max_phase
    return ((col // vec) ^ phase) * vec + col % vec
for row in range(16):
    assert sorted(swizzle(row, col) for col in range(16)) == list(range(16))
    assert all(swizzle(row, swizzle(row, col)) == col for col in range(16))
printed = {
  0: [(0,0),(0,1),(0,2),(0,3),(0,4),(0,5),(0,6),(0,7),(0,8),(1,14),(1,15)],
  1: [(2,2),(2,3),(2,0),(2,1),(2,6),(2,7),(2,4),(2,5),(2,10),(3,12),(3,13)],
  2: [(4,4),(4,5),(4,6),(4,7),(4,0),(4,1),(4,2),(4,3),(4,12),(5,10),(5,11)],
  3: [(6,6),(6,7),(6,4),(6,5),(6,2),(6,3),(6,0),(6,1),(6,14),(7,8),(7,9)],
  7: [(14,14),(14,15),(14,12),(14,13),(14,10),(14,11),(14,8),(14,9),(14,6),(15,0),(15,1)],
}
banks = list(range(9)) + [30, 31]
for phase, elements in printed.items():
    for bank, (row, col) in zip(banks, elements):
        assert row // 2 == phase
        assert (row * 16 + swizzle(row, col)) % 32 == bank
old = [((col // 2) ^ 1) * 2 for col in range(16)]
assert len(set(old)) == 8  # Missing low element bit causes pairs to collide.

results = {
  'python': sys.version.split()[0],
  'scope': 'Listings 1-36. No Triton compilation, parser/verifier, PTX or GPU execution.',
  'listings': checks,
  'blocked': {'status': 'PASS', 'elements': 256, 'printed_cells': 96, 'threads': 64, 'elements_per_thread': 4},
  'swizzle': {'status': 'PASS', 'elements': 256, 'printed_cells': 55, 'rows_bijective': 16, 'old_formula_distinct_columns_per_row': 8},
}
(here / 'front-check-results.json').write_text(json.dumps(results, indent=2, ensure_ascii=False) + '\n')
print(json.dumps({k: v for k, v in results.items() if k != 'listings'}, indent=2, ensure_ascii=False))
print('36 listings extracted; 2 Python syntax checks, 33 MLIR delimiter checks, 23 SSA name coverage checks, and 1 abstract mapping completed.')
