import {run_session} from './engine.js';
self.onmessage=({data})=>{
  try{self.postMessage({id:data.id,envelope:JSON.parse(run_session(data.source,data.steps,data.action))});}
  catch(error){self.postMessage({id:data.id,envelope:{error:{code:'RUNTIME_ERROR',message:error.message}}});}
};
