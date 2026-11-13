import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync} from 'node:fs';
import {resolve} from 'node:path';
import {run_request,run_session} from '../dist/engine.js';

const load=name=>JSON.parse(readFileSync(new URL(`../examples/${name}.json`,import.meta.url),'utf8'));
const call=(source,steps,action)=>JSON.parse(run_session(typeof source==='string'?source:JSON.stringify(source),steps,action));
const plain=result=>{const r=structuredClone(result);delete r.session;return r;};
const linear=()=>({version:1,mode:'feasibility',variables:['x'],constraints:[{expression:'x',range:[.2,.8]}],box:[[0,1]],contractors:{propagation:false,newton:false},options:{tolerance:1/64,max_assessments:500},search:{strategy:'bfs'}});

test('sessions match uninterrupted solving for six nonlinear scenarios under DFS and BFS',()=>{
  for(const name of ['robot_workspace','thermal_parameters','mixed_process','robust_localization','design_alternatives','scaled_parameters'])for(const strategy of ['dfs','bfs']){
    const q=load(name);q.search={...q.search,strategy};let envelope=call(q,7,'start');assert(!envelope.error,JSON.stringify(envelope));
    let iteration=0;
    while(envelope.result.session.can_advance){
      const previous=envelope.result.stats.assessments;
      envelope=++iteration%3===0?call(envelope.checkpoint,137,'restore'):call('',137,'advance');
      assert(!envelope.error,JSON.stringify(envelope));
      assert(envelope.result.stats.assessments>previous);
    }
    assert.deepEqual(plain(envelope.result),JSON.parse(run_request(JSON.stringify(q))),name+' '+strategy);
  }
});

test('restoring cannot turn unclassified space into an inside or outside certificate',()=>{
  const base={checkpoint_version:1,kind:'rootcover.feasibility',request:JSON.stringify(linear())};
  for(const kind of ['inside','outside'])assert(call({...base,events:[{kind}]},1,'restore').error);
  const truncated=call({...base,events:[]},1,'restore');
  assert.equal(truncated.result.complete,false);assert.equal(truncated.result.session.pending_boxes,2);
  for(const point of [-.01,0,1,1.01])assert(call({...base,events:[{kind:'split',axis:0,point}]},1,'restore').error);
});

test('malformed checkpoint envelopes and unsupported root sessions fail explicitly',()=>{
  assert(call(load('geometry'),1,'start').error);
  assert(call(linear(),0,'start').error);assert(call(linear(),20001,'start').error);
  const envelope=call(linear(),1,'start');
  assert(call({...envelope.checkpoint,inside:[]},1,'restore').error);
  assert(call({...envelope.checkpoint,checkpoint_version:2},1,'restore').error);
  assert(call(JSON.stringify(envelope.checkpoint).replace('"checkpoint_version":1','"checkpoint_version":1,"checkpoint_version":1'),1,'restore').error);
  assert(call('',1,'invalid').error);
});

test('a stopped search retains unresolved precision and depth cells rather than reprocessing them',()=>{
  const q=linear();q.options={tolerance:1e-6,max_assessments:3,max_depth:1};
  let envelope=call(q,1,'start');envelope=call(envelope.checkpoint,100,'restore');
  assert.equal(envelope.result.stats.assessments,3);assert.equal(envelope.result.session.can_advance,false);
  assert.equal(envelope.result.session.terminal_unknown_boxes,2);
  const again=call('',100,'advance');assert.deepEqual(again,envelope);
});

test('load audits the checkpoint without spending a new assessment',()=>{
  const first=call(linear(),5,'start');const loaded=call(first.checkpoint,0,'load');
  assert(!loaded.error);assert.deepEqual(plain(loaded.result),plain(first.result));
  assert.equal(loaded.result.session.replayed_events,5);
  assert.deepEqual(loaded.checkpoint,first.checkpoint);
});

test('global contractor and assessment budgets are unchanged across restores',()=>{
  const q=load('design_alternatives');q.options.max_assessments=27;q.contractors={max_steps:11};
  let envelope=call(q,4,'start');
  for(let i=0;i<4;i++)envelope=call(envelope.checkpoint,7,'restore');
  assert.equal(envelope.result.stats.assessments,27);assert(envelope.result.stats.contractor_calls<=11);
  assert.equal(envelope.result.session.can_advance,false);
  assert(envelope.result.unresolved.some(c=>c.status==='pending'));
  assert.deepEqual(plain(envelope.result),JSON.parse(run_request(JSON.stringify(q))));
});

test('CLI checkpoints survive a fresh process and support atomic in-place replacement',()=>{
  const folder=new URL('../work/',import.meta.url);mkdirSync(folder,{recursive:true});
  const directory=mkdtempSync(new URL('../work/session-cli-',import.meta.url));const state=resolve(directory,'run.rootcover-checkpoint.json');
  let run=spawnSync(process.execPath,['bin/rootcover.mjs','examples/robust_localization.json','--steps','5','--checkpoint',state],{encoding:'utf8'});
  assert.equal(run.status,1,run.stderr);assert.equal(JSON.parse(run.stdout).stats.assessments,5);
  run=spawnSync(process.execPath,['bin/rootcover.mjs','--resume',state,'--steps','20000','--checkpoint',state],{encoding:'utf8'});
  assert.equal(run.status,1,run.stderr);const result=JSON.parse(run.stdout);
  assert.equal(result.session.pending_boxes,0);assert.equal(result.inner_box_count,15);
  assert.equal(JSON.parse(readFileSync(state,'utf8')).events.length,result.stats.assessments);
});

test('CLI refuses to overwrite the model or an unrelated document',()=>{
  const folder=new URL('../work/',import.meta.url);mkdirSync(folder,{recursive:true});
  const directory=mkdtempSync(new URL('../work/session-write-',import.meta.url));const input=resolve(directory,'model.json');
  const raw=JSON.stringify(linear());writeFileSync(input,raw);
  let run=spawnSync(process.execPath,['bin/rootcover.mjs',input,'--steps','3','--checkpoint',input],{encoding:'utf8'});
  assert.equal(run.status,2);assert.equal(readFileSync(input,'utf8'),raw);
  const other=resolve(directory,'notes.json');writeFileSync(other,'{"notes":"keep"}');
  run=spawnSync(process.execPath,['bin/rootcover.mjs',input,'--steps','3','--checkpoint',other],{encoding:'utf8'});
  assert.equal(run.status,2);assert.equal(readFileSync(other,'utf8'),'{'+'"notes":"keep"}');
});
