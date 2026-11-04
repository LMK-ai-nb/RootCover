"""Independent exact-rational test reference; never imported by the solver."""
from fractions import Fraction as F
import ast

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

