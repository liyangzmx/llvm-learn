"""Exact front-half and Presburger identities; no floating point solver."""
from fractions import Fraction as F
from pathlib import Path
import json

root=Path(__file__).resolve().parent
A=[[F(x) for x in row] for row in [[2,1,-1,8],[-3,-1,2,-11],[-2,1,2,-3]]]
A[1]=[a+F(3,2)*b for a,b in zip(A[1],A[0])]
A[2]=[a+b for a,b in zip(A[2],A[0])]
first=[r[:] for r in A]
A[2]=[a-4*b for a,b in zip(A[2],A[1])]
assert A==[[2,1,-1,8],[0,F(1,2),F(1,2),1],[0,0,-1,1]]
assert all(sum(a*x for a,x in zip(row,[2,3,-1]))==row[-1] for row in A)
assert -2*2+2*3+2*(-1)!=-3  # Original matrix's erroneous y coefficient.

# Every row is a*x <= rhs. Eliminate the last variable, preserving pairs.
ineq=[[-1,0,0,-1],[0,-1,0,-1],[0,0,-1,-1],[-1,-1,0,-3],[-1,0,-1,-3],[0,-1,-1,-3],[1,1,1,6]]
stages=[ineq]
while len(ineq[0])>1:
    zero=[r[:-2]+r[-1:] for r in ineq if r[-2]==0]
    lo=[r for r in ineq if r[-2]<0];hi=[r for r in ineq if r[-2]>0]
    pairs=[]
    for u in hi:
        for l in lo:
            pairs.append([F(a,u[-2])-F(b,l[-2]) for a,b in zip(u[:-2]+u[-1:],l[:-2]+l[-1:])])
    ineq=zero+pairs;stages.append(ineq)
assert all(row[0]>=0 for row in stages[-1])
assert [len(s) for s in stages]==[7,6,6,6]
sample=[3,2,1]
assert all(sum(a*x for a,x in zip(row[:-1],sample))<=row[-1] for row in stages[0])

comparisons=0
for a in range(-20,21):
    for b in range(-20,21):
        assert (not a<b)==(b<a+1)
        assert (not a==b)==(a<b or b<a)
        assert (a==b)==(a<b+1 and b<a+1)
        assert (a<b)==(0<b-a)
        comparisons+=4
division_cases=0
for e in range(-50,51):
    for c in range(1,12):
        q=e//c;r=e%c
        assert c*q<=e<=c*q+c-1 and r==e-c*q and 0<=r<c
        assert (e+c-1)//c==-((-e)//c)
        division_cases+=1
# The purported existential elimination retains precisely the same y.
normalizations=0
for w in range(-7,8):
    for z in range(-7,8):
        for y in range(-7,8):
            assert (3*y-2*w+1>-w and 2*y-6<z and (5*y+1)%4==0)==(0<-w+3*y+1 and 0<-2*y+z+6 and (5*y+1)%4==0)
            normalizations+=1
result={"gaussian_first":first,"gaussian_triangular":A,"solution":[2,3,-1],
        "FME_stages":stages,"FME_integer_sample":sample,
        "comparison_assertions":comparisons,"division_cases":division_cases,
        "existential_body_normalizations":normalizations,"status":"PASS"}
(root/'math-results.json').write_text(json.dumps(result,default=str,ensure_ascii=False,indent=2)+'\n')
print('PASS: Gaussian, 3 FME projections, 4 integer comparisons, division identities, existential-body normalization')
