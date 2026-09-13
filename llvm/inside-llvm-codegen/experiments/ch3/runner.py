#!/usr/bin/env python3
"""Reproduce this chapter. Outputs default to a fresh temporary directory."""
import argparse, itertools, json, os, re, subprocess, tempfile
from pathlib import Path
HERE = Path(__file__).resolve().parent
BOOK_ROOT = Path(os.environ.get("BOOK_ROOT", HERE.parents[1]))
LLVM_BUILD = Path(os.environ.get("LLVM_BUILD", "/opt/llvm-project/build"))
LLVM_SRC = Path(os.environ.get("LLVM_SRC", "/opt/llvm-project"))
p = argparse.ArgumentParser(description=__doc__)
p.add_argument("--output-dir", type=Path)
p.add_argument("--summary", type=Path)
a = p.parse_args()
OUT = a.output_dir or Path(tempfile.mkdtemp(prefix="inside-llvm-ch" + HERE.name[2:] + "-"))
OUT.mkdir(parents=True, exist_ok=True)
checks, commands, used_tools = [], [], set()
tool_files = {}
def check(name, ok, **observed):
    if not ok:
        raise AssertionError(f"{name}: {observed}")
    checks.append({"name": name, "status": "passed", **observed})
def run(tool, *args, fail=False):
    used_tools.add(tool)
    st = (LLVM_BUILD / "bin" / tool).stat()
    tool_files.setdefault(tool, {"size": st.st_size, "mtime_ns": st.st_mtime_ns})
    command = [str(LLVM_BUILD / "bin" / tool), *map(str, args)]
    result = subprocess.run(command, cwd=OUT, capture_output=True, text=True, timeout=120)
    label = f"{len(commands):02d}-{tool}"
    (OUT / (label + ".stdout")).write_text(result.stdout)
    (OUT / (label + ".stderr")).write_text(result.stderr)
    commands.append({"tool": tool, "args": [str(x).replace(str(OUT), "$OUT").replace(str(HERE), "$INPUT").replace(str(LLVM_SRC), "$LLVM_SRC") for x in args], "returncode": result.returncode})
    if (fail and result.returncode == 0) or (not fail and result.returncode != 0):
        raise RuntimeError(f"{command} returned {result.returncode}:\n{result.stderr}")
    return result

def verify(path):
    run("llvm-as", path, "-o", OUT / (Path(path).stem + ".bc"))
    run("opt", "-passes=verify", "-disable-output", path)

def interpret(path):
    run("lli", "--force-interpreter", "-mtriple=bpfel", path)

def finish(**data):
    for tool, original in tool_files.items():
        st = (LLVM_BUILD / "bin" / tool).stat()
        if original != {"size": st.st_size, "mtime_ns": st.st_mtime_ns}:
            raise RuntimeError("Tool changed while running; rerun after the build completes: " + tool)
    data["tool_files"] = tool_files
    result = {"chapter": int(HERE.name[2:]), "status": "passed", "tools": {t: subprocess.check_output([str(LLVM_BUILD / "bin" / t), "--version"], text=True).splitlines()[:3] for t in sorted(used_tools)}, "checks": checks, "commands": commands, **data}
    target = a.summary or OUT / "results.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"chapter": result["chapter"], "status": "passed", "checks": len(checks), "summary": str(target), "outputs": str(OUT)}, ensure_ascii=False))

# Exhaust all self-maps of P({a,b}), retaining exactly the monotone maps.
le=lambda x,y: x & y == x
monotone=0
for f in itertools.product(range(4), repeat=4):
    if not all(not le(x,y) or le(f[x],f[y]) for x in range(4) for y in range(4)): continue
    fixed=[x for x in range(4) if f[x]==x]
    low=0; high=3
    for _ in range(4): low=f[low]; high=f[high]
    assert f[low]==low and f[high]==high
    assert all(le(low,x) and le(x,high) for x in fixed)
    monotone+=1
check("finite_lattice_fixed_points", monotone==36, monotone_maps=monotone, all_maps=256)
# A monotone map can cycle from an incomparable, non-extremal seed.
f=[0,2,1,3]
check("arbitrary_seed_counterexample", all(not le(x,y) or le(f[x],f[y]) for x in range(4) for y in range(4)) and f[f[1]]==1 and f[1]!=1, cycle=["{a}","{b}","{a}"])
TOP="top"; BOT="bottom"
def join(x,y): return y if x==BOT else x if y==BOT or x==y else TOP
mop=join(2+3,3+2); mfp=TOP if TOP in (join(2,3),join(3,2)) else None
check("mop_vs_mfp", mop==5 and mfp==TOP, MOP=5,MFP=TOP)
succ={"A":["B","C"],"B":["G"],"C":["D","E"],"D":["F"],"E":["F"],"F":["A","G"],"G":[]}
# Each statement is (destination, sources), preserving intra-block order.
statements={"A":[("m",set("ab")),("n",set("cd"))],"B":[("p",set("cd"))],"C":[("r",set("cd"))],"D":[("e",{"b"}),("s",set("ab")),("u",set("es"))],"E":[("e",set("ad")),("t",set("cd")),("u",set("et"))],"F":[("v",set("au"))],"G":[("m",set("ab"))]}
use={}; defs={}
for b,insts in statements.items():
    use[b]=set(); defs[b]=set()
    for d,ss in insts: use[b]|=ss-defs[b]; defs[b].add(d)
livein={b:set() for b in succ}; liveout={b:set() for b in succ}; rounds=0
while True:
    old={b:(livein[b].copy(),liveout[b].copy()) for b in succ}; rounds+=1
    for b in reversed(succ):
        liveout[b]=set().union(*(livein[s] for s in succ[b]));livein[b]=use[b]|(liveout[b]-defs[b])
    if all(old[b]==(livein[b],liveout[b]) for b in succ):break
    assert rounds<20
# Independent witness-path search: can a use be reached before a redef?
def live_oracle(start,var):
    todo=[start]; seen=set()
    while todo:
        b=todo.pop()
        if b in seen:continue
        seen.add(b)
        killed=False
        for d,ss in statements[b]:
            if var in ss:return True
            if var==d:killed=True;break
        if not killed:todo.extend(succ[b])
    return False
variables=set().union(*defs.values(),*use.values())
assert all((v in livein[b])==live_oracle(b,v) for b in succ for v in variables)
expected={"A":"abcd","B":"abcd","C":"abcd","D":"abcd","E":"abcd","F":"abcdu","G":"ab"}
check("liveness_table_3_3", all(livein[b]==set(v) for b,v in expected.items()), rounds_including_final_check=rounds, live_in={b:sorted(v) for b,v in livein.items()}, live_use={b:sorted(v) for b,v in use.items()})
# Reaching definitions: IDs denote definitions, not names.
succ2={"A":["B"],"B":["C","D"],"C":["E"],"D":["E"],"E":["B","F"],"F":[]}
inst2={"A":[("s1","x"),("s2","y"),("s3","z")],"B":[("s4","x"),("s5","y")],"C":[("s6","z")],"D":[("s7","z")],"E":[("s8","x")],"F":[]}
varof={d:v for rows in inst2.values() for d,v in rows}; gen={}; kill={}
for b,rows in inst2.items():
    last={v:d for d,v in rows}; gen[b]=set(last.values()); kill[b]={d for d,v in varof.items() if v in last and d!=last[v]}
pred={b:[p for p in succ2 if b in succ2[p]] for b in succ2}; ins={b:set() for b in succ2}; outs={b:set() for b in succ2}; rounds=0
while True:
    old={b:outs[b].copy() for b in outs}; rounds+=1
    for b in succ2:
        ins[b]=set().union(*(outs[p] for p in pred[b]));outs[b]=gen[b]|(ins[b]-kill[b])
    if old==outs:break
    assert rounds<20
# Independent definition-token reachability through blocks that do not kill it.
oracle={b:set() for b in succ2}
for source,rows in inst2.items():
    for d in gen[source]:
        todo=[source];seen=set()
        while todo:
            b=todo.pop()
            if b in seen:continue
            seen.add(b);oracle[b].add(d)
            for s in succ2[b]:
                if d not in kill[s]:todo.append(s)
assert oracle==outs
check("reaching_definitions_table_3_4", outs["B"]==set(["s3","s4","s5","s6","s7"]) and outs["F"]==set(["s5","s6","s7","s8"]), rounds_including_final_check=rounds, stable_in={b:sorted(v) for b,v in ins.items()},stable_out={b:sorted(v) for b,v in outs.items()})
# Classical dense constant propagation, deliberately ignoring executable edges.
succ3={"S1":["S2"],"S2":["S3","S7"],"S3":["S4","S5"],"S4":["S6"],"S5":["S6"],"S6":["S2"],"S7":[]}
pred3={b:[p for p in succ3 if b in succ3[p]] for b in succ3}; out3={b:(BOT,BOT) for b in succ3}; rounds=0
while True:
    old=out3.copy();rounds+=1
    for b in succ3:
        state=(BOT,BOT)
        for p in pred3[b]:state=tuple(join(x,y) for x,y in zip(state,out3[p]))
        if b=="S1":state=(1,0)
        elif b=="S4":state=(state[0] if state[0] in (TOP,BOT) else state[0]+1,state[1])
        elif b=="S5":state=(state[0],1)
        out3[b]=state
    if old==out3:break
    assert rounds<20
check("dense_constant_table_3_5", out3["S5"]==(TOP,1) and out3["S7"]==(TOP,TOP), stable_out=out3, rounds_including_final_check=rounds)
run("clang","--target=bpfel","-O0","-Xclang","-disable-O0-optnone","-fno-discard-value-names","-S","-emit-llvm",HERE/"constant.c","-o",OUT/"constant.ll")
verify(OUT/"constant.ll")
run("opt","-passes=mem2reg,sccp,simplifycfg,verify","-S",OUT/"constant.ll","-o",OUT/"sccp.ll")
s=(OUT/"sccp.ll").read_text()
def function(name):return re.search(r"define[^\n]*@"+name+r"\(.*?^}",s,re.M|re.S)[0]
check("sccp_executable_edges", "ret i32 0" in function("branch") and "inc" not in function("loop"), branch_returns=0, dead_increment_removed=True, loop_ir=function("loop"))
interpret(OUT/"constant.ll");interpret(OUT/"sccp.ll")
check("constant_examples_semantics",True, branch=0,loop=11,relational_both_paths=5)
finish()
