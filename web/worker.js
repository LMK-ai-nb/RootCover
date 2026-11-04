import {run_request} from './engine.js';
self.onmessage=({data})=>{
  try{self.postMessage({id:data.id,result:JSON.parse(run_request(data.source))});}
  catch(error){self.postMessage({id:data.id,result:{error:{code:'RUNTIME_ERROR',message:error.message}}});}
};
