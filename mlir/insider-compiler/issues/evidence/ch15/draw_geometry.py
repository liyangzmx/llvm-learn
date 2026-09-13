"""Draw exact book LP geometry as SVG, then render using installed librsvg."""
from pathlib import Path
from fractions import Fraction as F
from itertools import combinations
import html, subprocess, json

root=Path(__file__).resolve().parent
# a*x+b*y <= c, including both axes.
constraints=[(-1,0,0),(0,-1,0),(-2,1,2),(1,-2,2),(1,1,5)]
vertices=set()
for (a,b,c),(d,e,f) in combinations(constraints,2):
    det=a*e-b*d
    if det:
        x,y=F(c*e-b*f,det),F(a*f-c*d,det)
        if all(u*x+v*y<=w for u,v,w in constraints):vertices.add((x,y))
poly=[(F(0),F(0)),(F(2),F(0)),(F(4),F(1)),(F(1),F(4)),(F(0),F(2))]
assert set(poly)==vertices
assert min((x-y,x,y) for x,y in vertices)==(-3,1,4)
def X(x):return 85+90*float(x)
def Y(y):return 545-90*float(y)
def line(a,b,color,width=2,dash='',marker=''):
    return f'<line x1="{X(a[0])}" y1="{Y(a[1])}" x2="{X(b[0])}" y2="{Y(b[1])}" stroke="{color}" stroke-width="{width}" stroke-dasharray="{dash}" {marker}/>'
def text(x,y,s,color='#233043',size=17,anchor='start'):
    return f'<text x="{x}" y="{y}" fill="{color}" font-size="{size}" text-anchor="{anchor}">{html.escape(s)}</text>'
for num in (1,2):
    parts=['<svg xmlns="http://www.w3.org/2000/svg" width="720" height="720" viewBox="0 0 720 720" role="img">',
           '<title>Feasible polygon for Chapter 15 linear program</title>',
           '<desc>Vertices (0,0),(2,0),(4,1),(1,4),(0,2). Min x1-x2 is -3 at (1,4).</desc>',
           '<rect width="720" height="720" fill="white"/>',
           '<defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 Z" fill="#c64b20"/></marker></defs>',
           '<g font-family="Arial, sans-serif">']
    for i in range(6):
        parts.extend([line((i,0),(i,5.4),'#e4e8ed',1),line((0,i),(5.4,i),'#e4e8ed',1)])
        if i: parts.extend([text(X(i),Y(0)+24,str(i),anchor='middle'),text(X(0)-17,Y(i)+6,str(i),anchor='end')])
    pts=' '.join(f'{X(x)},{Y(y)}' for x,y in poly)
    parts.append(f'<polygon points="{pts}" fill="#cee4f7" stroke="#205f98" stroke-width="3"/>')
    parts.extend([line((0,2),(F(17,10),F(27,5)),'#376ea5'),line((2,0),(F(27,5),F(17,10)),'#986b22'),line((0,5),(5,0),'#32805c')])
    parts.extend([line((0,0),(5.65,0),'#233043'),line((0,0),(0,5.65),'#233043'),text(X(5.8),Y(0)+6,'x₁',size=21),text(X(0)-8,Y(5.8),'x₂',size=21)])
    if num==2:
        for c,col in [(-3,'#c64b20'),(0,'#946bb0'),(2,'#777777'),(3,'#777777')]:
            # y=x-c clipped to [0,5.4]^2.
            lo=max(F(0),F(c));hi=min(F(27,5),F(27,5)+c)
            parts.append(line((lo,lo-c),(hi,hi-c),col,2,'6 5'))
            parts.append(text(X(hi)+8,Y(hi-c)+5,f'c={c}',col,15))
        parts.append(line((F(19,5),F(31,10)),(F(29,10),4),'#c64b20',3,marker='marker-end="url(#arrow)"'))
        parts.append(text(X(3.5),Y(4.35),'−∇f = (−1, 1)','#c64b20',16))
    offsets={(0,0):(-8,42),(2,0):(0,44),(4,1):(12,-9),(1,4):(10,-13),(0,2):(-12,6)}
    for x,y in poly:
        dx,dy=offsets[(x,y)]
        parts.append(f'<circle cx="{X(x)}" cy="{Y(y)}" r="5" fill="#205f98"/>')
        parts.append(text(X(x)+dx,Y(y)+dy,f'({x}, {y})',anchor='end' if x==0 else 'start'))
    parts.append(text(70,628,'2x₁ − x₂ = −2','#376ea5',17))
    parts.append(text(300,628,'x₁ − 2x₂ = 2','#986b22',17))
    parts.append(text(515,628,'x₁ + x₂ = 5','#32805c',17))
    parts.append(text(70,660,'Shaded region: all five inequalities, including x₁ ≥ 0 and x₂ ≥ 0.',size=16))
    if num==2:parts.append(text(70,690,'Contours: x₁ − x₂ = c. Minimum: −3 at (1, 4).',size=16))
    parts.append('</g></svg>')
    svg=root/f'fig15-{num}.svg';svg.write_text('\n'.join(parts)+'\n')
    subprocess.run(['rsvg-convert',str(svg),'-o',str(svg.with_suffix('.png'))],check=True)
(root/'geometry-results.json').write_text(json.dumps({'constraints':constraints,'vertices':poly,'minimum':-3,'minimizer':[1,4],'coordinate_scale_px':90,'status':'PASS'},default=str,indent=2)+'\n')
print('PASS: exact polygon and minimum; both SVGs rendered to PNG with librsvg')
