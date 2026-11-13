import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {run_request,run_session} from '../dist/engine.js';
const run=(source,steps,action)=>JSON.parse(run_session(typeof source==='string'?source:JSON.stringify(source),steps,action));
const output=[];
for(const request of JSON.parse(readFileSync(0,'utf8'))){
  let envelope=run(request,1,'start');assert(!envelope.error,JSON.stringify(envelope));
  const snapshots=[envelope.result];let index=0;const pattern=[3,7,19,41,83];
  while(envelope.result.session.can_advance){
    const step=pattern[index%pattern.length],restore=index++%2===0;
    envelope=restore?run(envelope.checkpoint,step,'restore'):run('',step,'advance');
    assert(!envelope.error,JSON.stringify(envelope));snapshots.push(envelope.result);
  }
  const plain=structuredClone(envelope.result);delete plain.session;
  assert.deepEqual(plain,JSON.parse(run_request(JSON.stringify(request))));
  const mutations=[];
  for(const transform of [
    e=>e.splice(0,1),e=>e.pop(),e=>{if(e.length)e[0]={kind:'inside'};},
    e=>{if(e.length)e[0]={kind:'outside'};},
    e=>{if(e.length)e[0]={kind:'split',axis:0,point:request.box[0][1]+1};},
  ]){
    const checkpoint=structuredClone(envelope.checkpoint);transform(checkpoint.events);
    const changed=run(checkpoint,1,'restore');mutations.push(changed.error?null:changed.result);
  }
  output.push({snapshots,mutations});
}
process.stdout.write(JSON.stringify(output));
