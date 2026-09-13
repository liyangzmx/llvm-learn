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

def cfg(text,name):
    body=re.search(r"define[^\n]*@"+name+r"\(.*?^}",text,re.M|re.S)[0]
    graph={};current=None
    for line in body.splitlines()[1:]:
        match=re.match(r"^([-\w.]+):",line)
        if match:current=match[1];graph[current]=[]
        if current:graph[current]+=re.findall(r"label %([-\w.]+)",line)
    return graph
def loop_properties(g,header):
    root=next(iter(g));nodes=set(g);pred={n:{p for p in g if n in g[p]} for n in g};dom={n:({root} if n==root else nodes.copy()) for n in g}
    while True:
        old={n:v.copy() for n,v in dom.items()}
        for n in nodes-{root}:dom[n]={n}|set.intersection(*(dom[p] for p in pred[n]))
        if old==dom:break
    latches={p for p in pred[header] if header in dom[p]};loop={header};todo=list(latches)
    while todo:
        n=todo.pop()
        if n in loop:continue
        loop.add(n);todo.extend(pred[n])
    entering=pred[header]-loop;exits={s for n in loop for s in g[n] if s not in loop}
    return {"blocks":sorted(loop),"latches":sorted(latches),"entering":sorted(entering),"preheader":len(entering)==1 and len(g[next(iter(entering))])==1,"dedicated_exits":all(pred[e]<=loop for e in exits),"exits":sorted(exits)}
for name in ["multi-latch.ll","lcssa.ll","irreducible.ll","nested.ll"]:verify(HERE/name)
run("opt","-passes=loop-simplify,verify,verify<domtree>,verify<loops>","-S",HERE/"multi-latch.ll","-o",OUT/"simplified.ll")
before=loop_properties(cfg((HERE/"multi-latch.ll").read_text(),"multi"),"header")
after=loop_properties(cfg((OUT/"simplified.ll").read_text(),"multi"),"header")
check("loop_simplify_three_properties", not before["preheader"] and len(before["latches"])==2 and not before["dedicated_exits"] and after["preheader"] and len(after["latches"])==1 and after["dedicated_exits"],before=before,after=after)
interpret(HERE/"multi-latch.ll");interpret(OUT/"simplified.ll")
check("simplify_semantics",True,expected=[0,5,10,0])
run("opt","-passes=lcssa,verify","-S",HERE/"lcssa.ll","-o",OUT/"closed.ll")
closed=(OUT/"closed.ll").read_text()
check("lcssa_exit_phi",bool(re.search(r"%last\.lcssa = phi i32 \[ %last, %header \]",closed)) and "%result = add i32 %last.lcssa, 4" in closed)
interpret(HERE/"lcssa.ll");interpret(OUT/"closed.ll")
check("lcssa_semantics",True,expected=[11,24,14])
run("clang","--target=bpfel","-O0","-Xclang","-disable-O0-optnone","-fno-discard-value-names","-S","-emit-llvm",HERE/"book-loop.c","-o",OUT/"book-loop.ll")
run("opt","-passes=mem2reg,loop-simplify,lcssa,verify","-S",OUT/"book-loop.ll","-o",OUT/"before-rotate.ll")
run("opt","-passes=function(loop(loop-rotate),verify,verify<loops>,verify<domtree>)","-S",OUT/"before-rotate.ll","-o",OUT/"rotated.ll")
old=cfg((OUT/"before-rotate.ll").read_text(),"test");new=cfg((OUT/"rotated.ll").read_text(),"test")
rotated_properties=loop_properties(new,"for.body")
latch=rotated_properties["latches"][0]
rotated=any(s not in rotated_properties["blocks"] for s in new[latch])
check("rotation_changes_cfg",old!=new and rotated and rotated_properties["preheader"] and rotated_properties["dedicated_exits"] and len(new["entry"])==2,old_cfg=old,new_cfg=new,rotated_properties=rotated_properties)
interpret(OUT/"before-rotate.ll");interpret(OUT/"rotated.ll")
check("rotation_zero_one_many",True,inputs=[-1,0,1,5,8,12],expected=[1,1,1,120,40320,479001600])
r=run("opt","-passes=print<loops>","-disable-output",HERE/"nested.ll")
check("nested_loopinfo", "depth 1" in r.stderr and "depth 2" in r.stderr,report=r.stderr)
r=run("opt","-passes=print<loops>","-disable-output",HERE/"irreducible.ll")
check("irreducible_not_loopinfo", "Loop at depth" not in r.stderr,report=r.stderr)
finish()
