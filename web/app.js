import{inspect,pairs,candidate_pairs,export_case}from'./engine.js';
const $=id=>document.getElementById(id);
const el=(tag,value,cls)=>{const e=document.createElement(tag);e.textContent=value;if(cls)e.className=cls;return e;};
let source='',request=null,result=null,selected='plan',witnessFocus=null;
const names={RIGHT_MULTIPLICITY:'一条左记录，匹配了两条右记录',LEFT_MULTIPLICITY:'两条左记录，匹配了同一条右记录',MISSING_RIGHT:'左记录没有匹配对象',MISSING_LEFT:'右记录没有匹配对象',OUTPUT_BUDGET:'输出规模超过声明的预算'};
const descriptions={RIGHT_MULTIPLICITY:'三行即可复现重复计数。删掉其中任意一行，这个基数反例就不再成立。',LEFT_MULTIPLICITY:'完整的三行反例，说明左表不满足声明的唯一性。',MISSING_RIGHT:'已检查完整右表；这不是用空白截图片段“证明”不存在。',MISSING_LEFT:'已检查完整左表；外连接保留记录，也不会补出真实匹配。',OUTPUT_BUDGET:'仅按分组乘积精确计数；预检没有构造这些结果行。'};
const current=()=>selected==='candidate'?result.comparison.candidate:result.audit;
function literal(v){return v===null?'NULL':typeof v==='string'?`"${v}"`:String(v);}
function renderTable(side,table,p){
  const head=$(`${side}-head`),body=$(`${side}-body`);head.replaceChildren();body.replaceChildren();
  $(`${side}-name`).textContent=table.name;$(`${side}-size`).textContent=`${table.rows.length} rows`;
  const tr=document.createElement('tr');tr.append(el('th','ROW ID'));for(const col of table.columns)tr.append(el('th',col));head.append(tr);
  const keyColumns=p.keys.map(k=>k[side]);
  const focused=new Set(witnessFocus?.[`${side}_ids`]||[]);
  for(const row of table.rows.slice(0,12)){
    const tr=document.createElement('tr');if(focused.has(row.id))tr.className='highlight';tr.append(el('td',row.id));
    row.values.forEach((v,i)=>{const td=el('td',literal(v),`${keyColumns.includes(table.columns[i])?'key-cell':''} ${v===null?'null-cell':''}`);td.title=literal(v);tr.append(td);});body.append(tr);
  }
  if(table.rows.length>12){const tr=document.createElement('tr'),td=el('td',`另有 ${table.rows.length-12} 行；完整输入全部参与预检。`);td.colSpan=table.columns.length+1;tr.append(td);body.append(tr);}
}
function download(name,value){const a=document.createElement('a'),url=URL.createObjectURL(new Blob([JSON.stringify(value,null,2)+'\n'],{type:'application/json'}));a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),2000);}
function render(){
  if(!result)return;const audit=current(),inv=audit.inventory,p=selected==='candidate'?request.candidate:request.plan;
  $('output-count').textContent=inv.output_rows;$('missing-count').textContent=inv.unmatched_left.length;$('issue-count').textContent=audit.issue_count;$('issue-count').classList.toggle('warning',!audit.safe);
  $('safe-status').textContent=audit.safe?'契约通过':'需要检查';$('safe-status').classList.toggle('safe',audit.safe);$('safe-note').textContent=audit.safe?'可在声明预算内构造结果':'预检先拦住问题，再解释来源';
  $('output-note').textContent=`${inv.left_rows} 条左记录 × ${inv.right_rows} 条右记录`;if(result.witness_valid!==undefined)$('output-note').textContent+=` · 反例核验${result.witness_valid?'通过':'未通过'}`;
  $('issue-note').textContent=`${audit.right_multiplicity_groups} 组右侧多重匹配 · ${audit.left_multiplicity_groups} 组左侧多重匹配`;
  $('plan-label').replaceChildren(el('span',`${(p.kind||'inner').toUpperCase()} JOIN`,'kind-chip'));for(const k of p.keys)$('plan-label').append(el('span',`${k.left} = ${k.right}`,'key-chip'));
  $('null-mode').textContent=`NULL ${p.nulls==='equal'?'可匹配':'不匹配'} · ${selected==='candidate'?'候选键':'原始键'}`;
  $('toggle-plan').disabled=!request.candidate;$('toggle-plan').textContent=selected==='plan'?'切换到候选键 →':'返回原始键 ←';
  $('join-kind').textContent=`${(p.kind||'inner').toUpperCase()} JOIN`;
  renderTable('left',request.left,p);renderTable('right',request.right,p);
  $('source-note').textContent=witnessFocus?'高亮的是当前证据引用的真实来源行。完整输入用于缺失匹配核验。':'蓝色列是当前关联键。文本、整数、布尔值严格区分；NULL 的匹配语义由计划显式声明。';
  $('evidence-total').textContent=audit.witnesses.length;$('evidence-list').replaceChildren();
  if(audit.safe)$('evidence-list').append(el('div','✓ 声明的基数、覆盖率与预算契约已通过。这能证明样本满足这些约束，业务键的含义仍由你判断。','good-evidence'));
  for(const [i,w] of audit.witnesses.entries()){
    const card=el('div','','witness'),title=el('div','','witness-code');title.append(el('b',names[w.code]||w.code),el('small',w.scope==='constructive'?'3 ROWS':'FULL INPUT'));card.append(title,el('p',descriptions[w.code]||w.explanation));
    const ids=el('div','','ids');ids.append(el('span','LEFT '),document.createTextNode(w.left_ids.join(', ')||'∅'),el('br',''),el('span','RIGHT '),document.createTextNode(w.right_ids.join(', ')||'∅'));card.append(ids);
    const focus=el('button','定位来源');focus.onclick=()=>{witnessFocus=w;render();};card.append(focus);
    if(w.scope==='constructive'&&selected==='plan'){const button=el('button','导出三行反例 ↓');button.className='export-case';button.style.marginLeft='7px';button.onclick=()=>{const value=JSON.parse(export_case(source,i));if(value.error){showError(value.error.message);return;}download('joinwitness-counterexample.json',value);};card.append(button);}
    $('evidence-list').append(card);
  }
  if(audit.witnesses_omitted)$('evidence-list').append(el('p',`另有 ${audit.witnesses_omitted} 条证据未展开，问题总数已完整计入。`,'empty'));
  $('comparison').replaceChildren();
  if(result.comparison){for(const [key,label,en,cls] of [['retained_pairs','保留的匹配','RETAINED',''],['lost_pairs','丢失的匹配','LOST','lost'],['gained_pairs','新增的匹配','GAINED','gained']]){const card=el('div','',`pair-stat ${cls}`);card.append(el('span',label),el('strong',result.comparison[key]),el('small',en));$('comparison').append(card);}}
  else $('comparison').append(el('p','此场景没有声明候选键。缺失记录可以定位，但不能替你猜测正确业务关联。','no-comparison'));
  $('materialize').disabled=!audit.safe;$('pairs').replaceChildren(el('p',audit.safe?'预检通过，可构造完整来源行对。':'当前计划未通过契约检查；构造前已拒绝，未生成部分结果。','empty'));
}
function showError(message){$('error').hidden=false;$('error').textContent=message;}
function load(raw){
  const value=JSON.parse(inspect(raw));source=raw;selected='plan';witnessFocus=null;
  if(value.error){result=null;showError(`输入校验未通过：${value.error.message}`);for(const id of ['output-count','missing-count','issue-count','safe-status'])$(id).textContent='—';for(const id of ['toggle-plan','materialize','export-report'])$(id).disabled=true;for(const id of ['left-head','right-head','left-body','right-body','evidence-list','pairs','comparison','plan-label'])$(id).replaceChildren();return;}
  request=JSON.parse(raw);result=value;$('error').hidden=true;$('export-report').disabled=false;render();
}
async function example(file){try{const r=await fetch(`data/${file}`);if(!r.ok)throw Error('示例无法加载');const s=await r.text();$('input').value=s;load(s);document.querySelectorAll('.scenario').forEach(b=>b.classList.toggle('active',b.dataset.file===file));}catch(e){showError(e.message);}}
for(const b of document.querySelectorAll('.scenario'))b.onclick=()=>example(b.dataset.file);
$('toggle-plan').onclick=()=>{if(!result?.comparison)return;selected=selected==='plan'?'candidate':'plan';witnessFocus=null;render();};
$('materialize').onclick=()=>{if(!result)return;const r=JSON.parse((selected==='candidate'?candidate_pairs:pairs)(source));if(r.error){showError(r.error.message);return;}$('pairs').replaceChildren();const table=document.createElement('table'),head=document.createElement('thead'),tr=document.createElement('tr');tr.append(el('th','LEFT ROW ID'),el('th','RIGHT ROW ID'));head.append(tr);table.append(head);const body=document.createElement('tbody');for(const p of r.pairs.slice(0,30)){const tr=document.createElement('tr');tr.append(el('td',p.left_id??'NULL'),el('td',p.right_id??'NULL'));body.append(tr);}table.append(body);$('pairs').append(table);if(r.pairs.length>30)$('pairs').append(el('p',`展示前 30 行，共 ${r.pairs.length} 行。`,'empty'));};
$('inspect').onclick=()=>{document.querySelectorAll('.scenario').forEach(b=>b.classList.remove('active'));load($('input').value);};
$('export-report').onclick=()=>{if(result)download('joinwitness-report.json',result);};
example('tenant-collision.json');
