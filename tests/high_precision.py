"""Independent high-precision AST reference shared by validation tools only."""
from pathlib import Path
import ast,sys
ROOT=Path(__file__).resolve().parents[1]
if (ROOT/'work/python-deps').exists():sys.path.insert(0,str(ROOT/'work/python-deps'))
import mpmath as mp
mp.mp.dps=100

FUNCS={name:getattr(mp,name) for name in ['sin','cos','tan','exp','log','sqrt','asin','acos','atan','sinh','cosh','tanh']}
FUNCS['abs']=abs

def gradient(expression,point,names):
    """Analytic AD at high precision; no finite differences at extreme scales."""
    n=len(names)
    def walk(e):
        if isinstance(e,ast.Constant):return mp.mpf(float(e.value)),[mp.mpf(0)]*n
        if isinstance(e,ast.Name):return mp.mpf(point[names.index(e.id)]),[mp.mpf(int(v==e.id)) for v in names]
        if isinstance(e,ast.UnaryOp):
            v,g=walk(e.operand)
            return (-v,[-x for x in g]) if isinstance(e.op,ast.USub) else (v,g)
        if isinstance(e,ast.Call):
            v,g=walk(e.args[0]);name=e.func.id;out=FUNCS[name](v)
            d={'sin':lambda:mp.cos(v),'cos':lambda:-mp.sin(v),'tan':lambda:1/mp.cos(v)**2,
               'exp':lambda:mp.exp(v),'log':lambda:1/v,'sqrt':lambda:1/(2*mp.sqrt(v)),
               'abs':lambda:mp.sign(v),'atan':lambda:1/(1+v*v),'asin':lambda:1/mp.sqrt(1-v*v),
               'acos':lambda:-1/mp.sqrt(1-v*v),'sinh':lambda:mp.cosh(v),'cosh':lambda:mp.sinh(v),
               'tanh':lambda:1/mp.cosh(v)**2}[name]()
            return out,[d*x for x in g]
        if isinstance(e,ast.BinOp):
            a,g=walk(e.left);b,h=walk(e.right)
            if isinstance(e.op,ast.Add):return a+b,[x+y for x,y in zip(g,h)]
            if isinstance(e.op,ast.Sub):return a-b,[x-y for x,y in zip(g,h)]
            if isinstance(e.op,ast.Mult):return a*b,[x*b+a*y for x,y in zip(g,h)]
            if isinstance(e.op,ast.Div):return a/b,[(x*b-a*y)/(b*b) for x,y in zip(g,h)]
            if isinstance(e.op,ast.Pow):
                assert all(x==0 for x in h),'Only constant powers in fixtures'
                return a**b,[mp.mpf(0) if b==0 else b*a**(b-1)*x for x in g]
        raise AssertionError(ast.dump(e))
    return walk(ast.parse(expression.replace('^','**'),mode='eval').body)[1]

def val(expression,point,names):
    def walk(e):
        if isinstance(e,ast.Constant):return mp.mpf(float(e.value))
        if isinstance(e,ast.Name):return mp.mpf(point[names.index(e.id)])
        if isinstance(e,ast.UnaryOp):return -walk(e.operand) if isinstance(e.op,ast.USub) else walk(e.operand)
        if isinstance(e,ast.Call):return FUNCS[e.func.id](walk(e.args[0]))
        if isinstance(e,ast.BinOp):
            a,b=walk(e.left),walk(e.right)
            if isinstance(e.op,ast.Add):return a+b
            if isinstance(e.op,ast.Sub):return a-b
            if isinstance(e.op,ast.Mult):return a*b
            if isinstance(e.op,ast.Div):return a/b
            if isinstance(e.op,ast.Pow):return a**b
        raise AssertionError(ast.dump(e))
    return walk(ast.parse(expression.replace('^','**'),mode='eval').body)

def real(x):return not isinstance(x,mp.mpc) and not mp.isnan(x)
def bound(x):return mp.inf if x=='Infinity' else -mp.inf if x=='-Infinity' else mp.mpf(x)
def contains(box,point):return all(bound(a)<=x<=bound(b) for (a,b),x in zip(box,point))
def valid_value(expr,point,names):
    try:
        v=val(expr,point,names)
        return v if real(v) and mp.isfinite(v) else None
    except (ValueError,ZeroDivisionError):return None
