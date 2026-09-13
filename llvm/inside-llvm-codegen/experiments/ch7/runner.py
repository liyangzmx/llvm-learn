#!/usr/bin/env python3
"""Reproduce chapter 7; outputs go to a fresh temporary directory by default."""
import argparse, hashlib, json, os, pathlib, re, subprocess, tempfile
from models import run_models
P = pathlib.Path
HERE = P(__file__).resolve().parent
BOOK_ROOT = P(os.environ.get('BOOK_ROOT', HERE.parents[1])).resolve()
LLVM_BUILD = P(os.environ.get('LLVM_BUILD', '/opt/llvm-project/build')).resolve()
LLVM_SRC = P(os.environ.get('LLVM_SRC', '/opt/llvm-project')).resolve()
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=P)
parser.add_argument('--summary', type=P, help='Optional additional JSON report path')
parser.add_argument('--bpf-only', action='store_true', help='Development subset; not full chapter coverage')
args = parser.parse_args()
out = (args.output or P(tempfile.mkdtemp(prefix='llvm-book-ch7-'))).resolve()
out.mkdir(parents=True, exist_ok=True)
commands, checks = [], []
def portable(v):
    return str(v).replace(str(LLVM_BUILD), '${LLVM_BUILD}').replace(str(LLVM_SRC), '${LLVM_SRC}').replace(str(BOOK_ROOT), '${BOOK_ROOT}').replace(str(out), '${OUTPUT}')
def run(name, tool, extra, allowed=(0,)):
    argv = [str(LLVM_BUILD/'bin'/tool)] + [str(x) for x in extra]
    proc = subprocess.run(argv, capture_output=True, text=True, timeout=180)
    (out/f'{name}.stdout').write_text(proc.stdout)
    (out/f'{name}.stderr').write_text(proc.stderr)
    commands.append({'name': name, 'argv': [portable(x) for x in argv], 'returncode': proc.returncode})
    if proc.returncode not in allowed:
        raise RuntimeError(f'{name}: {proc.stderr[-3000:]}')
    return proc.stdout, proc.stderr

def check(name, ok, observed):
    checks.append({'name': name, 'passed': bool(ok), 'observed': observed})
    if not ok: raise AssertionError(f'{name}: {observed}')
def bodies(path):
    s=path.read_text()
    return {m[1]:m[2].strip() for m in re.finditer(r'^name:\s+(\S+).*?^body:\s+\|\n(.*?)(?=^\.\.\.)',s,re.M|re.S)}
def llc(name, inp, triple, cpu, flags):
    dest=out/f'{name}.mir'
    run(name,'llc',[f'-mtriple={triple}',f'-mcpu={cpu}','-verify-machineinstrs',*flags,inp,'-o',dest])
    return bodies(dest)
check('teaching-bit-vectors-and-costs', True, run_models())
version,_=run('version','llc',['--version'])
for name in ['selection','globalisel','fastisel','legalization','softfloat']:
    run(f'verify-{name}','opt',['-passes=verify','-disable-output',HERE/f'{name}.ll'])
run('clang-callee','clang',['--target=bpfel','-mcpu=v1','-O0','-fno-discard-value-names','-S','-emit-llvm',HERE/'callee.c','-o',out/'callee.ll'])
run('verify-callee','opt',['-passes=verify','-disable-output',out/'callee.ll'])
callee=llc('callee-finalize',out/'callee.ll','bpfel','v1',['-O0','-fast-isel=false','-stop-after=finalize-isel','-debug-only=isel,isel-dump'])
v1=llc('bpf-v1',HERE/'selection.ll','bpfel','v1',['-O0','-fast-isel=false','-stop-after=finalize-isel','-debug-only=isel,isel-dump'])
v3=llc('bpf-v3',HERE/'selection.ll','bpfel','v3',['-O0','-fast-isel=false','-stop-after=finalize-isel'])
check('entry-token-two-results','ch,glue = EntryToken' in (out/'bpf-v1.stderr').read_text(),'EntryToken has chain and glue; getEntryNode() returns result 0.')
check('pattern-register', 'ADD_rr' in v1['add_reg'],v1['add_reg'])
check('pattern-immediate','ADD_ri' in v1['add_imm'] and ', 42' in v1['add_imm'],v1['add_imm'])
check('v1-promotes-register-not-memory','ADD_rr ' in v1['add32'] and 'ADD_rr_32' not in v1['add32'] and v1['add32'].count('(s32)') == 3,v1['add32'])
check('v3-alu32','ADD_rr_32' in v3['add32'] and 'LDW32' in v3['add32'] and 'STW32' in v3['add32'],v3['add32'])
check('machine-phi-survives-isel','PHI' in v1['choose'],v1['choose'])
check('caller-i32-object','STW ' in callee['caller'] and 'LDW ' in callee['caller'] and '(s32)' in callee['caller'],callee['caller'])
legal=llc('bpf-legalization',HERE/'legalization.ll','bpfel','v1',['-O0','-fast-isel=false','-stop-after=finalize-isel'])
check('signed-i16-expansion','SLL_ri' in legal['add16_signed'] and 'SRA_ri' in legal['add16_signed'] and ', 48' in legal['add16_signed'],legal['add16_signed'])
check('i128-two-halves',legal['add128'].count('LDD ')==4 and legal['add128'].count('STD ')==2 and legal['add128'].count('ADD_rr ')==3 and 'JUGT_rr ' in legal['add128'] and 'PHI ' in legal['add128'],legal['add128'])
check('vector-scalarization',legal['vector_add'].count('ADD_rr ')==2 and legal['vector_add'].count('STD ')==2,legal['vector_add'])
_,softdiag=run('bpf-softfloat-rejected','llc',['-mtriple=bpfel','-mcpu=v1','-O0','-fast-isel=false',HERE/'softfloat.ll','-o',out/'softfloat.s'],allowed=(1,))
check('softfloat-libcall-diagnostic',"__divdf3" in softdiag and "not supported" in softdiag,softdiag.strip())
inc=out/'BPFGenDAGISel.inc'
run('tablegen-bpf','llvm-tblgen',['-gen-dag-isel','-I',LLVM_SRC/'llvm/include','-I',LLVM_SRC/'llvm/lib/Target/BPF',LLVM_SRC/'llvm/lib/Target/BPF/BPF.td','-o',inc])
check('generated-matcher-table','MatcherTable' in inc.read_text() and 'BPF::ADD_ri' in inc.read_text(),{'bytes':inc.stat().st_size,'sha256':hashlib.sha256(inc.read_bytes()).hexdigest()})
fast_inc=out/'AArch64GenFastISel.inc'
run('tablegen-fast','llvm-tblgen',['-gen-fast-isel','-I',LLVM_SRC/'llvm/include','-I',LLVM_SRC/'llvm/lib/Target/AArch64',LLVM_SRC/'llvm/lib/Target/AArch64/AArch64.td','-o',fast_inc])
check('generated-fast-emitter','fastEmit_ISD_ADD' in fast_inc.read_text() and 'AArch64::ADDXrr' in fast_inc.read_text(),{'bytes':fast_inc.stat().st_size,'sha256':hashlib.sha256(fast_inc.read_bytes()).hexdigest()})
if not args.bpf_only:
    check('aarch64-registered',bool(re.search(r'^\s+aarch64\s+-',version,re.M)),version.strip())
    run('clang-globalisel','clang',['--target=aarch64-unknown-linux-gnu','-mcpu=generic','-O1','-S','-emit-llvm',HERE/'globalisel.c','-o',out/'globalisel-from-c.ll'])
    run('verify-globalisel-from-c','opt',['-passes=verify','-disable-output',out/'globalisel-from-c.ll'])
    gi={}
    for stage in ['irtranslator','legalizer','regbankselect','instruction-select']:
        gi[stage]=llc(f'gi-{stage}',HERE/'globalisel.ll','aarch64-unknown-linux-gnu','generic',['-O0','-global-isel=true','-global-isel-abort=1',f'-stop-after={stage}'])
    check('irtranslator-llt-s16','G_ADD' in gi['irtranslator']['add16'] and '(s16)' in gi['irtranslator']['add16'],gi['irtranslator']['add16'])
    check('legalizer-widens-s16',bool(re.search(r'\(s32\) = .*G_ADD',gi['legalizer']['add16'])) and not re.search(r'\(s16\) = .*G_ADD',gi['legalizer']['add16']),gi['legalizer']['add16'])
    check('bank-not-register-class','gpr(s32)' in gi['regbankselect']['or32'] and 'G_OR' in gi['regbankselect']['or32'],gi['regbankselect']['or32'])
    check('selected-target-opcode','ADDWrr' in gi['instruction-select']['add32'] and 'G_ADD' not in gi['instruction-select']['add32'],gi['instruction-select']['add32'])
    fast=llc('fastisel',HERE/'fastisel.ll','aarch64-unknown-linux-gnu','generic',['-O0','-global-isel=false','-fast-isel=true','-fast-isel-abort=3','-stop-after=finalize-isel','-debug-only=isel'])
    check('fastisel-without-fallback','ADDWrr' in fast['add32'],fast['add32'])
try:
    commit=subprocess.check_output(['git','-C',str(LLVM_SRC),'rev-parse','HEAD'],text=True).strip()
    dirty=subprocess.check_output(['git','-C',str(LLVM_SRC),'diff','--name-only'],text=True).splitlines()
except subprocess.CalledProcessError:commit,dirty=None,[]
report={'chapter':7,'scope':'bpf-only' if args.bpf_only else 'full','llvm_version':version.strip(),'llvm_commit':commit,'llvm_modified_tracked_files':dirty,'input_sha256':{x.name:hashlib.sha256(x.read_bytes()).hexdigest() for x in HERE.iterdir() if x.is_file()},'commands':commands,'checks':checks,'limitations':['Cross-target code generation and machine verification do not execute BPF or AArch64 machine code.','Debug node IDs and generated matcher offsets are observations, not stable APIs.','No compiler-speed or generated-program performance benchmark.']}
(out/'results.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
if args.summary:
    args.summary.parent.mkdir(parents=True,exist_ok=True)
    args.summary.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'chapter':7,'checks_passed':len(checks),'scope':report['scope'],'output':str(out)},ensure_ascii=False))
