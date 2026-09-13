"""Executable teaching models; not LLVM's scheduler implementation."""
from itertools import permutations
from math import ceil

def topo_orders(deps):
    def visit(order, remaining):
        if not remaining:
            yield order
            return
        for n in sorted(remaining):
            if deps[n] <= set(order):
                yield from visit(order+[n], remaining-{n})
    return list(visit([],set(deps)))

def peak_pressure(order, uses):
    live=set(); history=[]
    for n in reversed(order):
        live.discard(n)
        live.update(uses[n])
        history.append({'before':n,'live':sorted(live)})
    return max([len(x['live']) for x in history],default=0), list(reversed(history))

def run_models():
    # Only these SSA temporaries count. Pointer live-ins, subregister lanes,
    # dead defs/early-clobbers and target pressure weights are deliberately absent.
    deps={'a':set(),'b':set(),'c':set(),'d':set(),
          'm':{'a','b'},'n':{'c','d'},'r':{'m','n'},'store':{'r'}}
    orders=topo_orders(deps)
    pressures=[peak_pressure(o,deps)[0] for o in orders]
    broad=['a','b','c','d','m','n','r','store']
    compact=['a','b','m','c','d','n','r','store']
    assert min(pressures)==3 and max(pressures)==4
    assert peak_pressure(broad,deps)[0]==4
    assert peak_pressure(compact,deps)[0]==3
    # Topological precedence alone does not enforce producer-to-consumer latency.
    latdeps={'L':{},'M':{'L':4},'A':{},'S':{'M':3,'A':1}}
    order=['L','M','A','S']
    starts={};next_issue=0
    for n in order:
        starts[n]=max([next_issue]+[starts[p]+lat for p,lat in latdeps[n].items()])
        next_issue=starts[n]+1
    assert starts=={'L':0,'M':4,'A':5,'S':7}
    # A recurrence u(i)->v(i)->u(i+1) has latencies 2+1 and distance 1.
    edges=[('u','v',2,0),('v','u',1,1)]
    feasible={}
    for ii in range(1,5):
        schedules=[{'u':u,'v':v} for u in range(0,8) for v in range(0,8)
                   if all(({'u':u,'v':v}[dst]-{'u':u,'v':v}[src]) >= lat-distance*ii
                          for src,dst,lat,distance in edges)]
        feasible[str(ii)]=bool(schedules)
    assert feasible=={'1':False,'2':False,'3':True,'4':True}
    # Software pipeline A_i=x_i+1; B_i=2*A_i, one cycle per stage.
    # Distinct units/issue width>=2; no alias or loop-carried dependence.
    tested=[]
    for count in range(0,65):
        x=list(range(count));expected=[2*(v+1) for v in x];actual=[None]*count
        if count:
            a=x[0]+1
            for i in range(1,count):
                actual[i-1]=2*a
                a=x[i]+1
            actual[count-1]=2*a
        assert actual==expected
        tested.append(count)
    return {'ssa_boundary_pressure':{'all_topological_orders':len(orders),'minimum':min(pressures),'maximum':max(pressures),'broad':peak_pressure(broad,deps)[1],'compact':peak_pressure(compact,deps)[1]},
            'single_issue_edge_latency':{'order':order,'issue_cycles':starts,'assumptions':'one issue/cycle, no resource hazards beyond issue width; edge latencies explicit'},
            'recurrence':{'edges':edges,'recMII':3,'feasible_II':feasible,'inequality':'start(v)-start(u) >= latency(u,v)-distance(u,v)*II'},
            'software_pipeline':{'tested_lengths':tested,'semantics_equal':True,'assumptions':'two independent pipelined units; issue width >= 2; A_i precedes B_i; no cross-iteration dependence'}}
if __name__=='__main__':
    import json
    print(json.dumps(run_models(),ensure_ascii=False,indent=2))
