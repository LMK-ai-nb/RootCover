import {createInterface} from 'node:readline';
import {run_request} from '../dist/engine.js';
import {probe} from '../_build/js/release/build/tests/probe/probe.js';
for await(const line of createInterface({input:process.stdin,crlfDelay:Infinity})){
  try{
    const value=JSON.parse(line);
    const result=value.kind==='probe'?probe(JSON.stringify(value.rows)):run_request(JSON.stringify(value.request));
    console.log(result);
  }catch(e){console.log(JSON.stringify({error:String(e)}));}
}
