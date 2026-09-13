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


import shlex
results={}
def body(p):return p.read_text().split("body:             |")[-1].split("\n...")[0]
for name,pas in [("postra-sink","postra-machine-sink"),("copy","machine-cp"),("branch","branch-folder")]:
    run("llc",["-mtriple=bpfel","-mcpu=generic","-verify-machineinstrs","-run-pass="+pas,HERE/(name+".mir"),"-o",OUT/(name+".mir")],name)
    t=body(OUT/(name+".mir"))
    results[name]={"machine_verifier":"passed","blocks":len(re.findall(r"^\s*bb\.[0-9]+[^\n]*:",t,re.M))}
assert body(OUT/"postra-sink.mir").index("$r6 = COPY") < body(OUT/"postra-sink.mir").index("bb.1:")
results["postra-sink"]["bpf_noop_reason"]="BPF does not enable AllowRegisterRenaming"
assert results["branch"]["blocks"]==2
for stage in ["before","after"]:
    run("llc",["-mtriple=bpfel","-mcpu=generic","-O2","-verify-machineinstrs","-stop-"+stage+"=prologepilog",HERE/"frame.ll","-o",OUT/("frame-"+stage+".mir")],"frame-"+stage)
assert "%stack." in body(OUT/"frame-before.mir") and "%stack." not in body(OUT/"frame-after.mir")
assert "$r10, -8" in body(OUT/"frame-after.mir")
results["bpf_pei"]="8-byte object resolved to R10-8; no SP adjustment"
flags=shlex.split(run("llvm-config",["--cxxflags","--ldflags","--libs","transformutils","--system-libs"],"library-flags"))
cxx=os.environ.get("CXX", "/usr/bin/clang++")
# llvm-config may emit -lzstd for the Homebrew installation on macOS.
if Path("/opt/homebrew/lib").is_dir(): flags += ["-L/opt/homebrew/lib"]
cmd=[cxx,*flags,str(HERE/"algorithms.cpp"),"-o",str(OUT/"algorithms")]
r=subprocess.run(cmd,cwd=OUT,text=True,capture_output=True)
(OUT/"algorithms-compile.stderr").write_text(r.stderr)
commands.append({"name":"algorithms-compile","argv":cmd,"exit_code":r.returncode})
assert r.returncode==0,r.stderr
r=subprocess.run([str(OUT/"algorithms")],cwd=OUT,text=True,capture_output=True)
(OUT/"algorithms.stdout").write_text(r.stdout)
commands.append({"name":"algorithms-run","argv":[str(OUT/"algorithms")],"exit_code":r.returncode})
assert r.returncode==0
alg=json.loads(r.stdout)
assert alg["layout"]==[0,1,2,4,3] and alg["score_b"]>alg["score_a"]
assert alg["repeated"]==[{"text":"abc","starts":[0,6]},{"text":"bc","starts":[1,7]}]
results["llvm_library_algorithms"]=alg

for name,pas in [("postra-sink-a64","postra-machine-sink"),("copy-a64","machine-cp")]:
    run("llc",["-mtriple=aarch64-unknown-linux-gnu","-verify-machineinstrs","-run-pass="+pas,HERE/(name+".mir"),"-o",OUT/(name+".mir")],name)
t=body(OUT/"postra-sink-a64.mir")
assert t.index("$w19 = COPY")>t.index("bb.1:")
t=body(OUT/"copy-a64.mir")
assert "COPY" not in t and "$x0 = ADDXri $x0, 3, 0" in t
results["postra_aarch64"]={"copy_sank_to":"bb.1","copy_propagation_removed_copies":2}
for label,source,flags in [("square","square.c",["-O0"]),("shrink","shrink.c",["-O2","-fno-optimize-sibling-calls"]),("no-shrink","shrink.c",["-O2","-fno-optimize-sibling-calls","-mllvm","-enable-shrink-wrap=false"])]:
    run("clang",["--target=aarch64-unknown-linux-gnu",*flags,"-S",HERE/source,"-o",OUT/(label+".s")],label)
square=(OUT/"square.s").read_text();on=(OUT/"shrink.s").read_text();off=(OUT/"no-shrink.s").read_text()
assert "sub\tsp, sp, #16" in square and "add\tsp, sp, #16" in square
assert on.index("cmp\tw0")<on.index("stp\tx29") and off.index("stp\tx29")<off.index("cmp\tw0")
assert on.count("ldp\tx29")==1 and off.count("ldp\tx29")==2
results["aarch64_frame"]={"square_O0_frame_bytes":16,"shrink_restore_sites":1,"disabled_restore_sites":2,"tail_calls_disabled_for_demonstration":True}
for label,extra in [("outliner",["-mllvm","-enable-machine-outliner=always"]),("no-outliner",[])]:
    run("clang",["--target=x86_64-unknown-linux-gnu","-O2","-S",*extra,HERE/"outliner.c","-o",OUT/(label+".s")],label)
t=(OUT/"outliner.s").read_text()
assert len(re.findall(r"jmp\s+OUTLINED_FUNCTION_0",t))==2
results["outliner"]={"outlined_functions":1,"tail_jumps":2,"target":"x86_64-unknown-linux-gnu"}
run("llc",["-mtriple=x86_64-unknown-linux-gnu","-O2","-verify-machineinstrs","-enable-split-machine-functions","-x86-asm-syntax=intel",HERE/"split.ll","-o",OUT/"mfs.s"],"mfs")
run("opt",["-passes=hotcoldsplit","-hotcoldsplit-threshold=0","-S",HERE/"split.ll","-o",OUT/"hcs.ll"],"hcs")
run("llc",["-mtriple=x86_64-unknown-linux-gnu","-O2","-verify-machineinstrs","-x86-asm-syntax=intel",OUT/"hcs.ll","-o",OUT/"hcs.s"],"hcs-asm")
mfs=(OUT/"mfs.s").read_text();hcs=(OUT/"hcs.ll").read_text()
assert ".text.split.foo" in mfs and "je\tfoo.cold" in mfs and "jmp\t.LBB0_2" in mfs
assert "define internal void @foo.cold.1" in hcs and "call void @foo.cold.1" in hcs
results["cold_split"]={"MFS":"same function, separate section, branch and shared frame","HCS":"new internal function foo.cold.1; parameter and output pointer"}
finish(results)
