import {parentPort,workerData} from 'node:worker_threads';
try{
  const {run_request}=await import('../dist/engine.js');
  parentPort.postMessage({ok:true,result:JSON.parse(run_request(workerData.raw))});
}catch(error){
  parentPort.postMessage({ok:false,message:error&&error.message?error.message:String(error)});
}
