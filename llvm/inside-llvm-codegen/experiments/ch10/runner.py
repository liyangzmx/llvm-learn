#!/usr/bin/env python3
"""Run with Python 3; artifacts go to a temporary directory unless --out is set."""
import argparse, hashlib, json, os, re, subprocess, tempfile
from pathlib import Path
HERE = Path(__file__).resolve().parent
BOOK_ROOT = Path(os.environ.get("BOOK_ROOT", HERE.parent.parent)).resolve()
LLVM_BUILD = Path(os.environ.get("LLVM_BUILD", "/opt/llvm-project/build")).resolve()
LLVM_SRC = Path(os.environ.get("LLVM_SRC", "/opt/llvm-project")).resolve()
p = argparse.ArgumentParser(description=__doc__)
p.add_argument("--out", type=Path)
a = p.parse_args()
OUT = a.out.resolve() if a.out else Path(tempfile.mkdtemp(prefix=HERE.name + "-llvm18-"))
OUT.mkdir(parents=True, exist_ok=True)
commands = []
def run(tool, args, label):
    cmd = [str(LLVM_BUILD / "bin" / tool), *map(str, args)]
    r = subprocess.run(cmd, cwd=OUT, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (OUT / (label + ".stdout")).write_text(r.stdout)
    (OUT / (label + ".stderr")).write_text(r.stderr)
    commands.append({"name": label, "argv": cmd, "exit_code": r.returncode})
    if r.returncode:
        raise RuntimeError(f"{label} failed ({r.returncode}); see {OUT / (label + '.stderr')}")
    return r.stdout
version = run("llc", ["--version"], "version")
assert "18.1.8" in version, "This chapter's expected results target LLVM 18.1.8"
def finish(results):
    payload = {"llvm_version": "18.1.8", "llvm_build": str(LLVM_BUILD),
       "source_root": str(LLVM_SRC), "book_root": str(BOOK_ROOT),
       "source_commit": subprocess.check_output(["git", "-C", str(LLVM_SRC), "rev-parse", "HEAD"], text=True).strip(),
       "input_sha256": {f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(HERE.iterdir()) if f.is_file()},
       "results": results, "commands": commands}
    (OUT / "results.json").write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps({"out": str(OUT), "results": results}, indent=2, ensure_ascii=False))

base = ["-mtriple=bpfel", "-mcpu=generic", "-O2", "-verify-machineinstrs"]
for name in ["sum", "bubble"]:
    run("llvm-as", [HERE/(name+".ll"), "-o", OUT/(name+".bc")], name+"-as")
    run("opt", ["-passes=verify", OUT/(name+".bc"), "-disable-output"], name+"-verify")
stages = ["finalize-isel", "livevars", "phi-node-elimination", "twoaddressinstruction", "register-coalescer", "virtregrewriter", "prologepilog"]
for stage in stages:
    run("llc", base + ["-stop-after="+stage, HERE/"sum.ll", "-o", OUT/("sum-"+stage+".mir")], "sum-"+stage)
pre = (OUT/"sum-livevars.mir").read_text().split("body:             |")[-1]
post = (OUT/"sum-phi-node-elimination.mir").read_text().split("body:             |")[-1]
assert " PHI " in pre and " PHI " not in post
assert "COPY" in post
for stage in ["regallocfast", "prologepilog"]:
    run("llc", base + ["-regalloc=fast", "-optimize-regalloc=0", "-stop-"+("before=" if stage=="regallocfast" else "after=")+stage, HERE/"sum.ll", "-o", OUT/("sum-fast-"+stage+".mir")], "sum-fast-"+stage)
run("llc", base + ["-debug-only=regalloc,machine-block-freq", HERE/"sum.ll", "-o", OUT/"sum.s"], "sum-trace")
(OUT/"bubble.ll").write_text((HERE/"bubble.ll").read_text())
counts = {}
for alloc in ["fast", "basic", "greedy", "pbqp"]:
    flags = base + ["-regalloc="+alloc, "-optimize-regalloc="+("0" if alloc=="fast" else "1")] + (["-pbqp-coalescing=false"] if alloc=="pbqp" else [])
    run("llc", flags + [OUT/"bubble.ll", "-filetype=obj", "-o", OUT/(alloc+".o")], alloc+"-object")
    run("llc", flags + (["-pbqp-dump-graphs"] if alloc == "pbqp" else []) + [OUT/"bubble.ll", "-o", OUT/(alloc+".s"), "-debug-only=regalloc,regalloc-pbqp,spill-code-placement,edge-bundles"], alloc+"-trace")
    run("llc", flags + [OUT/"bubble.ll", "-stop-after=prologepilog", "-o", OUT/(alloc+".mir")], alloc+"-mir")
    dis = run("llvm-objdump", ["-d", OUT/(alloc+".o")], alloc+"-disassembly")
    asm = (OUT/(alloc+".s")).read_text()
    mir = (OUT/(alloc+".mir")).read_text()
    count = len(re.findall(r"^\s*[0-9]+:", dis, re.M))
    slots = len(re.findall(r"type: spill-slot", mir))
    loads = len(re.findall(r"= \*\(u64 \*\)\(r10", asm))
    stores = len(re.findall(r"\*\(u64 \*\)\(r10[^\n]*=", asm))
    assert "%stack." not in mir.split("body:             |")[-1]
    assert " PHI " not in mir.split("body:             |")[-1]
    counts[alloc] = {"machine_instruction_count":count, "spill_slots":slots, "stack_loads":loads, "stack_stores":stores}
# Host execution checks IR semantics separately from BPF machine-code verification.
combined = (HERE/"sum.ll").read_text() + (HERE/"bubble.ll").read_text().replace("declare dso_local void @swap(ptr, ptr)", "") + (HERE/"check.ll").read_text()
(OUT/"check.ll").write_text(combined)
run("llvm-as", [OUT/"check.ll", "-o", OUT/"check.bc"], "check-as")
# lli interpreter avoids reliance on a matching JIT backend; it executes the IR.
run("lli", ["-force-interpreter", OUT/"check.bc"], "ir-semantics")
# Also compile the C listings themselves, retaining calls so their bodies execute.
cinput=(HERE/"sum.c").read_text()+(HERE/"bubble.c").read_text()+(HERE/"bubble-inline.c").read_text().replace("bubbleSort(","bubbleSortInline(")+(HERE/"check-c.c").read_text()
(OUT/"check-c.c").write_text(cinput)
run("clang",["-O1","-fno-inline-functions","-S","-emit-llvm",OUT/"check-c.c","-o",OUT/"check-c.ll"],"c-listings-compile")
run("lli",["-force-interpreter",OUT/"check-c.ll"],"c-listings-semantics")
for name in ["add-x86","lea-x86"]:
    run("llvm-mc",["--triple=x86_64-unknown-linux-gnu","--filetype=obj",HERE/(name+".s"),"-o",OUT/(name+".o")],name)
    run("llvm-objdump",["-d",OUT/(name+".o")],name+"-disassembly")
# Recompute the boundary equivalence relation from emitted MIR CFG, not hand-coded edges.
boundaries=[];edges=[];curr=None
for line in (OUT/"basic.mir").read_text().split("body:             |")[-1].splitlines():
    m=re.match(r"\s*bb\.(\d+)[^:]*:",line)
    if m:
        curr=int(m[1]);boundaries.extend([(curr,"in"),(curr,"out")])
    if "successors:" in line:
        edges.extend([(curr,int(x)) for x in re.findall(r"%bb\.(\d+)",line)])
parent={x:x for x in boundaries}
def find(x):
    if parent[x]!=x:parent[x]=find(parent[x])
    return parent[x]
for a,b in edges:parent[find((a,"out"))]=find((b,"in"))
groups={}
for x in boundaries:groups.setdefault(find(x),[]).append(f"BB.{x[0]}.{x[1]}")
bundles=list(groups.values())
assert len(bundles)==7 and len(boundaries)==18
expected={"fast":(67,10,18,10),"basic":(53,1,2,1),"greedy":(56,1,1,1),"pbqp":(53,1,2,1)}
for alloc,row in counts.items():assert tuple(row.values())==expected[alloc],row
from models import run_models
models=run_models()
finish({"target":"bpfel", "cpu":"generic", "optimization":"O2", "fast_optimized_regalloc":False,
        "allocators":counts, "edge_bundles":bundles, "models":models, "C_listings":"sum and both sorting variants compiled; interpreter returned 0", "x86_snippets":"add/mov and lea assembled and disassembled", "phi_elimination":"PHI removed; COPY inserted", "machine_verifier":"passed",
        "ir_semantics":"sum=45; bubbleSort matches [-9,-2,0,1,1,3,7,7]; n=0,1 leave array unchanged",
        "execution_scope":"LLVM IR interpreter plus BPF code generation; no BPF kernel/JIT execution or timings."})
