#!/usr/bin/env python3
from pathlib import Path
import subprocess, shlex
root = Path(__file__).resolve().parent
opt = '/opt/llvm-project/build/bin/mlir-opt'
pdll = '/opt/llvm-project/build/bin/mlir-pdll'
log = []
def run(name,args,expect=0,tool=opt):
    cmd=[tool,*args]
    r=subprocess.run(cmd,capture_output=True,text=True)
    (root/(name+'.out')).write_text(r.stdout)
    (root/(name+'.err')).write_text(r.stderr)
    log.append('$ '+shlex.join(cmd)+'\nexit: '+str(r.returncode)+'\n'+r.stdout+r.stderr)
    (root/'commands-and-results.txt').write_text('\n\n'.join(log))
    assert r.returncode==expect,(name,r.returncode,r.stderr)
    return r.stdout
run('version',['--version'])
s=run('transform',[str(root/'transform.mlir'),'--transform-interpreter'])
assert 'call @second()' in s and 'call @third()' in s and '"test.bar"()' in s
run('pdl-parse',[str(root/'pdl.mlir')])
run('pdl-interp',[str(root/'pdl.mlir'),'--convert-pdl-to-pdl-interp'])
pdl=run('pdll-pdl',['-x=mlir',str(root/'replace.pdll')],tool=pdll)
run('pdll-cpp',['-x=cpp',str(root/'replace.pdll')],tool=pdll)
run('pdll-interp',[str(root/'pdll-pdl.out'),'--convert-pdl-to-pdl-interp'])
# Test harness from test/lib/Rewrite/TestPDLByteCode.cpp accepts modules named patterns/ir.
(root/'pdll-run.mlir').write_text(pdl.replace('module {','module @patterns {',1)+'''\nmodule @ir {
  func.func @constant() -> i32 {
    %c = arith.constant 10 : i32
    return %c : i32
  }
}
''')
s=run('pdll-run',[str(root/'pdll-run.mlir'),'--test-pdl-bytecode-pass'])
assert 'arith.constant 11 : i32' in s and 'arith.constant 10 : i32' not in s
pdl=(root/'pdl.mlir').read_text()
(root/'pdl-run.mlir').write_text('module @patterns {\n'+pdl+'}\n'+'''module @ir {
  func.func @identity(%a: i32) -> i32 {
    %b = "foo.op"(%a) : (i32) -> i32
    return %b : i32
  }
}
''')
s=run('pdl-run',[str(root/'pdl-run.mlir'),'--allow-unregistered-dialect','--test-pdl-bytecode-pass'])
assert 'foo.op' not in s
(root/'pdl-mismatch.mlir').write_text((root/'pdl-run.mlir').read_text().replace('-> i32 {', '-> f32 {').replace('(i32) -> i32', '(i32) -> f32').replace('return %b : i32', 'return %b : f32'))
s=run('pdl-mismatch',[str(root/'pdl-mismatch.mlir'),'--allow-unregistered-dialect','--test-pdl-bytecode-pass'])
assert 'foo.op' in s
run('cmath-parse',[str(root/'cmath.mlir')])
(root/'cmath-valid.mlir').write_text('''func.func @mul(%a: !cmath.complex<f32>, %b: !cmath.complex<f32>) -> !cmath.complex<f32> {
  %r = "cmath.mul"(%a, %b) : (!cmath.complex<f32>, !cmath.complex<f32>) -> !cmath.complex<f32>
  return %r : !cmath.complex<f32>
}
''')
run('cmath-qualified',[str(root/'cmath-valid.mlir'),'--irdl-file='+str(root/'cmath-qualified.mlir')],expect=1)
run('cmath-valid',[str(root/'cmath-valid.mlir'),'--irdl-file='+str(root/'cmath.mlir')])
(root/'cmath-invalid.mlir').write_text((root/'cmath-valid.mlir').read_text().replace('%b: !cmath.complex<f32>','%b: !cmath.complex<f64>').replace('(!cmath.complex<f32>, !cmath.complex<f32>)','(!cmath.complex<f32>, !cmath.complex<f64>)'))
run('cmath-invalid',[str(root/'cmath-invalid.mlir'),'--irdl-file='+str(root/'cmath.mlir')],expect=1)
# This modern-form variant represents the overlap central to listing 12-12.
(root/'overlap.mlir').write_text('''irdl.dialect @overlap {
  irdl.operation @test {
    %t = irdl.any
    %v = irdl.base "!builtin.vector"
    %either = irdl.any_of(%t, %v)
    irdl.operands(%either)
    irdl.results(%t)
  }
}
''')
(root/'empty.mlir').write_text('module {}\n')
run('overlap-parse',[str(root/'overlap.mlir')])
run('overlap-load',[str(root/'empty.mlir'),'--irdl-file='+str(root/'overlap.mlir')],expect=1)
print('PASS: Transform calls, PDL/PDLL lowering and bytecode rewriting, IRDL dynamic loading and negative constraints')
