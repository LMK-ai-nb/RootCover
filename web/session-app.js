const $=id=>document.getElementById(id);
let worker=null,generation=0,busy=false,current=null,runningAction=null;
const status=(text,error=false)=>{$('session-status').textContent=text;$('session-status').classList.toggle('error',error);};
function reportError(message){status(current?`${message}；原进度仍保留。`:message,true);}
function failStep(message){
  busy=false;if(worker)worker.terminate();worker=null;runningAction=null;
  reportError(message);controls();
}
function controls(){
  for(const id of ['session-start','session-load','session-example','session-steps','session-request','session-file'])$(id).disabled=busy;
  $('session-cancel').disabled=!busy;
  $('session-continue').disabled=busy||!current?.result.session.can_advance;
  $('session-save').disabled=busy||!current;
  $('session-report').disabled=busy||!current;
}
function discard(){
  generation++;if(worker)worker.terminate();worker=null;current=null;
  for(const id of ['session-inside','session-pending','session-unknown','session-assessments'])$(id).textContent='—';
  $('session-raw').textContent='尚未计算';$('session-budget').value=0;$('session-budget').max=1;
  $('session-budget-text').textContent='这表示预算使用量，不是求解完成百分比。';
  $('session-summary').textContent='开始后可以随时保存最近完成的一步。';controls();
}
function show(envelope){
  current=envelope;const {result:r}=envelope,s=r.session;
  $('session-request').value=envelope.checkpoint.request;
  if(runningAction==='load')$('session-example').value='custom';
  $('session-inside').textContent=r.inner_box_count;
  $('session-pending').textContent=s.pending_boxes;$('session-unknown').textContent=s.terminal_unknown_boxes;
  $('session-assessments').textContent=r.stats.assessments;
  $('session-budget').max=s.hard_assessment_limit;$('session-budget').value=r.stats.assessments;
  $('session-budget-text').textContent=`${r.stats.assessments} / ${s.hard_assessment_limit} 次评估预算已使用；不是求解完成百分比。`;
  $('session-summary').textContent=`已保留 ${r.inner_box_count} 个整盒可行区域，${s.pending_boxes} 个待处理区域及 ${s.terminal_unknown_boxes} 个边界未决区域。累计收缩调用 ${r.stats.contractor_calls} 次。`;
  $('session-result-note').textContent=r.complete?'全部区域已分类；空集结论只在没有可行盒且没有未决时成立。':'待处理与边界未决均保留在完整结果中；它们尚未被证明可行或不可行。';
  $('session-raw').textContent=JSON.stringify(r,null,2);
  status(s.can_advance?'已暂停，可继续':s.pending_boxes?'总评估预算已用完':r.complete?'全部区域已分类':'搜索结束，边界仍未决');
}
function startWorker(){
  if(worker)return;
  worker=new Worker('session-worker.js',{type:'module'});
  const instance=worker;
  worker.onmessage=({data})=>{
    if(worker!==instance||data.id!==generation)return;
    if(data.envelope.error){failStep(data.envelope.error.message||'无法处理这一步。');return;}
    busy=false;show(data.envelope);runningAction=null;
    controls();
  };
  worker.onerror=event=>{
    event.preventDefault();if(worker!==instance||!busy)return;
    failStep('计算未完成，请重试。');
  };
}
function execute(action,source=''){
  const steps=Number($('session-steps').value);
  if(action!=='load'&&(!Number.isInteger(steps)||steps<1||steps>20000)){status('每步工作量须为 1 至 20000 的整数。',true);return;}
  if(action==='start'){discard();}
  if(action==='advance'&&!worker){action='restore';source=JSON.stringify(current.checkpoint);}
  busy=true;generation++;runningAction=action;status(action==='load'||action==='restore'?'正在核验进度':'正在计算');controls();
  try{
    startWorker();worker.postMessage({id:generation,source,steps:action==='load'?0:steps,action});
  }catch(error){failStep(error.message||'无法创建计算线程。');}
}
function download(value,name){
  const url=URL.createObjectURL(new Blob([JSON.stringify(value,null,2)+'\n'],{type:'application/json'}));
  const a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
}
async function example(){
  discard();busy=true;const id=++generation;controls();status('正在载入场景');
  try{
    const name=$('session-example').value;
    if(!['design_alternatives','thermal_parameters','robust_localization','scaled_parameters'].includes(name))throw new Error('未知场景');
    const response=await fetch(`data/${name}.json`);if(!response.ok)throw new Error('场景载入失败');
    const request=await response.text();if(id!==generation)return;
    $('session-request').value=JSON.stringify(JSON.parse(request),null,2);status('准备就绪');
  }catch(error){if(id===generation)status(error.message,true);}
  finally{if(id===generation){busy=false;controls();}}
}
$('session-start').onclick=()=>execute('start',$('session-request').value);
$('session-continue').onclick=()=>execute('advance');
$('session-cancel').onclick=()=>{
  generation++;if(worker)worker.terminate();worker=null;busy=false;runningAction=null;
  status(current?'已停止，本步前的进度仍保留':'已停止');controls();
};
$('session-request').addEventListener('input',()=>{discard();$('session-example').value='custom';status('问题已修改，请重新开始。');});
$('session-example').onchange=example;
$('session-save').onclick=()=>download(current.checkpoint,'RootCover.rootcover-checkpoint.json');
$('session-report').onclick=()=>download({request:JSON.parse(current.checkpoint.request),result:current.result},'RootCover-session-result.json');
$('session-load').onclick=()=>$('session-file').click();
$('session-file').onchange=async()=>{
  const file=$('session-file').files[0];if(!file)return;
  $('session-file').value='';
  if(file.size>8*1024*1024){reportError('进度文件过大。');return;}
  busy=true;const id=++generation;controls();status('正在读取进度');
  try{
    const source=await file.text();if(id!==generation)return;
    const checkpoint=JSON.parse(source);
    if(typeof checkpoint.request!=='string')throw new Error('进度文件缺少原问题。');
    // Keep the last verified snapshot and displayed model until a replacement
    // has passed the MoonBit verifier. A rejected file must not erase work.
    if(worker)worker.terminate();worker=null;
    execute('load',source);
  }catch(error){if(id===generation){busy=false;reportError(error.message);controls();}}
};
example();
