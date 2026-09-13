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

verify(HERE / "add.ll")
verify(HERE / "edge-selection.ll")
interpret(HERE / "edge-selection.ll")
check("explicit_edge_values", True, selected_values=[1, 2])
for name, diagnostic in [("bad-dominance.ll", "does not dominate"), ("bad-phi.ll", "PHINode should have one entry"), ("bad-duplicate-edge.ll", "multiple entries for the same basic block")]:
    r = run("opt", "-passes=verify", "-disable-output", HERE / name, fail=True)
    check(name, diagnostic in r.stderr, diagnostic=diagnostic)
run("mlir-opt", HERE / "edge-values.mlir", "--convert-arith-to-llvm", "--convert-func-to-llvm", "--convert-cf-to-llvm", "--reconcile-unrealized-casts", "-o", OUT / "edge-values-llvm.mlir")
lowered = (OUT / "edge-values-llvm.mlir").read_text()
destinations = re.search(r"llvm.cond_br.*?\^(\w+)\([^\n]+?\^(\w+)\(", lowered)
check("mlir_llvm_dialect_preserves_edge_arguments", destinations is not None and destinations[1] == destinations[2])
run("mlir-translate", OUT / "edge-values-llvm.mlir", "--mlir-to-llvmir", "-o", OUT / "edge-values.ll")
verify(OUT / "edge-values.ll")
translated = (OUT / "edge-values.ll").read_text().split("define i32 @choose", 1)[1].split("\n}", 1)[0]
destinations = re.search(r"br i1 %\w+, label %(\w+), label %(\w+)", translated)
check("mlir_export_splits_duplicate_successor", destinations is not None and destinations[1] != destinations[2] and translated.count(" phi i32 ") == 2, phi_count=translated.count(" phi i32 "))
interpret(OUT / "edge-values.ll")
check("mlir_edge_argument_semantics", True, selected_values=[1, 2])
ast = run("clang", "--target=bpfel", "-Xclang", "-ast-dump", "-fsyntax-only", HERE / "examples.c").stdout
check("clang_ast", all(x in ast for x in ["FunctionDecl", "CompoundStmt", "ReturnStmt", "BinaryOperator"]))
run("clang", "--target=bpfel", "-O0", "-Xclang", "-disable-O0-optnone", "-fno-discard-value-names", "-S", "-emit-llvm", HERE / "examples.c", "-o", OUT / "before.ll")
verify(OUT / "before.ll")
run("opt", "-passes=mem2reg,verify", "-S", OUT / "before.ll", "-o", OUT / "ssa.ll")
ssa = (OUT / "ssa.ll").read_text()
check("mem2reg_promotes", "alloca" not in ssa and " phi i32 " in ssa, phi_count=ssa.count(" phi i32 "))
pruned = re.search(r"define.*?@pruned\(.*?^}", ssa, re.M | re.S)[0].split("@pruned", 1)[1]
check("dead_phi_pruning", " phi " not in pruned)
interpret(OUT / "before.ll")
interpret(OUT / "ssa.ll")
check("c_examples_before_after", True, scalar_expectations={"add":12,"factor_5":120,"choose_42":44,"choose_43":1,"sum10":45,"lost_copy":10,"swap_0_1_2_9":[0,2,0,2]}, assertions=15)
run("opt", "-passes=dot-cfg", "-disable-output", OUT / "ssa.ll")
check("cfg_dot", any("factor" in p.name for p in OUT.glob("*.dot")))
verify(HERE / "machine-phi.ll")
for stage in ["before", "after"]:
    run("llc", "-mtriple=bpfel", "-mcpu=v1", "-O0", "-verify-machineinstrs", f"-stop-{stage}=phi-node-elimination", HERE / "machine-phi.ll", "-o", OUT / (stage + ".mir"))
before = (OUT / "before.mir").read_text(); after = (OUT / "after.mir").read_text()
check("machine_phi_elimination", " = PHI " in before and " = PHI " not in after and "COPY" in after, before_phi_count=before.count(" = PHI "), after_phi_count=after.count(" = PHI "))
def sequentialize(assignments):
    pending = {d:s for d,s in assignments.items() if d != s}; seq=[]; serial=0
    while pending:
        ready = next((d for d in pending if d not in pending.values()), None)
        if ready is not None:
            seq.append((ready, pending.pop(ready)))
        else:
            dst = next(iter(pending)); temp = f"$tmp{serial}"; serial+=1
            seq.append((temp, dst))
            pending = {d:(temp if s==dst else s) for d,s in pending.items()}
    return seq
cases=0
for n in range(1,5):
    names=[f"r{i}" for i in range(n)]; initial={v:i+1 for i,v in enumerate(names)}
    for sources in itertools.product(names, repeat=n):
        assignments=dict(zip(names,sources)); actual=initial.copy()
        for d,s in sequentialize(assignments): actual[d]=actual[s]
        assert all(actual[d]==initial[s] for d,s in assignments.items())
        cases+=1
check("parallel_copy_exhaustive", True, assignment_maps=cases, registers="1 through 4")
# Wrongly executing a backedge copy on the exit path destroys the old i.
def lost_copy_model(edge_specific):
    i=0
    while True:
        next_i=i+1
        if edge_specific:
            if next_i>=10:return i+1
            i=next_i
        else:
            i=next_i
            if next_i>=10:return i+1
check("lost_copy_edge_placement",lost_copy_model(True)==10 and lost_copy_model(False)==11,correct=10,incorrect_pre_branch_copy=11)
finish()
