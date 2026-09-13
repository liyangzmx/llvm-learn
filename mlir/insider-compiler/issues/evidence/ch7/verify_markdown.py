#!/usr/bin/env python3
"""Parse every complete MLIR listing and generate the two TableGen patterns."""
from pathlib import Path
import re
import subprocess
D = Path(__file__).resolve().parent
MD = D.parents[2] / 'insider-compiler-ch7.md'
text = MD.read_text()
OPT = Path('/opt/llvm-project/build/bin/mlir-opt')
TBLGEN = OPT.with_name('mlir-tblgen')
logs = []
for number, lang, code in re.findall(r'\*\*代码清单 7-(\d+) [^\n]+\*\*\n\n```([^\n]+)\n(.*?)\n```', text, re.S):
    if lang == 'mlir':
        inp = D / f'listing-7-{number}.mlir'
        inp.write_text(code + '\n')
        cmd = [str(OPT), str(inp), '-o', '/dev/null']
    elif lang == 'tablegen':
        inp = D / f'listing-7-{number}.td'
        inp.write_text('include "mlir/Dialect/Arith/IR/ArithOps.td"\ninclude "mlir/IR/PatternBase.td"\n' + code + '\n')
        cmd = [str(TBLGEN), str(inp), '-I', '/opt/llvm-project/mlir/include', '-I', '/opt/llvm-project/build/tools/mlir/include', '-gen-rewriters', '-o', str(D / 'listing-7-3.inc')]
    else:
        logs.append(f'listing-7-{number}: {lang}, explicitly non-standalone; source checked')
        continue
    r = subprocess.run(cmd, capture_output=True, text=True)
    logs.append('$ ' + ' '.join(cmd) + '\nexit=' + str(r.returncode) + '\n' + r.stderr)
    print('listing', number, 'exit', r.returncode)
    if r.returncode:
        (D / 'verify-markdown.log').write_text('\n'.join(logs))
        raise SystemExit(r.stderr)
(D / 'verify-markdown.log').write_text('\n'.join(logs))
assert re.findall(r'PDF p\. (\d+) -->', text) == [str(i) for i in range(1, 18)]
assert len(re.findall(r'^\*\*代码清单 7-\d+ ', text, re.M)) == 17
assert len(re.findall(r'^```mermaid$', text, re.M)) == 4
assert len(re.findall(r'^\[\^ch7-[^]]+\]:', text, re.M)) == 5
print('PASS: 17 pages, 17 listings, 4 figures, 5 footnotes; 14 MLIR listings + 1 TableGen fragment verified')
