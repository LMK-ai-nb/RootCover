const $ = s => document.querySelector(s);
let selected='geometry', worker=null, serial=0, loadId=0, last=null, request=null;
const descriptions={
  geometry:'圆 x² + y² = 2 与直线 y = x。在 [-1.5, 1.5]² 搜索，预期有两处交点。',
  calibration:'合成标定曲线 x³ − 3x + 1 = 0。可限制取值范围，或加入 ±0.125 的观测容差。',
  equilibrium:'合成反应模型的两个非线性平衡方程，在给定正区域包围 (1, 3)。',
  noisy_localization:'三个测距基站位于 (0,0)、(4,0)、(0,4)，距离平方观测带为 [1.75,2.25]、[9.75,10.25]、[9.75,10.25]。绿色盒内所有坐标均符合观测。'
};
function resetWorker(){
  worker?.terminate();
  const current = new Worker(new URL('./worker.js',import.meta.url),{type:'module'});
  worker=current;
  current.onmessage=({data})=>{if(current===worker && data.id===serial)finish(data.result);};
  current.onerror=e=>{if(current===worker)finish({error:{message:e.message||'求解线程加载失败'}});};
}
function busy(value){
  for(const id of ['run','request','branch','tolerance-band','budget','reset'])$('#'+id).disabled=value;
  $('#cancel').disabled=!value;
}
async function load(name){
  const id=++loadId;selected=name;serial++;resetWorker();busy(true);
  $('#download').disabled=true;$('#status').textContent='正在读取样例…';
  try{
    const response=await fetch(`data/${name}.json`);
    if(!response.ok)throw new Error('无法读取示例');
    const q=await response.json();if(id!==loadId)return;
    $('#request').value=JSON.stringify(q,null,2);
    $('#case-description').textContent=descriptions[name];
    $('#branch').hidden=name!=='calibration';$('#tolerance-band').hidden=name!=='calibration';
    document.querySelectorAll('[data-case]').forEach(b=>b.classList.toggle('active',b.dataset.case===name));run();
  }catch(e){if(id===loadId)finish({error:{message:e.message}});}
}
function run(){
  serial++;last=null;$('#download').disabled=true;$('#status').textContent='正在求解…';$('#status').classList.remove('error');
  try{request=JSON.parse($('#request').value);}catch{request=null;}
  busy(true);worker.postMessage({id:serial,source:$('#request').value});
}
function finish(result){
  busy(false);last=result;$('#raw').textContent=JSON.stringify(result,null,2);$('#root-list').replaceChildren();
  if(result.error){
    $('#status').textContent='输入无效';$('#status').classList.add('error');$('#root-count').textContent='—';$('#unknown-count').textContent='—';
    $('#summary').textContent=result.error.message;$('#plot').replaceChildren();return;
  }
  const paving=result.mode==='feasibility';
  $('#primary-label').textContent=paving?'已确认可行盒':'已确认唯一解';
  $('#root-count').textContent=paving?result.inner_box_count:result.root_count;
  $('#unknown-count').textContent=result.unresolved.length;
  $('#status').textContent=result.complete?(paving?'区域已分类':'区域已解析'):(paving&&result.resolution_met?'分辨率已达 · 有未决':'仍有未决');
  $('#legend-main').textContent=paving?'整盒满足全部观测带':'唯一解包围盒 / 中心标记';
  const stats=result.stats;
  let summary=`${stats.assessments} 次区域评估 · ${stats.excluded} 次排除 · ${stats.splits} 次划分。`;
  if(paving){
    summary+=result.resolution_met?'所有未决盒宽度已达到设定分辨率。':'仍有未决盒尚未达到设定分辨率。';
    summary+='可行盒数量不是解的个数；未决盒可能可行，也可能不可行。';
  }else{
    summary+=`${stats.contractions} 次收缩。`;
    summary+=result.roots.length?(result.tolerance_met?'已确认解的包围宽度满足设定容差。':'部分根包围尚未达到设定容差。'):'当前没有已确认的唯一解。';
  }
  const items=paving?result.inside:result.roots;
  for(const [i,r]of items.slice(0,8).entries()){
    const row=document.createElement('div');row.className='root-row';
    const label=document.createElement('b');label.textContent=paving?`可行盒 ${i+1}`:`解 ${i+1}`;
    const value=document.createElement('code');
    value.textContent=(paving?r.box:r.enclosure).map((a,j)=>`${result.variables[j]} ∈ [${a[0]}, ${a[1]}]`).join('  ·  ')+(paving?'':`  / q ≤ ${r.certificate.contraction_bound}`);
    row.append(label,value);$('#root-list').append(row);
  }
  if(items.length>8)summary+='列表仅展示前8项；导出报告包含全部区域。';
  $('#summary').textContent=summary;$('#download').disabled=false;draw(result);
}
const ns='http://www.w3.org/2000/svg';
function draw(r){
  const svg=document.createElementNS(ns,'svg');svg.setAttribute('viewBox','0 0 650 340');
  function el(tag,attrs,text){const e=document.createElementNS(ns,tag);for(const [k,v]of Object.entries(attrs))e.setAttribute(k,String(v));if(text!=null)e.textContent=text;svg.append(e);return e;}
  const n=r.variables.length,[a,b]=r.initial_box[0],[c,d]=n>1?r.initial_box[1]:[-1,1];
  const px=x=>60+(b/2===a/2?0.5:(x/2-a/2)/(b/2-a/2))*550;
  const py=y=>290-(d/2===c/2?0.5:(y/2-c/2)/(d/2-c/2))*260;
  for(let i=0;i<=5;i++){
    const x=a*(1-i/5)+b*i/5,y=c*(1-i/5)+d*i/5;
    el('line',{x1:px(x),y1:30,x2:px(x),y2:290,stroke:'#e0e9dd'});
    el('text',{x:px(x),y:312,fill:'#879984','font-size':10,'text-anchor':'middle'},x.toPrecision(3));
    if(n>1){el('line',{x1:60,y1:py(y),x2:610,y2:py(y),stroke:'#e0e9dd'});el('text',{x:48,y:py(y)+3,fill:'#879984','font-size':10,'text-anchor':'end'},y.toPrecision(3));}
  }
  function cell(v,color,alpha){
    el('rect',{x:px(v[0][0]),y:n>1?py(v[1][1]):100,width:Math.max(0.6,px(v[0][1])-px(v[0][0])),height:n>1?Math.max(0.6,py(v[1][0])-py(v[1][1])):150,fill:color,'fill-opacity':alpha,stroke:color,'stroke-width':0.3});
  }
  for(const item of r.unresolved.slice(0,1000))cell(item.box,'#c4933b',.3);
  if(r.mode==='feasibility'){
    for(const item of r.inside.slice(0,1000))cell(item.box,'#267052',.52);
  }else{
    for(const [i,item]of r.roots.slice(0,1000).entries()){
      const v=item.enclosure,x=px(v[0][0]/2+v[0][1]/2),y=n>1?py(v[1][0]/2+v[1][1]/2):160;
      el('circle',{cx:x,cy:y,r:13,fill:'#91c69a','fill-opacity':.22});el('circle',{cx:x,cy:y,r:5,fill:'#267052',stroke:'white','stroke-width':2});
      el('text',{x:x+12,y:y-12,fill:'#35734e','font-size':11},`解 ${i+1}`);
    }
  }
  el('text',{x:610,y:333,fill:'#607d64','font-size':11,'text-anchor':'end'},r.variables[0]);
  if(n>1)el('text',{x:28,y:22,fill:'#607d64','font-size':11},r.variables[1]);
  $('#axes').textContent=n>1?`${r.variables[0]} × ${r.variables[1]}${n>2?' / 投影':''}`:r.variables[0];$('#plot').replaceChildren(svg);
}
for(const b of document.querySelectorAll('[data-case]'))b.onclick=()=>load(b.dataset.case);
$('#run').onclick=run;$('#reset').onclick=()=>load(selected);
$('#cancel').onclick=()=>{loadId++;serial++;resetWorker();busy(false);$('#status').textContent='已停止';$('#summary').textContent='计算已停止，可调整请求后再次运行。';};
function modify(fn){try{const q=JSON.parse($('#request').value);fn(q);$('#request').value=JSON.stringify(q,null,2);run();}catch(e){finish({error:{message:e.message}});}}
$('#budget').onclick=()=>modify(q=>{q.options={...q.options,max_assessments:1};});
$('#branch').onclick=()=>modify(q=>{q.box=[[0,1]];});
$('#tolerance-band').onclick=()=>modify(q=>{
  if(q.constraints){q.constraints[0].range=[-0.125,0.125];}
  else{q.mode='feasibility';q.constraints=q.equations.map(expression=>({expression,range:[-0.125,0.125]}));delete q.equations;}
  q.options={...q.options,tolerance:0.001};
});
$('#download').onclick=()=>{
  if(!last||last.error)return;
  const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([JSON.stringify({request,result:last},null,2)],{type:'application/json'}));a.download='rootcover-report.json';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000);
};
resetWorker();load('geometry');
