import {EditorView,basicSetup} from 'codemirror';
import {sql,PostgreSQL} from '@codemirror/lang-sql';
const $=id=>document.getElementById(id);
const host=window.probe?'electron':'tauri';
const bridge=window.probe || {
 query:args=>window.__TAURI__.core.invoke('query',args),
 cancel:()=>window.__TAURI__.core.invoke('cancel'),
 record:metrics=>window.__TAURI__.core.invoke('record',{metrics}),
 ready:()=>window.__TAURI__.core.invoke('ready')
};
$('identity').textContent=`${host==='tauri'?'Tauri / WKWebView':'Electron / Chromium'} · same DuckDB worker · synthetic fixtures`;
const initial='SELECT * FROM dataset LIMIT 200;';
const aggregate='SELECT region, SUM(amount) AS revenue FROM dataset GROUP BY region ORDER BY region;';
const editor=new EditorView({doc:initial,extensions:[basicSetup,sql({dialect:PostgreSQL,schema:{dataset:['id','sale_date','region','amount']}})],parent:$('editor')});
let rows=[],columns=[],busy=false;
function doc(text){editor.dispatch({changes:{from:0,to:editor.state.doc.length,insert:text}});}
function cell(text){const d=document.createElement('div');d.className='cell';d.setAttribute('role','cell');d.textContent=text??'NULL';return d;}
function render(){const start=Math.max(0,Math.floor($('viewport').scrollTop/28)-2);const end=Math.min(rows.length,start+20);const frag=document.createDocumentFragment();for(let i=start;i<end;i++){const row=document.createElement('div');row.className='data-row';row.style.top=`${i*28}px`;row.setAttribute('role','row');row.setAttribute('aria-rowindex',i+2);for(const v of rows[i])row.append(cell(v));frag.append(row);}$('visible').replaceChildren(frag);}
function grid(data,cols){rows=data;columns=cols;$('gridHeader').replaceChildren(...cols.map(c=>cell(c.name)));$('spacer').style.height=`${rows.length*28}px`;$('viewport').scrollTop=0;$('grid').setAttribute('aria-rowcount',rows.length+1);$('rowCount').textContent=`${rows.length.toLocaleString()} displayed`;render();}
$('viewport').addEventListener('scroll',render);
function setBusy(value){busy=value;for(const id of ['run','stress','benchmark','format'])$(id).disabled=value;$('cancel').disabled=!value;}
async function run(statement=editor.state.doc.toString()){
 if(busy)return;setBusy(true);$('status').textContent='Running local query…';const start=performance.now();
 try{const result=await bridge.query({sql:statement,format:$('format').value});if(!result.ok)throw Error(result.error);grid(result.rows,result.columns);$('schema').textContent=`${result.dataset_rows.toLocaleString()} rows\n\n`+result.schema.map(c=>`${c.name}\n${c.type}`).join('\n\n');$('status').textContent=`${result.rows.length} result rows · ${(performance.now()-start).toFixed(1)} ms round trip · ${result.elapsed_ms.toFixed(1)} ms worker${result.truncated?' · truncated':''}`;return result;}
 catch(e){$('status').textContent=String(e.message||e);return null;}finally{setBusy(false);}
}
$('run').onclick=()=>run();$('cancel').onclick=()=>bridge.cancel();$('format').onchange=()=>run();
document.addEventListener('keydown',e=>{if(e.metaKey&&e.key==='Enter'){e.preventDefault();run();}});
function stress(){grid(Array.from({length:100000},(_,i)=>[String(i),i%3===0?'West':'East',String(i%100)]),[{name:'synthetic_id'},{name:'region'},{name:'amount'}]);$('status').textContent='100,000 synthetic UI rows — not a DuckDB result.';}
$('stress').onclick=stress;
const frame=()=>new Promise(requestAnimationFrame);
async function stream(){const deltas=[];let last=performance.now();$('streamText').textContent='';for(let i=0;i<120;i++){await frame();const now=performance.now();deltas.push(now-last);last=now;$('streamText').textContent+=`${i%5===0?'Checking evidence. ':'.'}`;}return deltas;}
$('stream').onclick=()=>stream();
function stats(xs){const a=[...xs].sort((a,b)=>a-b);return {runs_ms:xs.map(x=>+x.toFixed(2)),median_ms:+a[Math.floor(a.length/2)].toFixed(2),p95_ms:+a[Math.floor((a.length-1)*.95)].toFixed(2)};}
$('benchmark').onclick=async()=>{
 setBusy(true);const m={host,user_agent:navigator.userAgent,kind:'disposable framework probe',query:{}};
 try{
  for(const [name,statement] of [['preview',initial],['aggregate',aggregate]]){const times=[];for(let i=0;i<5;i++){const start=performance.now();const r=await bridge.query({sql:statement,format:'parquet'});if(!r.ok)throw Error(r.error);if(name==='aggregate'&&JSON.stringify(r.rows)!=='[["East","32999967"],["West","16500033"]]')throw Error('Wrong aggregate');grid(r.rows,r.columns);await frame();times.push(performance.now()-start);}m.query[name]=stats(times);}
  const denied=await bridge.query({sql:'DELETE FROM dataset',format:'parquet'});m.write_rejected=denied.ok===false;
  const cancelStart=performance.now();const promise=bridge.query({sql:'SELECT SUM(a.amount*b.amount) FROM dataset a CROSS JOIN dataset b',format:'parquet'});await new Promise(r=>setTimeout(r,150));await bridge.cancel();try{await promise;m.cancelled=false;}catch{m.cancelled=true;}m.cancel_total_ms=+(performance.now()-cancelStart).toFixed(2);
  const before=performance.now();stress();await frame();m.synthetic_grid_create_ms=+(performance.now()-before).toFixed(2);
  const scroll=[];for(let i=0;i<120;i++){const t=performance.now();$('viewport').scrollTop=i*1800;render();await frame();scroll.push(performance.now()-t);}m.synthetic_grid_scroll_frames=stats(scroll);m.live_dom_rows=$('visible').children.length;
  const editStart=performance.now();doc(('SELECT region, SUM(amount) FROM dataset GROUP BY region;\n').repeat(2000));await frame();m.editor_112k_chars_ms=+(performance.now()-editStart).toFixed(2);doc(aggregate);
  m.stream_frame_intervals=stats(await stream());await bridge.record(m);$('metrics').textContent=JSON.stringify(m,null,2);$('status').textContent='Comparison recorded locally. Details below.';
 }catch(e){m.error=String(e);$('metrics').textContent=JSON.stringify(m,null,2);await bridge.record(m);}finally{setBusy(false);await run(aggregate);}
};
run().then(async()=>{await frame();await frame();bridge.ready();});
