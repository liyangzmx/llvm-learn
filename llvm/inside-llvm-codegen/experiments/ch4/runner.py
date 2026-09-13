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

def reachable(g,start,removed=None):
    todo=[] if start==removed else [start]; seen=set()
    while todo:
        x=todo.pop()
        if x in seen or x==removed:continue
        seen.add(x);todo.extend(g[x])
    return seen
def dominators(g,root):
    nodes=reachable(g,root); pred={n:{p for p in nodes if n in g[p]} for n in nodes}
    dom={n:({root} if n==root else nodes.copy()) for n in nodes}
    while True:
        old={n:v.copy() for n,v in dom.items()}
        for n in nodes-{root}:dom[n]={n}|set.intersection(*(dom[p] for p in pred[n]))
        if old==dom:break
    idom={root:None}
    for n in nodes-{root}:
        strict=dom[n]-{n};idom[n]=next(d for d in strict if strict-{d}<=dom[d])
    return dom,idom
def dfs(g,root):
    order=[]; parent={root:None}
    def visit(n):
        order.append(n)
        for s in g[n]:
            if s not in parent:parent[s]=n;visit(s)
    visit(root);return order,parent
def semi_by_definition(g,root):
    order,parent=dfs(g,root);num={n:i for i,n in enumerate(order)};semi={root:root}
    for w in order[1:]:
        for v in order:
            todo=list(g[v]);seen=set();found=False
            while todo:
                x=todo.pop()
                if x==w:found=True;break
                if x in seen or num[x]<=num[w]:continue
                seen.add(x);todo.extend(g[x])
            if found:semi[w]=v;break
    ids={root:None}
    for w in order[1:]:
        a,b=semi[w],parent[w]
        while a!=b:
            if num[a]>num[b]:a=ids[a]
            else:b=ids[b]
        ids[w]=a
    return semi,ids
def frontiers(g,dom,ids):
    depth={n:len(dom[n])-1 for n in dom}
    exact={x:{y for p in dom if x in dom[p] for y in g[p] if y in dom and not (x!=y and x in dom[y])} for x in dom}
    dj={x:{y for z in dom if x in dom[z] for y in g[z] if y in dom and ids[y]!=z and depth[y]<=depth[x]} for x in dom}
    assert exact==dj
    return exact
# All four-node CFGs with no edge into entry; self-loops are included.
edges=[(u,v) for u in range(4) for v in range(1,4)]; count=0
for mask in range(1<<len(edges)):
    g={i:[] for i in range(4)}
    for k,(u,v) in enumerate(edges):
        if mask>>k&1:g[u].append(v)
    if len(reachable(g,0))!=4:continue
    dom,ids=dominators(g,0)
    for d in g:
        remaining=reachable(g,0,d)
        assert all((d in dom[w])==(w not in remaining) for w in g)
    semi,semi_ids=semi_by_definition(g,0)
    assert ids==semi_ids
    frontiers(g,dom,ids);count+=1
check("four_node_graphs",True,reachable_graphs=count,enumerated_graphs=4096,compared_algorithms=["delete-node reachability","dominance fixed point","definition semidominators + NCA","definition DF vs DJ subtree scan"])
semi_example = {0:[1,5],1:[2,4],2:[3],3:[4],4:[],5:[3]}
semi_dom, semi_idom = dominators(semi_example, 0)
semi_values, recovered_ids = semi_by_definition(semi_example, 0)
check("semidominator_need_not_dominate", semi_values[4] == 1 and semi_idom[4] == 0 and 1 not in semi_dom[4] and recovered_ids == semi_idom, dfs_order=dfs(semi_example,0)[0], semi_4=semi_values[4], idom_4=semi_idom[4], bypass=[0,5,3,4])
g={1:[2,5],2:[3,4],3:[6],4:[6],5:[7],6:[7],7:[]};dom,ids=dominators(g,1);df=frontiers(g,dom,ids)
check("table_4_1",ids=={1:None,2:1,3:2,4:2,5:1,6:2,7:1} and df[2]=={7} and df[3]=={6},dominators={n:sorted(s) for n,s in dom.items()},idom=ids,frontier={n:sorted(s) for n,s in df.items()})
updated={n:v.copy() for n,v in g.items()};updated[5].append(6)
newdom,newids=dominators(updated,1)
check("insert_edge_changes_dominance",newids[6]==1 and 2 not in newdom[6],edge=[5,6],old_idom_6=2,new_idom_6=1)
for name in ["graph7.ll","join-loop.ll","postdom-roots.ll"]:verify(HERE/name)
r=run("opt","-passes=print<domtree>,print<domfrontier>,print<postdomtree>,verify<domtree>","-disable-output",HERE/"graph7.ll")
report=r.stdout+r.stderr
llvm_ids={}; stack={}
for line in report.split("DominanceFrontier for")[0].splitlines():
    m=re.match(r"\s+\[(\d+)\] %n(\d+)",line)
    if m:
        level,n=map(int,m.groups());llvm_ids[n]=stack.get(level-1);stack[level]=n
llvm_df={}
for line in report.splitlines():
    if "DomFrontier for BB" in line:
        numbers=list(map(int,re.findall(r"%n(\d+)",line)));llvm_df[numbers[0]]=set(numbers[1:])
check("llvm_domtree_graph7",llvm_ids==ids and llvm_df==df,idom=llvm_ids,frontier={n:sorted(v) for n,v in llvm_df.items()})
run("opt","-passes=mem2reg,verify,print<domfrontier>","-S",HERE/"join-loop.ll","-o",OUT/"idf.ll")
idf=(OUT/"idf.ll").read_text(); phi_blocks=[];block=None
for line in idf.splitlines():
    match=re.match(r"^([-\w.]+):",line)
    if match:block=match[1]
    if " phi " in line:phi_blocks.append(block)
check("iterated_df_mem2reg",set(phi_blocks)=={"header","join"},phi_blocks=phi_blocks)
r=run("opt","-passes=print<postdomtree>","-disable-output",HERE/"postdom-roots.ll")
report=r.stdout+r.stderr
check("multiple_exit_and_infinite_root",all(x in report for x in ["exit1","exit2","spin","<<exit node>>"]),report=report)
finish()
