"""Independent exact-rational arithmetic and analytic-root oracle. Python stdlib only.

MoonBit answers arrive through a separate compiled public consumer. Certificate
replay uses Fraction interval operations and a Python AST evaluator, not the
MoonBit rounding, differentiation, search or matrix-inversion implementation.
"""
from fractions import Fraction as F
from pathlib import Path
import ast,itertools,json,math,random,subprocess

ROOT=Path(__file__).resolve().parents[1]
SEED=20261104
rng=random.Random(SEED)
def f(x):return F.from_float(float(x))
def pt(x):return (f(x),f(x))
def add(a,b):return (a[0]+b[0],a[1]+b[1])
def neg(a):return (-a[1],-a[0])
def sub(a,b):return add(a,neg(b))
def mul(a,b):
    xs=[x*y for x in a for y in b];return min(xs),max(xs)
def power(a,k):
    if not k:return pt(1)
    if k%2:
        return a[0]**k,a[1]**k
    return (F(0) if a[0]<=0<=a[1] else min(a[0]**k,a[1]**k),max(a[0]**k,a[1]**k))
def dual(node,box,names):
    n=len(names);zero=[pt(0) for _ in names]
    if isinstance(node,ast.Constant):return pt(node.value),zero
    if isinstance(node,ast.Name):
        i=names.index(node.id);zero[i]=pt(1);return box[i],zero
    if isinstance(node,ast.UnaryOp):
        v,g=dual(node.operand,box,names)
        return (neg(v),[neg(x) for x in g]) if isinstance(node.op,ast.USub) else (v,g)
    if isinstance(node,ast.BinOp):
        v,g=dual(node.left,box,names)
        if isinstance(node.op,ast.Pow):
            k=node.right.value;return power(v,k),[mul(pt(k),mul(power(v,k-1),d)) for d in g] if k else zero
        w,h=dual(node.right,box,names)
        if isinstance(node.op,ast.Add):return add(v,w),[add(a,b) for a,b in zip(g,h)]
        if isinstance(node.op,ast.Sub):return sub(v,w),[sub(a,b) for a,b in zip(g,h)]
        if isinstance(node.op,ast.Mult):return mul(v,w),[add(mul(a,w),mul(v,b)) for a,b in zip(g,h)]
    raise AssertionError(ast.dump(node))
def eval_system(q,box):return [dual(ast.parse(s.replace('^','**'),mode='eval').body,box,q['variables']) for s in q['equations']]
def replay(q,root):
    c=root['certificate'];box=[tuple(map(f,a)) for a in c['domain']]
    mid=[pt(x) for x in c['center']];n=len(box)
    assert all(a[0]<=m[0]<=a[1] for a,m in zip(box,mid))
    jac=[d for _,d in eval_system(q,box)];fm=[v for v,_ in eval_system(q,mid)]
    y=[[pt(x) for x in row] for row in c['preconditioner']]
    b=[]
    for i in range(n):
        row=[]
        for j in range(n):
            t=pt(int(i==j))
            for k in range(n):t=sub(t,mul(y[i][k],jac[k][j]))
            row.append(t)
        b.append(row)
    norm=max(sum(max(abs(a),abs(z)) for a,z in row) for row in b)
    assert norm<=f(c['contraction_bound'])<1
    for i in range(n):
        t=mid[i]
        for k in range(n):t=sub(t,mul(y[i][k],fm[k]))
        for j in range(n):t=add(t,mul(b[i][j],sub(box[j],mid[j])))
        lo,hi=map(f,c['image'][i])
        assert lo<=t[0]<=t[1]<=hi,('image does not enclose exact Krawczyk interval',q,t,(lo,hi))
        assert box[i][0]<lo<=hi<box[i][1]

messages=[];expected=[]
rows=[];exact=[]
special=[0.0,-0.0,math.ulp(0.0),-math.ulp(0.0),1e-300,-1e-300,1e300,-1e300,0.1,-0.2]
for _ in range(700):
    a,b=sorted(rng.choices(special,k=2)) if rng.random()<0.3 else sorted(rng.uniform(-100,100) for _ in range(2))
    c,d=sorted(rng.choices(special,k=2)) if rng.random()<0.3 else sorted(rng.uniform(-100,100) for _ in range(2))
    for op,func in [('add',add),('sub',sub),('mul',mul)]:
        rows.append([op,a,b,c,d]);exact.append(func((f(a),f(b)),(f(c),f(d))))
    k=rng.randrange(0,9);rows.append(['pow',a,b,k,0]);exact.append(power((f(a),f(b)),k))
messages.append({'kind':'probe','rows':rows})
for _ in range(75):
    n=rng.randrange(1,7);names=[f'x{i}' for i in range(n)];r=[rng.randint(-12,12)/4 for _ in names]
    matrix=[[rng.randint(-2,2) for _ in names] for _ in names]
    for i in range(n):matrix[i][i]=sum(abs(x) for x in matrix[i])+3
    equations=['+'.join(f'({a})*({v}-({z}))' for a,v,z in zip(row,names,r)) for row in matrix]
    q={'version':1,'variables':names,'equations':equations,'box':[[z-1,z+1] for z in r]}
    messages.append({'kind':'solve','request':q});expected.append((q,[tuple(map(f,r))]))
for _ in range(75):
    n=rng.randrange(1,4);names=[f'x{i}' for i in range(n)];pairs=[]
    for _ in names:
        a=rng.randint(-15,-1)/4;b=rng.randint(1,15)/4;pairs.append((a,b))
    q={'version':1,'variables':names,'equations':[f'({x}-({a}))*({x}-({b}))' for x,(a,b) in zip(names,pairs)],'box':[[a-1,b+1] for a,b in pairs]}
    messages.append({'kind':'solve','request':q});expected.append((q,[tuple(map(f,z)) for z in itertools.product(*pairs)]))
for _ in range(30):
    a=rng.randint(-9,9)/4;k=rng.randint(1,8)
    q={'version':1,'variables':['x'],'equations':[f'(x-({a}))^2+{k}'],'box':[[a-4,a+4]]}
    messages.append({'kind':'solve','request':q});expected.append((q,[]))
proc=subprocess.run(['node','tests/oracle_bridge.mjs'],cwd=ROOT,input='\n'.join(json.dumps(x) for x in messages)+'\n',text=True,capture_output=True,timeout=180,check=True)
answers=[json.loads(x) for x in proc.stdout.splitlines()];assert len(answers)==len(messages),(len(answers),proc.stderr)
assert len(answers[0])==len(rows)
for got,want in zip(answers[0],exact):
    a,b=map(float,got)
    assert (math.isinf(a) and a<0 or f(a)<=want[0]) and (math.isinf(b) and b>0 or want[1]<=f(b)),(got,want)
certificates=0
for got,(q,roots) in zip(answers[1:],expected):
    assert 'error' not in got,got
    assert got['complete'] and not got['unresolved'],(q,got)
    assert got['root_count']==len(roots),(q,got)
    for root in roots:
        matches=[r for r in got['roots'] if all(f(a)<=x<=f(b) for (a,b),x in zip(r['enclosure'],root))]
        assert len(matches)==1,(q,root,got)
    for root in got['roots']:replay(q,root);certificates+=1
report={'seed':SEED,'interval_cases':len(rows),'systems':len(expected),'exact_certificate_replays':certificates,'passed':True}
(ROOT/'artifacts').mkdir(exist_ok=True)
(ROOT/'artifacts/oracle.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
