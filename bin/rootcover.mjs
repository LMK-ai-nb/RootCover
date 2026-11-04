#!/usr/bin/env node
import {readFileSync} from 'node:fs';
const args=process.argv.slice(2);
if(args.length!==1||args[0]==='--help'){
  console.log('Usage: node bin/rootcover.mjs REQUEST.json|-\nExit: 0 complete; 1 unresolved regions; 2 invalid input or runtime error.');
  process.exit(args[0]==='--help'?0:2);
}
try{
  const {run_request}=await import('../dist/engine.js');
  const raw=readFileSync(args[0]==='-'?0:args[0],'utf8');
  if(raw.length>262144)throw new Error('Request exceeds 256 Ki UTF-16 units.');
  const result=JSON.parse(run_request(raw));
  console.log(JSON.stringify(result,null,2));
  process.exitCode=result.error?2:result.complete?0:1;
}catch(error){
  console.error(JSON.stringify({error:{code:'HOST_ERROR',message:error.message}}));process.exitCode=2;
}
