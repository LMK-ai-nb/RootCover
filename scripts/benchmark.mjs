import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {cpus} from 'node:os';
import {performance} from 'node:perf_hooks';
import {run_request} from '../dist/engine.js';
const rows=[];
for(const [name,count] of [['geometry',2],['calibration',3],['equilibrium',1],['localization',2],['coupled6',64]]){
  const raw=readFileSync(new URL(`../examples/${name}.json`,import.meta.url),'utf8');
  for(let i=0;i<2;i++)run_request(raw);
  const times=[];let result;
  for(let i=0;i<7;i++){const start=performance.now();result=JSON.parse(run_request(raw));times.push(performance.now()-start);}
  if(!result.complete||result.root_count!==count)throw new Error(`Incomplete benchmark: ${name}`);
  const sorted=[...times].sort((a,b)=>a-b);rows.push({case:name,root_count:count,assessments:result.stats.assessments,median_ms:sorted[3],samples_ms:times});
}
const report={node:process.version,platform:process.platform,arch:process.arch,cpu:cpus()[0]?.model,scope:'Synthetic inputs, JSON decode/validation/solve/encode and host JSON parse; 2 warmups, 7 samples. Not a comparison with other solvers.',cases:rows};
mkdirSync(new URL('../artifacts/',import.meta.url),{recursive:true});writeFileSync(new URL('../artifacts/benchmark.json',import.meta.url),JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
