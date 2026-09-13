#!/usr/bin/env python3
from pathlib import Path
import subprocess, shlex
r=Path(__file__).resolve().parent
opt='/opt/llvm-project/build/bin/mlir-opt';pdll='/opt/llvm-project/build/bin/mlir-pdll'
checks=[]
for n in [1,2,7,9,11]:
    checks.append(('listing-'+str(n),[opt,str(r/('listing-12-'+str(n)+'.mlir'))]))
checks.append(('listing-8',[pdll,'-x=mlir',str(r/'listing-12-8.pdll')]))
(r/'listing-10-check.cpp').write_text('#include "mlir/IR/PatternMatch.h"\n#include "mlir/IR/BuiltinOps.h"\n#include "mlir/Parser/Parser.h"\n#include "listing-12-10.cpp"\nvoid check(mlir::MLIRContext *context) { ReplaceTenWithEleven pattern(context); }\n')
checks.append(('listing-10',['clang++','-std=c++17','-fsyntax-only','-I/opt/llvm-project/mlir/include','-I/opt/llvm-project/llvm/include','-I/opt/llvm-project/build/tools/mlir/include','-I/opt/llvm-project/build/include',str(r/'listing-10-check.cpp')]))
log=[]
for name,cmd in checks:
    p=subprocess.run(cmd,capture_output=True,text=True)
    (r/(name+'.out')).write_text(p.stdout);(r/(name+'.err')).write_text(p.stderr)
    log.append('$ '+shlex.join(cmd)+'\nexit: '+str(p.returncode)+'\n'+p.stdout+p.stderr)
    (r/'document-results.txt').write_text('\n\n'.join(log))
    assert p.returncode==0,(name,p.stderr)
print('PASS: final Markdown listings 1,2,7,8,9,10,11 parsed/compiled')
