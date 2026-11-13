"""Independent 100-digit point/derivative checks, reference roots and contractor
solution-preservation checks. mpmath is a validation dependency, not a runtime.
Finite tests are not a formal proof of the numerical implementation.
"""
from pathlib import Path
import ast,itertools,json,math,random,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
if (ROOT/'work/python-deps').exists():sys.path.insert(0,str(ROOT/'work/python-deps'))
import mpmath as mp
mp.mp.dps=100
SEED=20261111
rng=random.Random(SEED)
from high_precision import FUNCS,gradient,val,real,bound,contains,valid_value

messages=[];evaluations=[];contracts=[];systems=[];pavings=[]
def append(kind,request):
    messages.append({'kind':kind,'request':request})
    return len(messages)-1

for name in FUNCS:
    domains=[(-4.,4.),(0.,0.),(-1.,1.),(-1e-300,1e-300)]
    if name in ['exp','sinh','cosh','tanh']:domains += [(-2000.,-1000.),(700.,800.),(-1e308,1e308)]
    if name in ['log','sqrt']:domains += [(-2.,-1.),(-1.,2.),(math.ulp(0.),math.ulp(0.)),(1e-300,1e300)]
    if name in ['sin','cos','tan']:domains += [(1.4,1.7),(-10.,10.),(1e12,1e12)]
    for _ in range(28):
        a=rng.uniform(-6,6);b=a+rng.uniform(0,1.5)
        if name in ['asin','acos']:a,b=sorted([rng.uniform(-1.1,1.1),rng.uniform(-1.1,1.1)])
        domains.append((a,b))
    for a,b in domains:
        q={'operation':'evaluate','variables':['x'],'expression':name+'(x)','box':[[a,b]]}
        index=append('nonlinear',q);evaluations.append((index,q))

# Pointwise analytic derivatives of composite expressions, evaluated independently.
for expression in ['exp(x)+log(y)+sin(x*y)+sqrt(y)+x^-2','atan(x)+asin(y/2)+acos(y/2)',
                   'sinh(x)+cosh(y)+tanh(x-y)','abs(x-y)+(x+y)/(1+x^2)']:
    for _ in range(20):
        a,b=rng.uniform(.3,2),rng.uniform(.3,1.8)
        q={'operation':'evaluate','variables':['x','y'],'expression':expression,'box':[[a,a],[b,b]]}
        evaluations.append((append('nonlinear',q),q))

root_cases=[
 ('documented_four_roots','sin(x)-0.1*x^2+1',[-10,10],[mp.findroot(lambda x:mp.sin(x)-mp.mpf(float(.1))*x*x+1,z) for z in [-4.4,-3.1,-1.1,3.15]]),
 ('fixed_point','cos(x)-x',[0,1],[mp.findroot(lambda x:mp.cos(x)-x,.7)]),
 ('exponential_decay','exp(-x)-x',[0,1],[mp.lambertw(1)]),
 ('log_domain','log(x)',[-2,2],[mp.mpf(1)]),
 ('sqrt_domain','sqrt(x)-2',[-1,9],[mp.mpf(4)]),
 ('nested_transcendentals','sin(exp(x))',[0,2],[mp.log(mp.pi),mp.log(2*mp.pi)]),
 ('atan','atan(x)-0.5',[0,2],[mp.tan(mp.mpf('.5'))]),
 ('asin','asin(x)-0.25',[-.9,.9],[mp.sin(mp.mpf('.25'))]),
 ('acos','acos(x)-1',[-.9,.9],[mp.cos(1)]),
 ('sinh','sinh(x)-1',[-2,2],[mp.asinh(1)]),
 ('cosh','cosh(x)-2',[-2,2],[-mp.acosh(2),mp.acosh(2)]),
 ('tanh','tanh(x)-0.5',[-2,2],[mp.atanh(mp.mpf('.5'))]),
 ('pole_without_root','1/x',[-1,1],[]),
]
for name,expr,domain,roots in root_cases:
    q={'version':1,'variables':['x'],'equations':[expr],'box':[domain],'options':{'max_assessments':10000,'tolerance':1e-7}}
    systems.append((append('solve',q),name,q,[(r,) for r in roots],True))
q={'version':1,'variables':['x','y'],'equations':['sin(x)','cos(y)'],'box':[[-3,3],[-3,3]],'options':{'max_assessments':10000}}
systems.append((append('solve',q),'trigonometric_2d',q,[(mp.mpf(0),-mp.pi/2),(mp.mpf(0),mp.pi/2)],True))
for n in [12,32]:
    names=[f'x{i}' for i in range(n)]
    q={'version':1,'variables':names,'equations':[f'2*{v}'+(f'-{names[i-1]}' if i else '')+f'-{2 if i==0 else 1}' for i,v in enumerate(names)],'box':[[0,2]]*n}
    systems.append((append('solve',q),f'coupled_{n}d',q,[(mp.mpf(1),)*n],True))
for expression,root in [('abs(x)',0),('sqrt(x)',0),('log(x)^2',1)]:
    q={'version':1,'variables':['x'],'equations':[expression],'box':[[-.5,2]],'options':{'tolerance':1e-5,'max_assessments':3000}}
    systems.append((append('solve',q),expression,q,[(mp.mpf(root),)],False))

for _ in range(32):
    point=[rng.uniform(.2,2),rng.uniform(-.8,.8)]
    names=['x','y']
    pool=['sin(x)+y','exp(y)-x','log(x)+sqrt(x)+y^2','x/(y^2+1)','asin(y/2)+atan(x)','cosh(y)-tanh(x)']
    cs=[]
    for expr in rng.sample(pool,3):
        center=val(expr,point,names)
        cs.append({'expression':expr,'range':[math.nextafter(float(center-mp.mpf('.05')),-math.inf),math.nextafter(float(center+mp.mpf('.05')),math.inf)]})
    for config in [{'propagation':True,'newton':False},{'propagation':False,'newton':True},{'propagation':True,'newton':True}]:
        q={'version':1,'mode':'feasibility','variables':names,'constraints':cs,'box':[[-.5,3],[-2,2]],'contractors':{**config,'max_steps':80,'max_rounds':4}}
        request={'operation':'contract','request':json.dumps(q)}
        contracts.append((append('nonlinear',request),q,point))

# Exercise inverse operators independently, including all periodic branches,
# powers of both parity and quotients whose denominator can cross zero.
for expression in [f'{name}(x)' for name in FUNCS]+['x^3','x^4','x^-1','x/(x-1)']:
    for _ in range(6):
        point=[rng.uniform(.2,.8) if expression.startswith(('log','sqrt','asin','acos')) else rng.uniform(-3,3)]
        center=valid_value(expression,point,['x'])
        if center is None:continue
        domain=[[-4,4]]
        if expression.startswith(('asin','acos')):domain=[[-1.2,1.2]]
        c={'expression':expression,'range':[math.nextafter(float(center-mp.mpf('.02')),-math.inf),math.nextafter(float(center+mp.mpf('.02')),math.inf)]}
        for config in [{'propagation':True,'newton':False},{'propagation':False,'newton':True},{'propagation':True,'newton':True}]:
            q={'version':1,'mode':'feasibility','variables':['x'],'constraints':[c],'box':domain,'contractors':{**config,'max_steps':80,'max_rounds':4}}
            contracts.append((append('nonlinear',{'operation':'contract','request':json.dumps(q)}),q,point))

for filename,known in [('robot_workspace',[(0,mp.pi/2),(mp.pi/2,-mp.pi/2)]),
                       ('thermal_parameters',[(2,mp.mpf('.5'),mp.mpf('.25'))]),
                       ('mixed_process',[(1,mp.mpf('.7'))])]:
    path=ROOT/'examples'/f'{filename}.json'
    if not path.exists():raise AssertionError('Missing runnable scenario '+str(path))
    q=json.loads(path.read_text())
    pavings.append((append('solve',q),q,known))

process=subprocess.run(['node','tests/oracle_bridge.mjs'],cwd=ROOT,input='\n'.join(json.dumps(x) for x in messages)+'\n',text=True,encoding='utf-8',capture_output=True,timeout=240,check=True)
answers=[json.loads(line) for line in process.stdout.splitlines()]
assert len(answers)==len(messages),(len(answers),len(messages),process.stderr)
point_checks=0;derivative_checks=0;grid_checks=0
for index,q in evaluations:
    got=answers[index];assert 'error' not in got,(q,got)
    axes=[[mp.mpf(a)+(mp.mpf(b)-mp.mpf(a))*mp.mpf(i)/4 for i in range(5)] for a,b in q['box']]
    for point in itertools.product(*axes):
        value=valid_value(q['expression'],point,q['variables'])
        if value is None:continue
        assert got['range'] is not None,('incorrect empty domain',q,point)
        lo,hi=map(bound,got['range'])
        assert lo<=value<=hi,('range excludes high precision point',q,point,str(value),got)
        point_checks+=1
        if got['fully_defined'] and got['smooth']:
            for j,interval in enumerate(got['gradient']):
                derivative=gradient(q['expression'],point,q['variables'])[j]
                if real(derivative):
                    assert bound(interval[0])<=derivative<=bound(interval[1]),('derivative excludes reference',q,j,str(derivative),interval)
                    derivative_checks+=1

for index,q,point in contracts:
    got=answers[index];assert 'error' not in got,(q,got)
    assert got['box'] is not None and contains(got['box'],list(map(mp.mpf,point))),('lost constructed feasible point',q,point,got)
    assert all(a<=c<=d<=b for (a,b),(c,d) in zip(q['box'],got['box']))
    # Independently evaluate grid points and retain every actually feasible one.
    axes=([.125,.5,1,1.5,2,2.5],[-1,-.5,0,.5,1]) if len(point)==2 else ([i/8 for i in range(-32,33)],)
    for sample in itertools.product(*axes):
        if not contains(q['box'],sample):continue
        values=[valid_value(c['expression'],sample,q['variables']) for c in q['constraints']]
        if all(v is not None and mp.mpf(c['range'][0])<=v<=mp.mpf(c['range'][1]) for c,v in zip(q['constraints'],values)):
            assert contains(got['box'],list(map(mp.mpf,sample))),('lost feasible grid point',q,sample,got)
        grid_checks+=1

for index,name,q,roots,regular in systems:
    got=answers[index];assert 'error' not in got,(name,got)
    if regular:assert got['complete'] and got['root_count']==len(roots),(name,got)
    else:assert not got['complete'] and got['unresolved'],(name,got)
    cells=[b['enclosure'] for b in got['roots']]+[b['box'] for b in got['unresolved']]
    for root in roots:assert any(contains(cell,root) for cell in cells),('lost reference root',name,list(map(str,root)),got)

inner_point_checks=0
for index,q,known in pavings:
    got=answers[index];assert 'error' not in got,(q,got)
    assert got['inside'] or got['unresolved'],got
    for p in known:assert any(contains(b['box'],list(map(mp.mpf,p))) for b in got['inside']+got['unresolved']),(q,p,got)
    for cell in got['inside']:
        for p in itertools.product(*[[mp.mpf(a),mp.mpf(a)*.5+mp.mpf(b)*.5,mp.mpf(b)] for a,b in cell['box']]):
            for c in q['constraints']:
                v=valid_value(c['expression'],p,q['variables']);assert v is not None
                if 'range' in c:
                    a,b=c['range'];assert (a is None or mp.mpf(a)<=v) and (b is None or v<=mp.mpf(b)),(q,cell,p,c,str(v))
                elif c['relation']=='<=':assert v<=mp.mpf(c['rhs'])
                elif c['relation']=='>=':assert v>=mp.mpf(c['rhs'])
                else:assert v==mp.mpf(c['rhs'])
            inner_point_checks+=1

report={'passed':True,'seed':SEED,'mpmath_version':mp.__version__,'decimal_digits':mp.mp.dps,
        'expression_boxes':len(evaluations),'high_precision_values':point_checks,'high_precision_derivatives':derivative_checks,
        'contractor_models':len(contracts)//3,'contractor_runs':len(contracts),'contractor_grid_checks':grid_checks,'root_systems':len(systems),
        'nonlinear_feasible_scenarios':len(pavings),'feasible_cell_points':inner_point_checks}
(ROOT/'artifacts/nonlinear-oracle.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
