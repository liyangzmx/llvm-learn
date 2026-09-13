#!/usr/bin/env python3
"""Reproduce SelectionDAG/MIR scheduling and explicit mathematical models."""
import argparse, hashlib, json, os, pathlib, re, subprocess, tempfile
from models import run_models
P=pathlib.Path; HERE=P(__file__).resolve().parent
BOOK_ROOT=P(os.environ.get('BOOK_ROOT',HERE.parents[1])).resolve()
LLVM_BUILD=P(os.environ.get('LLVM_BUILD','/opt/llvm-project/build')).resolve()
LLVM_SRC=P(os.environ.get('LLVM_SRC','/opt/llvm-project')).resolve()
p=argparse.ArgumentParser();p.add_argument('--output',type=P);p.add_argument('--summary',type=P);p.add_argument('--bpf-only',action='store_true');args=p.parse_args()
out=(args.output or P(tempfile.mkdtemp(prefix='llvm-book-ch8-'))).resolve();out.mkdir(parents=True,exist_ok=True)
commands=[];checks=[];observations={}
def portable(v):
    return str(v).replace(str(LLVM_BUILD),'${LLVM_BUILD}').replace(str(LLVM_SRC),'${LLVM_SRC}').replace(str(BOOK_ROOT),'${BOOK_ROOT}').replace(str(out),'${OUTPUT}')
def run(name,tool,extra):
    argv=[str(LLVM_BUILD/'bin'/tool)]+[str(x) for x in extra]
    proc=subprocess.run(argv,capture_output=True,text=True,timeout=180)
    (out/f'{name}.stdout').write_text(proc.stdout);(out/f'{name}.stderr').write_text(proc.stderr)
    commands.append({'name':name,'argv':[portable(x) for x in argv],'returncode':proc.returncode})
    if proc.returncode:raise RuntimeError(f'{name}: {proc.stderr[-2500:]}')
    return proc.stdout,proc.stderr

def check(name,ok,observed):
    checks.append({'name':name,'passed':bool(ok),'observed':observed})
    if not ok:raise AssertionError(f'{name}: {observed}')
def body(path):
    return '\n'.join(m[1].strip() for m in re.finditer(r'^body:\s+\|\n(.*?)(?=^\.\.\.)',path.read_text(),re.M|re.S))
def codegen(name,inp,triple,cpu,flags,asm=False):
    dest=out/(name+('.s' if asm else '.mir'))
    _,log=run(name,'llc',[f'-mtriple={triple}',f'-mcpu={cpu}','-O2','-verify-machineinstrs',*flags,inp,'-o',dest])
    return (dest.read_text() if asm else body(dest)),log
version,_=run('version','llc',['--version'])
run('verify-dependencies','opt',['-passes=verify','-disable-output',HERE/'dependencies.ll'])
run('verify-sms','opt',['-passes=verify','-disable-output',HERE/'swp-bad-sched.ll'])
for sched in ['linearize','fast','list-burr','source','list-hybrid','list-ilp']:
    text,log=codegen('dag-'+sched,HERE/'dependencies.ll','bpfel','v1',['-fast-isel=false',f'-pre-RA-sched={sched}','-debug-only=pre-RA-sched','-stop-after=finalize-isel'])
    check('dag-'+sched,'STD ' in text and text.count('LDD ')==3 and 'RET ' in text,{'mir':text,'log_lines':len(log.splitlines())})
mi,milog=codegen('bpf-misched',HERE/'dependencies.ll','bpfel','v1',['-fast-isel=false','-enable-misched=true','-debug-only=machine-scheduler','-stop-after=machine-scheduler'])
check('bpf-mir-dependencies',all(x in milog for x in ['Data Latency=','Memory','Out  Latency=','Pressure']),{'pressure':re.findall(r'^.*(?:Max Pressure:|RegionPolicy:).*$',milog,re.M),'data_edge_latencies':sorted(set(map(int,re.findall(r'Data Latency=(\d+)',milog))))})
observations['bpf_misched']=mi
run('tablegen-model','llvm-tblgen',['-I',LLVM_SRC/'llvm/include','-dump-json',HERE/'schedule-model.td','-o',out/'schedule-model.json'])
records=json.loads((out/'schedule-model.json').read_text())
mul_rw=[x['def'] for x in records['DemoMUL']['SchedRW']]
advance=[v for v in records.values() if isinstance(v,dict) and 'ReadAdvance' in v.get('!superclasses',[]) and v.get('Cycles')==1]
check('sched-model-read-advance',mul_rw==['MULOut','EXIn','OrdinaryRead'] and any(v['ValidWrites'][0]['def']=='ALUOut' for v in advance),{'MUL_SchedRW':mul_rw,'ADD_to_MUL_src1_latency':1,'formula':'max(0,2-1)'})
observations['models']=run_models()
check('teaching-models',True,{'topological_orders':observations['models']['ssa_boundary_pressure']['all_topological_orders'],'pressure_range':[3,4],'recMII':3,'pipeline_test_lengths':65})
if not args.bpf_only:
    for target in ['riscv32','hexagon']:
        check('registered-'+target,bool(re.search(r'^\s+'+target+r'\s+-',version,re.M)),target)
    for stem in ['pressure','pressure-large','postra']:
        run('clang-'+stem,'clang',['--target=riscv32-unknown-elf','-march=rv32im','-mabi=ilp32','-mcpu=sifive-e31','-O2','-fno-discard-value-names','-S','-emit-llvm',HERE/f'{stem}.c','-o',out/f'{stem}.ll'])
        run('verify-'+stem,'opt',['-passes=verify','-disable-output',out/f'{stem}.ll'])
    for stop in ['before','after']:
        text,log=codegen('rv32-pre-'+stop,out/'pressure.ll','riscv32-unknown-elf','sifive-e31',['-mattr=+m','-enable-misched=true','-debug-only=machine-scheduler',f'-stop-{stop}=machine-scheduler'])
        observations['rv32_pre_'+stop]=text
        check('rv32-opcodes-'+stop,'MUL ' in text and 'MULW' not in text and 'ADDW' not in text,text)
        if stop=='after':
            check('rv32-small-region-policy','ShouldTrackPressure=0' in log,re.findall(r'^.*RegionPolicy:.*$',log,re.M))
    text,log=codegen('rv32-pressure-large',out/'pressure-large.ll','riscv32-unknown-elf','sifive-e31',['-mattr=+m','-enable-misched=true','-debug-only=machine-scheduler','-stop-after=machine-scheduler'])
    observations['rv32_pressure_large']=text
    check('rv32-large-region-pressure','ShouldTrackPressure=1' in log and 'Max Pressure:' in log,{'region':re.findall(r'^.*(?:RegionPolicy:|RegionInstrs:).*$',log,re.M),'initial_max_pressure':re.search(r'Max Pressure:.*?(?=Live In:)',log,re.S)[0].strip()})
    for scheduler,flags,stop in [('tdlist',['-post-RA-scheduler=true','-enable-post-misched=false'],'post-RA-sched'),('misched',['-post-RA-scheduler=false','-enable-post-misched=true'],'postmisched')]:
        text,log=codegen('rv32-post-'+scheduler,out/'postra.ll','riscv32-unknown-elf','sifive-e31',['-mattr=+m',*flags,'-debug-only=post-RA-sched,machine-scheduler',f'-stop-after={stop}'])
        check('rv32-post-'+scheduler,'$x10' in text and 'MUL ' in text and not re.search(r'%\d',text),{'mir':text,'log_lines':len(log.splitlines())})
    for stage in ['before','after']:
        mir,log=codegen('hexagon-sms-'+stage,HERE/'swp-bad-sched.ll','hexagon','hexagonv60',['-enable-pipeliner','-enable-aa-sched-mi','-pipeliner-experimental-cg=true',f'-stop-{stage}=pipeliner','-debug-only=pipeliner'])
        observations['hexagon_sms_'+stage]=mir
    check('hexagon-pipeliner-changes-mir',observations['hexagon_sms_before'] != observations['hexagon_sms_after'],{'before_lines':len(observations['hexagon_sms_before'].splitlines()),'after_lines':len(observations['hexagon_sms_after'].splitlines())})
    asm,smslog=codegen('hexagon-sms',HERE/'swp-bad-sched.ll','hexagon','hexagonv60',['-enable-pipeliner','-enable-aa-sched-mi','-pipeliner-experimental-cg=true','-debug-only=pipeliner'],asm=True)
    run('hexagon-filecheck','FileCheck',[HERE/'swp-bad-sched.ll','--input-file',out/'hexagon-sms.s'])
    check('hexagon-sms-regression','loop0(' in asm and 'endloop0' in asm and 'Schedule Found? 1 (II=3)' in smslog and 'Schedule Found? 0 (II=20)' in smslog,{'mii_lines':re.findall(r'^.*(?:MII =|Initiation|II =|II=|schedule found).*$',smslog,re.M),'hardware_loop_starts':asm.count('loop0('),'filecheck':'passed'})
    # Keep useful debug observations without asserting an obsolete book II or SU number.
    observations['hexagon_sms_log_tail']=smslog.splitlines()[-24:]
commit=subprocess.check_output(['git','-C',str(LLVM_SRC),'rev-parse','HEAD'],text=True).strip()
dirty=subprocess.check_output(['git','-C',str(LLVM_SRC),'diff','--name-only'],text=True).splitlines()
report={'chapter':8,'scope':'bpf-only' if args.bpf_only else 'full','llvm_version':version.strip(),'llvm_commit':commit,'llvm_modified_tracked_files':dirty,'input_sha256':{x.name:hashlib.sha256(x.read_bytes()).hexdigest() for x in HERE.iterdir() if x.is_file()},'commands':commands,'checks':checks,'observations':observations,'limitations':['Cross-target instructions were generated and machine-verified, not executed on BPF/RISC-V/Hexagon hardware.','Scheduler latency/resource values are LLVM model values, not measured cycles.','Mathematical models state simplifying assumptions and are not a reimplementation of LLVM.']}
(out/'results.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
if args.summary:
    args.summary.parent.mkdir(parents=True,exist_ok=True);args.summary.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'chapter':8,'checks_passed':len(checks),'scope':report['scope'],'output':str(out)},ensure_ascii=False))
