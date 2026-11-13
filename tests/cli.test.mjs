import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {run_request} from '../dist/engine.js';
const load=name=>JSON.parse(readFileSync(new URL(`../examples/${name}.json`,import.meta.url),'utf8'));
const run=q=>JSON.parse(run_request(JSON.stringify(q)));
const contains=(a,x)=>a[0]<=x&&x<=a[1];
test('geometry returns both analytic intersections',()=>{
  const r=run(load('geometry'));assert.equal(r.complete,true);assert.equal(r.root_count,2);
  for(const v of [-1,1])assert(r.roots.some(b=>b.enclosure.every(a=>contains(a,v))));
});
test('inverse calibration preserves all branches and supports physical range selection',()=>{
  const q=load('calibration');const r=run(q);assert.equal(r.complete,true);assert.equal(r.root_count,3);
  q.box=[[0,1]];const selected=run(q);assert.equal(selected.complete,true);assert.equal(selected.root_count,1);
  assert(selected.roots[0].enclosure[0][0]>0.34);assert(selected.roots[0].enclosure[0][1]<0.35);
});
test('positive reaction equilibrium encloses the analytic steady state',()=>{
  const r=run(load('equilibrium'));assert.equal(r.complete,true);assert.equal(r.root_count,1);
  assert(contains(r.roots[0].enclosure[0],1));assert(contains(r.roots[0].enclosure[1],3));
});
test('singular root is unresolved and covered',()=>{
  const r=run(load('singular'));assert.equal(r.complete,false);assert.equal(r.root_count,0);
  assert(r.unresolved.some(b=>contains(b.box[0],0)));
});
test('budget one leaves pending regions visible',()=>{
  const q=load('geometry');q.options={max_assessments:1};const r=run(q);
  assert.equal(r.complete,false);assert.equal(r.stats.assessments,1);assert(r.unresolved.length>0);
  for(const x of [-1,1])assert(r.unresolved.some(b=>b.box.every(a=>contains(a,x))));
});
test('raw duplicate keys and invalid numeric forms cannot silently change a request',()=>{
  const s=JSON.stringify(load('geometry'));
  assert(JSON.parse(run_request(s.replace('"version":1','"version":1,"version":1'))).error);
  const q=load('geometry');q.box[0]=[2,1];assert(run(q).error);
  q.box[0]=[-1.5,1.5];q.equations[0]='unknown(x)';assert(run(q).error);
});
test('CLI exit status distinguishes complete, unresolved and invalid',()=>{
  for(const [name,code] of [['geometry',0],['singular',1]]){
    const p=spawnSync(process.execPath,['bin/rootcover.mjs',`examples/${name}.json`],{encoding:'utf8'});
    assert.equal(p.status,code,p.stderr);assert(JSON.parse(p.stdout).roots);
  }
  const p=spawnSync(process.execPath,['bin/rootcover.mjs','-'],{input:'{"version":9}',encoding:'utf8'});
  assert.equal(p.status,2);assert(JSON.parse(p.stdout).error);
});
test('three-dimensional range localization preserves both mirror solutions',()=>{
  const r=run(load('localization'));assert.equal(r.complete,true);assert.equal(r.root_count,2);
  for(const z of [-2,2])assert(r.roots.some(b=>b.enclosure.every((a,i)=>contains(a,[1,1,z][i]))));
});
test('six coupled polynomial equations return all 64 analytic combinations',()=>{
  const r=run(load('coupled6'));assert.equal(r.complete,true);assert.equal(r.root_count,64);
  for(let mask=0;mask<64;mask++)assert(r.roots.some(b=>b.enclosure.every((a,i)=>contains(a,mask>>i&1?1:-1))));
});
test('bounded noisy localization certifies whole feasible boxes and preserves uncertain cells',()=>{
  const r=run(load('noisy_localization'));assert.equal(r.mode,'feasibility');assert.equal(r.complete,false);
  assert.equal(r.resolution_met,true);assert(r.inside.length>0);assert(r.unresolved.length>0);
  assert(!Object.hasOwn(r,'root_count'));
  assert(r.inside.some(b=>b.box.every(a=>contains(a,1))));
  for(const b of r.inside)for(let i=0;i<3;i++){
    const allowed=load('noisy_localization').constraints[i].range;
    assert(b.ranges[i][0]>=allowed[0]&&b.ranges[i][1]<=allowed[1]);
  }
});
test('calibration tolerance bands preserve all three feasible branches',()=>{
  const q=load('calibration_band'),r=run(q);assert.equal(r.mode,'feasibility');assert.equal(r.resolution_met,true);
  for(const x of [-1.8793852415718169,0.3472963553338607,1.532088886237956]){
    assert([...r.inside,...r.unresolved].some(b=>contains(b.box[0],x)));
  }
});
test('feasibility budget exhaustion remains unresolved and CLI exits one',()=>{
  const q=load('noisy_localization');q.options.max_assessments=1;
  const r=run(q);assert.equal(r.complete,false);assert.equal(r.resolution_met,false);assert.equal(r.unresolved.length,2);
  const p=spawnSync(process.execPath,['bin/rootcover.mjs','-'],{input:JSON.stringify(q),encoding:'utf8'});
  assert.equal(p.status,1);assert.equal(JSON.parse(p.stdout).mode,'feasibility');
});
test('inconsistent measurement bands can be proven empty without claiming a root count',()=>{
  const q=load('calibration_band');q.constraints=[{expression:'x',range:[0.5,1]},{expression:'x',range:[-1,-0.5]}];
  const r=run(q);assert.equal(r.complete,true);assert.equal(r.definitely_empty,true);assert.equal(r.inside.length,0);
});

test('two-link inverse kinematics certifies both nonlinear configurations',()=>{
  const r=run(load('robot_roots'));assert.equal(r.complete,true);assert.equal(r.root_count,2);
  for(const p of [[0,Math.PI/2],[Math.PI/2,-Math.PI/2]])assert(r.roots.some(b=>b.enclosure.every((a,i)=>contains(a,p[i]))));
});

test('nonlinear feasible scenarios retain known parameters and certify inner boxes',()=>{
  for(const [name,p] of [['robot_workspace',[0,Math.PI/2]],['thermal_parameters',[2,.5,.25]],['mixed_process',[1,.7]]]){
    const q=load(name),r=run(q);assert(!r.error,JSON.stringify(r));assert(r.inside.length>0);
    assert.equal(r.resolution_met,true);assert(r.stats.contractor_calls>0);
    assert([...r.inside,...r.unresolved].some(b=>b.box.every((a,i)=>contains(a,p[i]))));
    for(const cell of r.inside)for(const [i,c] of q.constraints.entries()){
      const [a,b]=cell.ranges[i];
      if(c.range){assert(c.range[0]===null||a>=c.range[0]);assert(c.range[1]===null||b<=c.range[1]);}
      else if(c.relation==='<=')assert(b<=c.rhs);
      else if(c.relation==='>=')assert(a>=c.rhs);
    }
  }
});

test('contractor switches control execution without dropping known feasible points',()=>{
  for(const [propagation,newton] of [[false,false],[true,false],[false,true],[true,true]]){
    const q=load('mixed_process');q.contractors={propagation,newton};const r=run(q);
    assert([...r.inside,...r.unresolved].some(b=>b.box.every((a,i)=>contains(a,[1,.7][i]))));
    assert.equal(r.stats.contractor_calls===0,!propagation&&!newton);
  }
});

test('unbounded observation bands never certify undefined points as feasible',()=>{
  const q={version:1,mode:'feasibility',variables:['x'],constraints:[{expression:'log(x)',range:[null,null]}],box:[[-1,1]],options:{tolerance:1e-5}};
  const r=run(q);assert(!r.error);assert(r.inside.length>0);
  assert(r.inside.every(b=>b.box[0][0]>0));assert(r.unresolved.some(b=>contains(b.box[0],0)));
  assert([...r.inside,...r.unresolved].some(b=>contains(b.box[0],.5)));
});

test('nonlinear request controls and relation syntax reject misleading inputs',()=>{
  const q=load('mixed_process');
  for(const config of [{newton:1},{propagation:'yes'},{max_steps:0},{max_rounds:33},{method:'magic'}]){
    assert(run({...q,contractors:config}).error,JSON.stringify(config));
  }
  const invalid=[{expression:'x',relation:'<',rhs:1},{expression:'x',range:[0,1],relation:'<=',rhs:1},{expression:'x',range:[1,0]}];
  for(const c of invalid)assert(run({...q,constraints:[c]}).error);
});

test('unbounded output endpoints remain valid JSON when elementary ranges overflow',()=>{
  const q={version:1,mode:'feasibility',variables:['x'],constraints:[{expression:'exp(x)',range:[0,null]}],box:[[1000,2000]]};
  const r=run(q);assert(!r.error);assert.equal(r.complete,true);assert.equal(r.inside.length,1);
  assert(r.inside[0].ranges[0][0]>1e300);assert.equal(r.inside[0].ranges[0][1],null);
});
