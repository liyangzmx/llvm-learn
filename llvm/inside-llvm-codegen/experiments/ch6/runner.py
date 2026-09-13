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

import hashlib, io, tarfile
BASELINE = "3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff"
r=run("llvm-tblgen","--dump-json",HERE/"language.td")
records=json.loads(r.stdout)
check("multiclass_records", records["!instanceof"]["Instr"]==["MyBackend_rm","MyBackend_rr"] and records["MyBackend_rr"]["name"]=="rr" and records["MyBackend_rm"]["name"]=="rm",records=records["!instanceof"]["Instr"])
v=records["Values"]
check("literal_and_value_rules",v["negative"]==-42 and v["hexadecimal"]==42 and v["binary"]==42 and v["a"]==[0,1,1,0] and v["slice"]==[30,10] and v["joined"]=="12ab" and v["direct_arguments"]==2 and "\n" in v["body"] and "return 1;" in v["body"],values={k:v[k] for k in ["negative","hexadecimal","binary","a","slice","joined","direct_arguments"]})
simple = json.loads(run("llvm-tblgen", "--dump-json", HERE / "records.td").stdout)
check("def_class_partial_encoding", simple["record_example"]["a"] == 1 and simple["record_example"]["b"] == "def example" and simple["!instanceof"]["TestInst"] == ["ADD", "MUL"] and simple["ADD"]["encoding"] == [None]*26 + [1,0,0,0,0,0] and simple["MUL"]["encoding"] == [None]*26 + [0,1,0,0,0,0], undefined_low_bits=26, assigned_high_values=[1,2])
for name,diagnostic in [("bad-field.td","unknown"),("bad-bits.td","more than once")]:
    r=run("llvm-tblgen","--print-records",HERE/name,fail=True)
    check(name,diagnostic.lower() in r.stderr.lower(),diagnostic=r.stderr.strip().splitlines()[0])
# Read-only export of the exact reference revision: do not consume modified BPF TD files.
snapshot=OUT/"llvm18-source";snapshot.mkdir(exist_ok=True)
archive=subprocess.check_output(["git","-C",str(LLVM_SRC),"archive",BASELINE,"llvm/include","llvm/lib/Target/BPF"])
with tarfile.open(fileobj=io.BytesIO(archive)) as tf:
    for m in tf.getmembers():
        dest=(snapshot/m.name).resolve()
        if not dest.is_relative_to(snapshot.resolve()) or m.issym() or m.islnk():
            raise RuntimeError("Unexpected archive entry: "+m.name)
    tf.extractall(snapshot, filter="data")
include=["-I",snapshot/"llvm/include","-I",snapshot/"llvm/lib/Target/BPF"]
td=snapshot/"llvm/lib/Target/BPF/BPF.td"
r=run("llvm-tblgen",*include,"--dump-json",td);bpf=json.loads(r.stdout)
add=bpf["ADD_rr"];ldw=bpf["LDW"];addr=bpf["ADDRri"]
check("bpf_alu_records",all(n in bpf for n in ["ADD_rr","ADD_ri","ADD_rr_32","ADD_ri_32"]) and add["Constraints"]=="$dst = $src2" and add["isAsCheapAsAMove"]==1 and add["Size"]==8,variants=["ADD_rr","ADD_ri","ADD_rr_32","ADD_ri_32"],constraints=add["Constraints"],size=add["Size"])
check("complex_pattern_record",addr["SelectFunc"]=="SelectAddr" and addr["NumOperands"]==2,select_func=addr["SelectFunc"],outputs=addr["NumOperands"])
check("ldw_predicate_and_pattern", "BPFNoALU32" in json.dumps(ldw["Predicates"]) and "zextloadi32" in json.dumps(ldw["Pattern"]),predicates=ldw["Predicates"],pattern=ldw["Pattern"])
run("llvm-tblgen",*include,"-gen-dag-isel",td,"-o",OUT/"BPFGenDAGISel.inc")
matcher=(OUT/"BPFGenDAGISel.inc").read_text()
check("generated_matcher_and_callback",all(s in matcher for s in ["MatcherTable", "BPF::ADD_rr", "BPF::ADD_ri", "BPF::LDW", "BPF::JAL", "BPF::JALX", "SelectAddr(N, Result[NextRes+0].first, Result[NextRes+1].first)"]),bytes=len(matcher.encode()))
run("llvm-tblgen",*include,"-gen-instr-info",td,"-o",OUT/"BPFGenInstrInfo.inc")
run("llvm-tblgen",*include,"-gen-emitter",td,"-o",OUT/"BPFGenMCCodeEmitter.inc")
check("instruction_and_encoding_generators",(OUT/"BPFGenInstrInfo.inc").stat().st_size>0 and (OUT/"BPFGenMCCodeEmitter.inc").stat().st_size>0)
comparison = {}
for mode, filename in [("-gen-dag-isel", "BPFGenDAGISel.inc"), ("-gen-instr-info", "BPFGenInstrInfo.inc"), ("-gen-emitter", "BPFGenMCCodeEmitter.inc")]:
    current = OUT / ("working-tree-" + filename)
    run("llvm-tblgen", "-I", LLVM_SRC / "llvm/include", "-I", LLVM_SRC / "llvm/lib/Target/BPF", mode, LLVM_SRC / "llvm/lib/Target/BPF/BPF.td", "-o", current)
    baseline_bytes = (OUT / filename).read_bytes()
    working_bytes = current.read_bytes()
    comparison[mode] = {"identical": baseline_bytes == working_bytes, "baseline_sha256": hashlib.sha256(baseline_bytes).hexdigest(), "working_tree_sha256": hashlib.sha256(working_bytes).hexdigest()}
finish(source_revision=BASELINE,source_mode="git archive of llvm/include and llvm/lib/Target/BPF; working tree read for comparison only",working_tree_generated_comparison=comparison)
