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
  assert.equal(r.complete,false);assert.equal(r.stats.assessments,1);assert.equal(r.unresolved.length,2);
});
test('raw duplicate keys and invalid numeric forms cannot silently change a request',()=>{
  const s=JSON.stringify(load('geometry'));
  assert(JSON.parse(run_request(s.replace('"version":1','"version":1,"version":1'))).error);
  const q=load('geometry');q.box[0]=[2,1];assert(run(q).error);
  q.box[0]=[-1.5,1.5];q.equations[0]='sin(x)';assert(run(q).error);
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
