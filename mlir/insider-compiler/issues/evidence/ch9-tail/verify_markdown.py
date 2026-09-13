#!/usr/bin/env python3
"""Validate numbered tail listings extracted from chapter 9 Markdown."""
from pathlib import Path
import sys,re,subprocess,json
D=Path(__file__).resolve().parent
files=[Path(x) for x in sys.argv[1:]] or [D.parents[2]/'insider-compiler-ch9.md']
text='\n'.join(p.read_text() for p in files)
records=[]
for n in range(34,41):
 m=re.search(r'^\*\*代码清单 9-'+str(n)+r' [^\n]+\*\*\n\n```mlir\n(.*?)\n```',text,re.S|re.M)
 if not m: raise SystemExit(f'missing listing {n}')
 code=m.group(1)
 if n==40:
  remainder=text[m.end():]
  extra=re.match(r'\s*<!-- source: [^\n]+ -->\s*```mlir\n(.*?)\n```',remainder,re.S)
  if extra:code+='\n'+extra.group(1)
 inp=D/f'listing-9-{n}.mlir';inp.write_text(code+'\n')
 cmd=['/opt/llvm-project/build/bin/mlir-opt',str(inp),'-o','/dev/null']
 r=subprocess.run(cmd,capture_output=True,text=True)
 records.append({'listing':n,'command':cmd,'returncode':r.returncode,'stderr':r.stderr})
 print('listing',n,'exit',r.returncode)
 if r.returncode:print(r.stderr)
(D/'verify-markdown.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
raise SystemExit(any(r['returncode'] for r in records))
