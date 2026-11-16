#!/usr/bin/env node
import {readFileSync,existsSync,openSync,writeFileSync,closeSync,renameSync,unlinkSync} from 'node:fs';
import {resolve} from 'node:path';
import {randomUUID,createHash} from 'node:crypto';
import {Worker} from 'node:worker_threads';
const args=process.argv.slice(2);
if(args.length===0||args.includes('--help')){
  console.log('Usage: node bin/rootcover.mjs REQUEST.json|-\n       node bin/rootcover.mjs REQUEST.json --steps 100 --checkpoint STATE.json\n       node bin/rootcover.mjs --resume STATE.json --steps 100 --checkpoint NEXT.json\n       node bin/rootcover.mjs REQUEST.json --timeout-ms 2000 --timing\nSessions support feasibility mode. Steps add work within the original total budget.\nExit: 0 complete; 1 unresolved regions; 2 invalid input or runtime error; 3 timeout.');
  process.exit(args.length===1&&args[0]==='--help'?0:2);
}

// The original model file is never replaced by a checkpoint. Existing targets
// must already be checkpoints; write a sibling temporary file then rename.
function saveCheckpoint(path,checkpoint,input,resuming){
  const destination=resolve(path);
  if(!resuming&&input!=='-'&&destination===resolve(input))throw new Error('Checkpoint cannot overwrite the model request.');
  if(existsSync(destination)){
    const existing=JSON.parse(readFileSync(destination,'utf8'));
    if(existing.kind!=='rootcover.feasibility'||existing.checkpoint_version!==1)throw new Error('Checkpoint target contains another document.');
  }
  const temporary=destination+'.partial-'+randomUUID();let descriptor,created=false;
  try{
    descriptor=openSync(temporary,'wx');created=true;
    writeFileSync(descriptor,JSON.stringify(checkpoint,null,2)+'\n','utf8');closeSync(descriptor);descriptor=undefined;
    renameSync(temporary,destination);created=false;
  }finally{
    if(descriptor!==undefined)closeSync(descriptor);
    if(created&&existsSync(temporary))unlinkSync(temporary);
  }
}
try{
  const {run_request,run_session}=await import('../dist/engine.js');
  let input,resume,checkpoint,steps,echoRequest=false,timeoutMs,timing=false;
  for(let i=0;i<args.length;i++){
    const arg=args[i];
    if(arg==='--echo-request'){echoRequest=true;continue;}
    if(arg==='--timing'){timing=true;continue;}
    if(arg==='--timeout-ms'){
      const value=args[++i];
      if(!value||!/^[1-9][0-9]{0,5}$/.test(value)||Number(value)>600000)throw new Error('Timeout must be an integer in 1..600000 ms.');
      timeoutMs=Number(value);timing=true;continue;
    }
    if(['--resume','--checkpoint','--steps'].includes(arg)){
      const value=args[++i];if(!value||value.startsWith('--'))throw new Error('Missing option value.');
      if(arg==='--resume'){if(resume!==undefined)throw new Error('Duplicate --resume.');resume=value;}
      if(arg==='--checkpoint'){if(checkpoint!==undefined)throw new Error('Duplicate --checkpoint.');checkpoint=value;}
      if(arg==='--steps'){
        if(steps!==undefined||!/^[1-9][0-9]{0,4}$/.test(value)||Number(value)>20000)throw new Error('Steps must be an integer in 1..20000.');
        steps=Number(value);
      }
    }else{
      if(input!==undefined||(arg.startsWith('-')&&arg!=='-'))throw new Error('Unexpected argument.');input=arg;
    }
  }
  if(resume!==undefined&&input!==undefined)throw new Error('Choose a request or --resume, not both.');
  const session=resume!==undefined||checkpoint!==undefined||steps!==undefined;
  if(session&&(checkpoint===undefined||steps===undefined))throw new Error('Sessions require --steps and --checkpoint.');
  input=resume??input;if(input===undefined)throw new Error('Missing input file.');
  const raw=readFileSync(input==='-'?0:input,'utf8');
  if(raw.length>(resume!==undefined?4194304:262144))throw new Error('Input exceeds the supported size limit.');
  if(timeoutMs!==undefined&&session)throw new Error('--timeout-ms is not supported with sessions.');
  const started=Date.now();
  let result;
  if(timeoutMs!==undefined){
    const worker=new Worker(new URL('./solve-worker.mjs',import.meta.url),{workerData:{raw}});
    const outcome=await new Promise((resolvePromise)=>{
      let settled=false;
      const timer=setTimeout(()=>{if(!settled){settled=true;worker.terminate();resolvePromise({timeout:true});}},timeoutMs);
      worker.once('message',message=>{if(settled)return;settled=true;clearTimeout(timer);resolvePromise(message);});
      worker.once('error',error=>{if(settled)return;settled=true;clearTimeout(timer);resolvePromise({ok:false,message:error.message});});
    });
    if(outcome.timeout){
      writeFileSync(2,JSON.stringify({elapsed_ms:Date.now()-started})+'\n');
      writeFileSync(1,JSON.stringify({error:{code:'TIMEOUT',message:'Exceeded '+timeoutMs+' ms.'}},null,2)+'\n');
      process.exitCode=3;
      process.exit(3);
    }
    if(!outcome.ok)throw new Error(outcome.message);
    result=outcome.result;
  }else{
    const envelope=session?JSON.parse(run_session(raw,steps,resume!==undefined?'restore':'start')):null;
    result=session?(envelope.error?envelope:envelope.result):JSON.parse(run_request(raw));
    if(session&&!result.error)saveCheckpoint(checkpoint,envelope.checkpoint,input,resume!==undefined);
  }
  if(timing)console.error(JSON.stringify({elapsed_ms:Date.now()-started}));
  if(echoRequest&&!result.error){result.request=JSON.parse(raw);result.request_sha256=createHash('sha256').update(raw).digest('hex');}
  console.log(JSON.stringify(result,null,2));
  process.exitCode=result.error?2:result.complete?0:1;
}catch(error){
  console.error(JSON.stringify({error:{code:'HOST_ERROR',message:error.message}}));process.exitCode=2;
}
