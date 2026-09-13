#!/usr/bin/env python3
"""Validate chapter1 extraction, instantiated IR, lowering, export and native scalar kernel.

Book constants remain truncated in the main text. complete-1-*.mlir use explicit
validation-data.json parameters, never purported recovered/trained book weights.
"""
import argparse
import ast
import importlib.util
import json
import re
import struct
import subprocess
import tempfile
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
a=argparse.ArgumentParser(description=__doc__)
a.add_argument('--llvm-bin',type=Path,default=Path('/opt/llvm-project/build/bin'))
a.add_argument('--translator',type=Path,required=True)
a.add_argument('--clang',default='/usr/bin/clang')
x=a.parse_args()
text=(ROOT/'insider-compiler-ch1.md').read_text()
assert not any(ord(c)<32 and c not in '\n\t' for c in text)
heads=list(re.finditer(r'^\*\*代码清单 1-(\d+)\b[^\n]*$',text,re.M))
assert [int(h[1]) for h in heads]==list(range(1,9))
for i,h in enumerate(heads):
 n=int(h[1]); end=heads[i+1].start() if i+1<len(heads) else len(text)
 lang='python' if n==1 else 'mlir'
 blocks=re.findall(r'^```'+lang+r'\s*\n(.*?)^```\s*$',text[h.end():end],re.S|re.M)
 ext='py' if n==1 else 'mlir'
 code='\n'.join(blocks)
 assert code.split()==(HERE/f'listing-1-{n}.{ext}').read_text().split(),n
assert [int(n) for n in re.findall(r'<!-- source: insider-compiler-ch1.pdf, PDF p\. (\d+) -->',text)]==list(range(1,15))
assert re.findall(r'^\*\*图 1-(\d+)\*\*',text,re.M)==['1','2','3','4']
assert len(re.findall(r'^\[\^ch1-[^\]]+\]:',text,re.M))==12
assert text.count('> **注意**')==1
compile(ast.parse((HERE/'listing-1-1.py').read_text()),'listing-1-1.py','exec')

# Verify concrete instances really substitute the documented parameters only.
data=json.loads((HERE/'validation-data.json').read_text())
def hex_dense(nested):
 values=[]
 def flatten(item):
  if isinstance(item,list):
   for v in item:flatten(v)
  else:values.append(item)
 flatten(nested)
 return 'dense<"0x'+''.join(struct.pack('<f',v).hex().upper() for v in values)+'">'
for n in range(2,8):
 expected=(HERE/f'listing-1-{n}.mlir').read_text().replace('dense<"0xC44B...">',hex_dense(data['weights_shape_16x10'])).replace('dense<"0xA270...">',hex_dense(data['bias_shape_1x10']))
 assert expected==(HERE/f'complete-1-{n}.mlir').read_text(),n

commands=[]
def run(args,expected=0,output=None):
 cp=subprocess.run([str(v) for v in args],text=True,capture_output=True)
 commands.append({'argv':[str(v) for v in args], 'exit':cp.returncode,
                  'expected_exit':expected,'stdout':cp.stdout if output is None else '(saved to '+output.name+')',
                  'stderr':cp.stderr})
 assert cp.returncode==expected,commands[-1]
 if output:output.write_text(cp.stdout)
 return cp.stdout
opt=x.llvm_bin/'mlir-opt'
with tempfile.TemporaryDirectory(prefix='ch1-verify-') as work:
 work=Path(work)
 version=run([opt,'--version']).strip()
 for n in range(2,8):
  run([opt,HERE/f'complete-1-{n}.mlir','-o',work/f'parsed-{n}.mlir'])
 run([opt,HERE/'complete-1-2.mlir','--tosa-validate=profile=mi','-o',work/'tosa-mi.mlir'])
 # LLVM18's registered shortcut hardcodes BaseInference, which rejects f32.
 run([opt,HERE/'complete-1-2.mlir','--tosa-to-linalg-pipeline','-o',work/'default.mlir'],expected=1)
 run([opt,HERE/'complete-1-2.mlir',
      '--pass-pipeline=builtin.module(func.func(tosa-to-linalg-named,tosa-to-linalg,tosa-to-arith,tosa-to-tensor),canonicalize)',
      '-o',HERE/'tosa-to-linalg-explicit.mlir'])
 run([opt,HERE/'complete-1-4.mlir','--one-shot-bufferize=bufferize-function-boundaries',
      '--convert-linalg-to-affine-loops','--canonicalize','-o',HERE/'linalg-to-affine.mlir'])
 run([opt,HERE/'complete-1-6.mlir','--lower-affine','--convert-scf-to-cf',
      '--convert-arith-to-llvm','--finalize-memref-to-llvm','--convert-func-to-llvm',
      '--convert-cf-to-llvm','--reconcile-unrealized-casts','-o',HERE/'affine-to-llvm.mlir'])
 run([opt,HERE/'snippet-fixture.mlir','-o',work/'snippet-parsed.mlir'])
 for file in ['tosa-to-linalg-explicit.mlir','linalg-to-affine.mlir','affine-to-llvm.mlir']:
  run([opt,HERE/file,'-o',work/file])
 for src,dst in [('affine-to-llvm.mlir','affine.ll'),('snippet-fixture.mlir','snippet-fixture.ll')]:
  run([x.translator,HERE/src],output=HERE/dst)
  run([x.llvm_bin/'llvm-as',HERE/dst,'-o',work/(dst+'.bc')])
 run([x.clang,'-O0','-ffp-contract=off',HERE/'affine.ll',HERE/'run-forward.c','-o',work/'forward'])
 native=run([work/'forward']).strip()
result={'llvm':version,'structure':{'pages':14,'listings':8,'figures':4,'footnotes':12,'notice_boxes':1,'markdown_matches_permanent_listings':'PASS'},
        'python':'AST and compile syntax PASS; torch/torch_mlir compile not executed',
        'python_modules_present':{m:bool(importlib.util.find_spec(m)) for m in ['torch','torch_mlir']},
        'constant_boundary':'Original data truncated; complete instances use validation-data.json',
        'snippet_boundary':'Supplied operands and entry only establish parser/export validity; not full vectorization of the book model',
        'native':native,'commands':commands}
(HERE/'verification-results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='commands'},ensure_ascii=False,indent=2))
print(f'{len(commands)} recorded commands matched expected exit status (default BaseInference failure is intentional).')
