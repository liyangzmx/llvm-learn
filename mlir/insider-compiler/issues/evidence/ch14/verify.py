#!/usr/bin/env python3
"""Verify final chapter text, exact matrices, and the actual local MLIR examples."""
import itertools
import json
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
CHAPTER = HERE.parents[2] / 'insider-compiler-ch14.md'
OPT = Path('/opt/llvm-project/build/bin/mlir-opt')
ANALYSIS = Path('/private/tmp/insider-ch14-build/ch14-analysis')
results = {'llvm_commit': '3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff', 'commands': [], 'checks': []}

def run(args, output=None):
    proc = subprocess.run([str(x) for x in args], text=True, capture_output=True)
    results['commands'].append({'argv': [str(x) for x in args], 'returncode': proc.returncode, 'stderr': proc.stderr})
    assert proc.returncode == 0, (args, proc.stderr)
    if output:
        (HERE / output).write_text(proc.stdout)
    return proc.stdout

def check(name, condition):
    assert condition, name
    results['checks'].append(name)

text = CHAPTER.read_text()
check('24 source pages exactly 2..25', [int(x) for x in re.findall(r'<!-- source: insider-compiler-ch14-end.pdf, PDF p. (\d+) -->', text)] == list(range(2, 26)))
listings = {int(n): (lang, code) for n, lang, code in re.findall(r'\*\*代码清单 14-(\d+)\*\*[^\n]*\n\s*```(\w+)\n(.*?)\n```', text, re.S)}
check('13 complete numbered listings', sorted(listings) == list(range(1, 14)))
check('one numbered figure and Mermaid', len(re.findall(r'^\*\*图 14-1\*\*', text, re.M)) == 1 and text.count('```mermaid') == 1)
check('five footnotes', re.findall(r'^\[\^ch14-(\d+)\]:', text, re.M) == list('12345'))
check('13 source notices', text.count('> **注意：**') == 13)
for n, (lang, code) in listings.items():
    suffix = {'mlir': 'mlir', 'c': 'c', 'text': 'txt'}[lang]
    (HERE / f'listing-14-{n}.{suffix}').write_text(code + '\n')

# Every coefficient in the nine mathematical tables. The expected rows below
# come from address formulas, equal source/target addresses, and lexicographic
# ordering. Comparison with actual C++ API output is an independent cross-check.
def bounds(nvars, positions, upper):
    out = []
    for p in positions:
        row = [0] * (nvars + 1); row[p] = 1
        out.append((row, '≥0'))
        row = [0] * (nvars + 1); row[p] = -1; row[-1] = upper[p]
        out.append((row, '≥0'))
    return out

def eq(rows): return [(r, '=0') for r in rows]
base = [[-1,0,0,1,0,0,0], [0,-1,0,0,1,0,0]]
b6 = bounds(6, range(6), [4095]*6)
b3 = bounds(5, range(3), [4095]*3)
expected = {
  1: eq([[2,-4,-1,0,1,0,0], [0,3,0,-1,0,-1,0]]) + bounds(6, range(2), [99,49]),
  2: eq([[7,9,-1,0,-1,0,0], [0,11,0,-1,0,1,0]]) + bounds(6, range(2), [99,49]),
  3: eq([[2,-4,-7,-9,1,1,0,0], [0,3,0,-11,-1,0,-1,0]]) + bounds(7, range(4), [99,49,99,49]),
  4: eq([[1,0,0,-1,0,0], [0,1,0,0,-1,0]]) + b3,
  5: eq([[1,0,0,-1,0,0], [0,1,0,0,-1,0]]) + b3,
  6: eq([[1,0,0,0,0,0,-1,0,0], [0,1,0,0,0,0,0,-1,0], [0,0,0,1,0,0,-1,0,0], [0,0,0,0,1,0,0,-1,0]]) + bounds(8, range(6), [4095]*6),
  7: eq(base) + b6,
  8: eq(base) + b6 + [([-1,0,0,1,0,0,-1], '≥0')],
  9: eq(base + base) + b6 + [([0,0,-1,0,0,1,-1], '≥0')],
}
tables = {}
for n, block in re.findall(r'^\*\*表 14-(\d+)\*\*[^\n]*\n\n((?:\|[^\n]*\n)+)', text, re.M):
    if int(n) == 10:
        check('table10 contains all four nodes', all(f'node {i}' in block for i in range(4)))
        continue
    rows = []
    for line in block.splitlines()[2:]:
        cells = [x.strip() for x in line.strip('|').split('|')]
        pos = next(i for i,c in enumerate(cells) if c in ('=0','≥0'))
        rows.append(([int(x) for x in cells[1:pos]], cells[pos]))
    tables[int(n)] = rows
    check(f'table14-{n} exact coefficients', rows == expected[int(n)])
check('nine coefficient tables extracted', sorted(tables) == list(range(1,10)))

def sat(rows, xs):
    for row, rel in rows:
        val = sum(a*b for a,b in zip(row, [*xs, 1]))
        if (val != 0 if rel == '=0' else val < 0): return False
    return True
counts = {'combined': 0, 'outer': 0, 'middle': 0, 'inner': 0}
for xs in itertools.product(range(3), repeat=6):
    s3,s4,s5,t3,t4,t5 = xs
    truth = (s3,s4) == (t3,t4)
    assert sat(tables[6], [*xs,s3,s4]) == truth
    assert sat(tables[7], xs) == truth
    assert sat(tables[8], xs) == (truth and t3 > s3)
    assert sat(tables[9], xs) == (truth and t5 > s5)
    counts['combined'] += truth
    counts['outer'] += sat(tables[8], xs)
    counts['middle'] += truth and s3 == t3 and t4 > s4
    counts['inner'] += sat(tables[9], xs)
check('729 finite-domain cases: relation composition and ordered dependencies', counts == {'combined':81, 'outer':0, 'middle':0, 'inner':27})
for p in range(3):
    for val in (-1,0,4095,4096):
        xs=[0,0,0]; xs[p]=val
        assert sat(tables[4], [*xs,xs[0],xs[1]]) == (0 <= val <= 4095)
check('domain boundaries include4095 exclude4096 and negative indices', True)
(HERE / 'matrices.json').write_text(json.dumps({'tables': tables, 'finite_domain_counts': counts}, ensure_ascii=False, indent=2)+'\n')

# Normalize every complete MLIR listing; parse snippets in an explicit envelope.
run([OPT, '--version'], 'llvm-version.txt')
for n in (4,5,6,7,8,9,10,12):
    run([OPT, HERE/f'listing-14-{n}.mlir'], f'listing-14-{n}.normalized.mlir')
for n in (2,3):
    code = listings[n][1]
    wrapper = 'func.func @access(%m: memref<?x?xf32>, %v0: f32, %M: index, %N: index, %K: index) {\n'+code+'\nreturn\n}\n'
    (HERE/f'listing-14-{n}.wrapped.mlir').write_text(wrapper)
    run([OPT, HERE/f'listing-14-{n}.wrapped.mlir'], f'listing-14-{n}.normalized.mlir')

pairs = [(4,5,'--affine-parallelize'),(6,7,'--affine-loop-fusion'),(8,12,'--affine-loop-fusion')]
for src,dst,flag in pairs:
    got = run([OPT,HERE/f'listing-14-{src}.mlir',flag], f'listing-14-{src}.transformed.mlir')
    expected_ir = (HERE/f'listing-14-{dst}.normalized.mlir').read_text()
    check(f'actual pass listing14-{src} equals final listing14-{dst}', got == expected_ir)
    run([OPT,HERE/f'listing-14-{src}.transformed.mlir','-o','/dev/null'])

# Reuse the helper build whose source and CMake are included in this directory.
access = run([ANALYSIS,HERE/'access.mlir'],'access-analysis.txt')
parallel = run([ANALYSIS,HERE/'parallel.mlir'],'parallel-analysis.txt')
def api_rows(txt):
    rows=[]
    for line in txt.splitlines():
        cells=line.split()
        if len(cells)>2 and cells[-2] in ('=','>=') and cells[-1]=='0':
            try: coeff=[int(x) for x in cells[:-2]]
            except ValueError: continue
            rows.append((coeff, '=0' if cells[-2]=='=' else '≥0'))
    return rows
check('actual access relations match tables1 and2', api_rows(access) == tables[1] + tables[2])
check('actual dependence relation matches table9', api_rows(parallel) == tables[9])
check('local parallel analysis is true,true,false', re.findall(r'LOOP \d+ parallel=(\d)', parallel) == ['1','1','0'])
check('actual dependence at depths1,2,3 is No,No,Has', re.findall(r'DEPENDENCE depth=\d+ result=(\d)',parallel) == ['1','1','0'])
check('complete integer sampler finds innermost relation nonempty', 'integerEmpty=0' in parallel)
log=(HERE/'fusion-union-debug.txt').read_text()
for label,value in [('additional compute fraction','23.81%'),('storage reduction factor','6.67x'),('fused nest cost','260'),('src write region size','400'),('slice write region size','60')]:
    check('actual fusion log '+label, f'{label}: {value}' in log)
check('fusion arithmetic and dynamic writes', round((260/210-1)*100,2)==23.81 and round(400/60,2)==6.67 and 10*15*4==600)
results['finite_domain_counts']=counts
results['limitations']=['C listings1 and13 visually/source checked as fragments, not compiled here', '4096^3 example parsed/analyzed/transformed, not numerically executed', 'snippets2 and3 require caller bounds/initialization; no numerical execution', 'listings9 and10 are illustrative stages, not claimed actual pass outputs', 'tiling runtime and math reviews independently saved by root; not rerun by this verifier']
(HERE/'verification-results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2)+'\n')
print(json.dumps({'commands':len(results['commands']),'checks':len(results['checks']),'status':'PASS'}, ensure_ascii=False))
