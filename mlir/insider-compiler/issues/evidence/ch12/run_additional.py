#!/usr/bin/env python3
from pathlib import Path
import subprocess, shlex
r=Path(__file__).resolve().parent
opt='/opt/llvm-project/build/bin/mlir-opt'
checks=[('handle-read',[opt,str(r/'handle-read.mlir'),'--transform-interpreter'],0),('handle-consumed',[opt,str(r/'handle-consumed.mlir'),'--transform-interpreter'],1),('cmath-named',[opt,str(r/'cmath-named.mlir')],1),('pdll-generated-check',['clang++','-std=c++17','-fsyntax-only','-I/opt/llvm-project/mlir/include','-I/opt/llvm-project/llvm/include','-I/opt/llvm-project/build/tools/mlir/include','-I/opt/llvm-project/build/include',str(r/'pdll-generated-check.cpp')],0)]
log=[]
for name,cmd,expected in checks:
    p=subprocess.run(cmd,text=True,capture_output=True)
    (r/(name+'.out')).write_text(p.stdout)
    (r/(name+'.err')).write_text(p.stderr)
    log.append('$ '+shlex.join(cmd)+'\nexit: '+str(p.returncode)+'\n'+p.stdout+p.stderr)
    (r/'additional-results.txt').write_text('\n\n'.join(log))
    assert p.returncode==expected,(name,p.returncode,p.stderr)
print('PASS: read handle reuse, consumed alias rejected, named IRDL syntax version difference, generated C++ syntax')
