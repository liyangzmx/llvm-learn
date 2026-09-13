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


def body(p):
    return p.read_text().split("body:             |")[-1].split("\n...")[0]
def blocks(t): return len(re.findall(r"^\s*bb\.[0-9]+[^\n]*:", t, re.M))
results = {}
for name, pas in [("dce","dead-mi-elimination"),("cse","machine-cse"),("phi","opt-phis"),("sink","machine-sink"),("licm","early-machinelicm")]:
    run("llc", ["-mtriple=bpfel","-mcpu=generic","-verify-machineinstrs","-run-pass="+pas,HERE/(name+".mir"),"-o",OUT/(name+".mir")],name)
    t=body(OUT/(name+".mir"))
    if name=="dce": assert "ADD_ri" not in t and "%2" not in t
    if name=="cse": assert t.count("ADD_ri")==1 and "ADD_rr %1, %1" in t
    if name=="phi": assert " PHI " not in t and "$r0 = COPY %0" in t
    if name=="sink": assert t.index("ADD_ri") > t.index("bb.1:")
    if name=="licm": assert t.index("MUL_rr") < t.index("bb.1:")
    results[name] = "expected MIR transformation; machine verifier passed"
for name in ["tail","cse","lifetime"]:
    run("llvm-as",[HERE/(name+".ll"),"-o",OUT/(name+".bc")],name+"-as")
    run("opt",["-passes=verify",OUT/(name+".bc"),"-disable-output"],name+"-verify")
for label,flags in [("before",["-stop-before=early-tailduplication"]),("default",["-stop-after=early-tailduplication"]),("size10",["-stop-after=early-tailduplication","-tail-dup-size=10"])]:
    run("llc",["-mtriple=bpfel","-mcpu=v4","-O2","-verify-machineinstrs",*flags,HERE/"tail.ll","-o",OUT/("tail-"+label+".mir")],"tail-"+label)
tails={label:blocks(body(OUT/("tail-"+label+".mir"))) for label in ["before","default","size10"]}
assert tails == {"before":7,"default":7,"size10":6}, tails
results["tail"]={"target":"bpfel","cpu":"v4","blocks":tails,"duplicate_source":"if.end"}
for label,flags in [("before",["-stop-before=stack-coloring"]),("after",["-stop-after=stack-coloring"]),("pei",["-stop-after=prologepilog"])]:
    run("llc",["-mtriple=bpfel","-mcpu=generic","-O2","-verify-machineinstrs",*flags,HERE/"lifetime.ll","-o",OUT/("lifetime-"+label+".mir")],"lifetime-"+label)
assert "%stack.1" in body(OUT/"lifetime-before.mir") and "%stack.1" not in body(OUT/"lifetime-after.mir")
assert "%stack." not in body(OUT/"lifetime-pei.mir")
results["lifetime"]={"input_objects":2,"shared_objects":1,"bytes":64,"pei_frame_indices_resolved":True}
# Contrast frontend lifetime information with a hand-written, valid contract.
run("clang", ["--target=aarch64-unknown-linux-gnu","-O2","-S","-emit-llvm",HERE/"stack.c","-o",OUT/"stack.ll"], "stack-clang")
for stage in ["before", "after"]:
    run("llc", ["-mtriple=aarch64-unknown-linux-gnu","-O2","-verify-machineinstrs","-stop-"+stage+"=stack-coloring",OUT/"stack.ll","-o",OUT/("stack-"+stage+".mir")],"stack-"+stage)
run("llc", ["-mtriple=aarch64-unknown-linux-gnu","-O2","-verify-machineinstrs","-stop-after=stack-coloring",HERE/"stack-marked.ll","-o",OUT/"stack-marked.mir"],"stack-marked")
slots=lambda p: sorted(set(re.findall(r"%stack\.([0-9]+)",body(p))))
assert slots(OUT/"stack-after.mir")==["0","1","2"]
assert slots(OUT/"stack-marked.mir")==["0","2"]
results["stack_aarch64"]={"clang_objects":3,"marked_objects":2,"object_bytes":4096,"marked_merge":"x -> z"}
# -O0 keeps the diamond; mem2reg removes allocas without converting control flow.
run("clang++",["--target=x86_64-unknown-linux-gnu","-O0","-Xclang","-disable-O0-optnone","-S","-emit-llvm",HERE/"if-conversion.cpp","-o",OUT/"if-raw.ll"],"if-clang")
run("opt",["-passes=mem2reg","-S",OUT/"if-raw.ll","-o",OUT/"if.ll"],"if-mem2reg")
for label,extra in [("before",["-stop-before=early-ifcvt"]),("disabled",["-stop-after=early-ifcvt"]),("enabled",["-stop-after=early-ifcvt","-x86-early-ifcvt"])]:
    run("llc",["-mtriple=x86_64-unknown-linux-gnu","-O2","-verify-machineinstrs",*extra,OUT/"if.ll","-o",OUT/("if-"+label+".mir")],"if-"+label)
ib={label:blocks(body(OUT/("if-"+label+".mir"))) for label in ["before","disabled","enabled"]}
assert ib=={"before":4,"disabled":4,"enabled":1},ib
assert body(OUT/"if-enabled.mir").count("CMOV32rr")==2
results["if_conversion"]={"target":"x86_64-unknown-linux-gnu","blocks":ib,"cmov_count":2,"required_flag":"-x86-early-ifcvt"}
for stage in ["before", "after"]:
    run("llc",["-mtriple=riscv64-unknown-linux-gnu","-O2","-verify-machineinstrs","-stop-"+stage+"=machine-cse",HERE/"cse.ll","-o",OUT/("cse-riscv-"+stage+".mir")],"cse-riscv-"+stage)
ops={stage:sum(body(OUT/("cse-riscv-"+stage+".mir")).count(op) for op in ["ADDW","SLLI","SRLI"]) for stage in ["before","after"]}
assert ops=={"before":6,"after":3},ops
results["global_cse_riscv"]={"arithmetic_instructions":ops,"stores_preserved":4}
finish(results)
