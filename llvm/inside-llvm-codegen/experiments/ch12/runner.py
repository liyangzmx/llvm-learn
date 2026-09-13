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
    r = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
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

run("clang++", ["--target=bpfel", "-mcpu=generic", "-O2", "-S", HERE/"test.cpp", "-o", OUT/"test.s"], "asm")
run("clang++", ["--target=bpfel", "-mcpu=generic", "-O2", "-c", HERE/"test.cpp", "-o", OUT/"test.o"], "object")
run("clang++", ["--target=bpfel", "-mcpu=generic", "-O2", "-S", "-emit-llvm", HERE/"test.cpp", "-o", OUT/"test.ll"], "ir")
run("llc", ["-mtriple=bpfel", "-mcpu=generic", "-O2", "-verify-machineinstrs", "-stop-after=prologepilog", OUT/"test.ll", "-o", OUT/"test.mir"], "mir")
run("llvm-mc", ["--triple=bpfel", "--show-inst", HERE/"add.s"], "add-inst")
mc = run("llvm-mc", ["--triple=bpfel", "--show-inst", "--show-encoding", HERE/"encoding.s"], "encoding-le")
be = run("llvm-mc", ["--triple=bpfeb", "--show-inst", "--show-encoding", HERE/"encoding.s"], "encoding-be")
run("llvm-mc", ["--triple=bpfel", "--filetype=obj", HERE/"encoding.s", "-o", OUT/"encoding.o"], "encoding-object")
run("llvm-mc", ["--triple=bpfel", "--filetype=obj", OUT/"test.s", "-o", OUT/"reassembled.o"], "reassemble")
dis = run("llvm-objdump", ["-d", OUT/"test.o"], "disassembly")
redis = run("llvm-objdump", ["-d", OUT/"reassembled.o"], "reassembled-disassembly")
rel = run("llvm-readobj", ["--sections", "--symbols", "--relocations", OUT/"test.o"], "object-info")
assert "R_BPF_64_32 _Z4swapRiS_" in rel
assert "R_BPF_64_ABS64 .text" in rel
enc = re.findall(r"encoding: \[(.*?)\]", mc)
expected = ["bf10000000000000", "632af8ff00000000", "630afcff00000000", "6702000020000000", "18030000887766550000000044332211", "9500000000000000"]
actual = ["".join(re.findall(r"0x([0-9a-f]{2})", line)) for line in enc]
assert actual == expected, actual
be_enc = ["".join(re.findall(r"0x([0-9a-f]{2})", line)) for line in re.findall(r"encoding: \[(.*?)\]", be)]
assert be_enc[0] == "bf01000000000000"
# Compare instructions, allowing the file-name header to differ.
def insns(x): return [l.strip() for l in x.splitlines() if re.match(r"\s*[0-9]+:", l)]
assert insns(dis) == insns(redis)
finish({"target": "bpfel", "cpu": "generic", "optimization": "O2", "instruction_count": len(insns(dis)),
        "encoding_le": actual, "encoding_be": be_enc, "external_call_relocation": "R_BPF_64_32", "eh_frame_relocation": "R_BPF_64_ABS64",
        "assembly_roundtrip_same_instructions": True, "machine_verifier": "passed",
        "execution_scope": "Compiled/assembled/disassembled; no BPF kernel/JIT execution."})
