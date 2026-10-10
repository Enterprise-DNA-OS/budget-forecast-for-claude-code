#!/usr/bin/env node
// The one CLI for Budget and Forecast for Claude Code. Human tables by default, --json for machines.
// Every change needs --actor and is written to the activity table with before and after.
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { getDb, REPO_ROOT } from './lib/db.mjs';
import { parseCsv } from './lib/csv.mjs';
import { table } from './lib/format.mjs';
import { page, table as htmlTable, writeOut, esc } from './lib/render.mjs';

export const commands=['help','entities','accounts','versions','pnl','variance','commentary-due','outlook','compare','cash','covenants','headcount','close','tax-calendar','distributions','attention','compliance','activity','weekly-review','month-end',
 'add-entity','add-account','add-version','lock','set','roll-forecast','comment','add-hire','update-hire','add-covenant','task','done','lodge','distribution','certify','import','export',
 'draft-board-pack','draft-variance-requests','draft-lender-certificate'];
export const TYPES=['revenue','cogs','expense','other_income','other_expense','asset','liability','equity'];
const PL=`profit_sign(a.type)<>0`;

const today=()=>new Date().toISOString().slice(0,10);
function need(v,k){if(v===undefined||v===null||v===true||String(v).trim()==='')throw Error(`Required: --${k}`);return String(v).trim();}
function num(v,k,{min=null}={}){const n=Number(String(need(v,k)).replace(/,/g,''));if(!Number.isFinite(n))throw Error(`${k} must be a number`);if(min!==null&&n<min)throw Error(`${k} must be ${min} or more`);return n;}
function date(v,k){const s=need(v,k);if(!/^\d{4}-\d{2}-\d{2}$/.test(s)||new Date(s+'T00:00:00Z').toISOString().slice(0,10)!==s)throw Error(`${k} must be a real YYYY-MM-DD date`);return s;}
export function month(v,k){const s=need(v,k);if(!/^\d{4}-(0[1-9]|1[0-2])$/.test(s))throw Error(`${k} must be a month as YYYY-MM`);return s+'-01';}
function monthEnd(m){const d=new Date(m+'T00:00:00Z');d.setUTCMonth(d.getUTCMonth()+1);d.setUTCDate(0);return d.toISOString().slice(0,10);}
function oneOf(v,k,list){const s=need(v,k).toLowerCase();if(!list.includes(s))throw Error(`${k} must be one of: ${list.join(', ')}`);return s;}
function bool(v,k){if(!['true','false'].includes(String(v)))throw Error(`${k} must be true or false`);return String(v)==='true';}
const like=s=>`%${s.toLowerCase().replace(/[%_\\]/g,'\\$&')}%`;
const idLike=s=>/^[0-9a-f-]{4,}$/i.test(s)?s.toLowerCase()+'%':'no-id-match';

const MATCH={
 entity:{flag:'entity',label:r=>`${r.id} ${r.name}`,sql:`SELECT * FROM entities WHERE id::text LIKE $2 OR lower(name)=lower($1) OR lower(name) LIKE $3 OR lower(adaptive_level)=lower($1) ORDER BY name`,exact:r=>[r.name,r.adaptive_level]},
 account:{flag:'account',label:r=>`${r.code} ${r.name}`,sql:`SELECT * FROM accounts WHERE lower(code)=lower($1) OR id::text LIKE $2 OR lower(name)=lower($1) OR lower(name) LIKE $3 ORDER BY code`,exact:r=>[r.code,r.name]},
 version:{flag:'version',label:r=>`${r.name} (${r.kind})`,sql:`SELECT * FROM versions WHERE id::text LIKE $2 OR lower(name)=lower($1) OR lower(name) LIKE $3 ORDER BY name`,exact:r=>[r.name]},
 hire:{flag:'hire',label:r=>`${r.id} ${r.role} ${r.person||''}`,sql:`SELECT * FROM hires WHERE id::text LIKE $2 OR lower(role)=lower($1) OR lower(role) LIKE $3 OR lower(person)=lower($1) ORDER BY role`,exact:r=>[r.role,r.person]},
 distribution:{flag:'ref',label:r=>`${r.id} ${r.amount} due ${r.pay_on} (${r.status})`,sql:`SELECT * FROM distributions WHERE id::text LIKE $2 OR ($1::text IS NULL AND $3::text IS NULL) ORDER BY pay_on`,exact:()=>[]}
};
// An exact name or code wins over a partial one, so "Rent" never collides with "Rent recharges".
export async function match(db,kind,ref){
 const m=MATCH[kind];ref=need(ref,m.flag);
 const rows=await db.query(m.sql,[ref,idLike(ref),like(ref)]);
 const exact=rows.filter(r=>m.exact(r).some(x=>x&&String(x).toLowerCase()===ref.toLowerCase()));
 const hit=exact.length===1?exact:rows;
 if(hit.length!==1)throw Error(hit.length?`Ambiguous ${kind} "${ref}". Use the full name or an id:\n${hit.map(m.label).join('\n')}`:`No ${kind} matches "${ref}"`);
 return hit[0];
}
async function tx(db,fn,dry=false){await db.exec('BEGIN');try{const r=await fn();await db.exec(dry?'ROLLBACK':'COMMIT');return r;}catch(e){await db.exec('ROLLBACK');throw e;}}
async function audit(db,record,id,action,actor,before,after,evidence){await db.query('INSERT INTO activity(record,record_id,action,actor,before_data,after_data,evidence) VALUES($1,$2,$3,$4,$5,$6,$7)',[record,id,action,actor,before?JSON.stringify(before):null,after?JSON.stringify(after):null,evidence]);}
async function insert(db,t,row){const k=Object.keys(row);return (await db.query(`INSERT INTO ${t}(${k.join(',')}) VALUES(${k.map((_,i)=>'$'+(i+1)).join(',')}) RETURNING *`,Object.values(row)))[0];}
async function patch(db,t,id,row){const k=Object.keys(row);return (await db.query(`UPDATE ${t} SET ${k.map((x,i)=>`${x}=$${i+1}`).join(',')} WHERE id=$${k.length+1} RETURNING *`,[...Object.values(row),id]))[0];}
async function one(db,sql,p=[]){return (await db.query(sql,p))[0];}
async function rangeOf(db,v){if(v.kind!=='actuals')return {from:v.starts_on,to:(await one(db,'SELECT ends_on FROM v_versions WHERE id=$1',[v.id])).ends_on};
 const b=await one(db,'SELECT starts_on AS from,ends_on AS to FROM v_versions WHERE id=current_budget()');if(!b)throw Error('No budget to take the months from. Pass --month');return b;}
const entityFilter=(o,n,col='e.id')=>o.entity?` AND ${col}=$${n}`:'';
function withTotals(rows,valueKeys,label='Net profit'){
 const out=[];let cur=null,acc=null;const flush=()=>{if(acc)out.push(acc);};
 for(const r of rows){if(r.entity!==cur){flush();cur=r.entity;acc={...Object.fromEntries(Object.keys(r).map(k=>[k,''])),entity:r.entity,currency:r.currency,account:label};for(const k of valueKeys)acc[k]=0;}
  out.push(r);const sign=r.type==='revenue'||r.type==='other_income'?1:-1;for(const k of valueKeys)acc[k]+=k==='gap'||k==='variance'||k==='difference'?Number(r[k]):sign*Number(r[k]);}
 flush();for(const r of out)if(r.account===label)for(const k of valueKeys)r[k]=Math.round(r[k]*100)/100;return out;
}

const reads={
 entities:`SELECT e.name,e.country,e.currency,e.gst_period,e.adaptive_level,m.last_actual,e.active FROM entities e LEFT JOIN v_latest m ON m.entity_id=e.id ORDER BY e.name`,
 accounts:`SELECT code,name,type,tag,owner,adaptive_code,active FROM accounts ORDER BY code`,
 versions:`SELECT name,kind,to_char(starts_on,'YYYY-MM') AS starts,to_char(ends_on,'YYYY-MM') AS ends,locked,approved_by,approved_on,line_count,(id=current_budget()) AS current_budget,(id=current_forecast()) AS current_forecast FROM v_versions ORDER BY array_position(ARRAY['actuals','budget','forecast','scenario'],kind),starts_on,created_at`,
 'commentary-due':`SELECT entity,currency,month,code,account,owner,actual,budget,variance,pct FROM v_commentary_due ORDER BY entity,abs(variance) DESC`,
 covenants:`SELECT entity,lender,metric,test,threshold,frequency,last_tested,last_value,last_passed,first_forecast_breach,breach_value FROM v_covenants ORDER BY entity,lender,metric`,
 headcount:`SELECT entity,currency,role,person,department,status,starts_on,ends_on,annual_salary,oncost_rate,monthly_cost,cost_in_forecast FROM v_headcount WHERE status<>'cancelled' ORDER BY entity,starts_on`,
 close:`SELECT c.entity,c.month,c.task,c.owner,c.due_on,c.done_on,c.state FROM v_close c WHERE c.period=(SELECT max(period) FROM close_tasks t WHERE t.entity_id=c.entity_id) ORDER BY c.entity,array_position(ARRAY['overdue','open','done'],c.state),c.due_on`,
 'tax-calendar':`SELECT entity,return_type,period_end,due_on,lodged_on,reference,state FROM v_tax_calendar WHERE state<>'lodged' OR due_on>=current_date-60 ORDER BY due_on,entity`,
 distributions:`SELECT entity,currency,amount,status,declared_on,pay_on,solvency_certificate_on,approved_by,in_forecast,net_assets_before,lowest_cash_after FROM v_distributions ORDER BY pay_on`,
 attention:`SELECT item,issue,detail FROM v_attention ORDER BY issue,item`,
 compliance:`SELECT rule,item,finding FROM v_compliance ORDER BY rule,item`,
 activity:`SELECT created_at,record,action,actor,evidence FROM activity ORDER BY created_at DESC,id DESC LIMIT 100`
};

// ---------------------------------------------------------------- imports
// Adaptive Planning, Integration > Export Data, format "Adaptive Account Names and Codes": one row per
// account and level, one column per month (doc.workday.com, "Export Data"). Rollup columns are skipped.
const MONTHS=['jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec'];
export function periodHeader(h){
 const s=String(h).trim();let m;
 if((m=s.match(/^(\d{1,2})\/(\d{4})$/))&&+m[1]>=1&&+m[1]<=12)return `${m[2]}-${m[1].padStart(2,'0')}-01`;
 if((m=s.match(/^([A-Za-z]{3})[a-z]*[- ](\d{2}|\d{4})$/))&&MONTHS.includes(m[1].toLowerCase()))return `${m[2].length===2?'20'+m[2]:m[2]}-${String(MONTHS.indexOf(m[1].toLowerCase())+1).padStart(2,'0')}-01`;
 if((m=s.match(/^(\d{4})-(\d{2})$/))&&+m[2]>=1&&+m[2]<=12)return `${m[1]}-${m[2]}-01`;
 return null;
}
export function amount(v,where){let s=String(v??'').trim();if(!s||s==='-')return null;const neg=/^\(.*\)$/.test(s);s=s.replace(/[(),$\s]|NZD|AUD/gi,'');const n=Number(s);if(!Number.isFinite(n))throw Error(`${where}: "${v}" is not a number`);return neg?-n:n;}
function readMap(o){return o.map?JSON.parse(fs.readFileSync(path.resolve(o.map),'utf8')):{};}
function col(row,map,name,...alts){const want=[map.columns?.[name],name,...alts].filter(Boolean);for(const w of want){const k=Object.keys(row).find(h=>h.trim().toLowerCase()===w.toLowerCase());if(k!==undefined)return row[k];}return undefined;}
async function resolver(db,map){
 const ents=await db.query('SELECT * FROM entities');const accs=await db.query('SELECT * FROM accounts');
 const lc=s=>String(s||'').trim().toLowerCase();
 return {
  entity(level){const t=map.levels?.[level]??level;return ents.find(e=>lc(e.adaptive_level)===lc(t)||lc(e.name)===lc(t));},
  account(code,name){for(const k of [code,name].filter(Boolean)){const t=map.accounts?.[k];if(t){const a=accs.find(x=>lc(x.code)===lc(t));if(a)return a;}}
   return accs.find(a=>code&&(lc(a.adaptive_code)===lc(code)||lc(a.code)===lc(code)))||accs.find(a=>name&&lc(a.name)===lc(name));}
 };
}
async function writeValues(db,{version,values,o,actor,filename,input,kind}){
 if(version.locked)throw Error(`Version "${version.name}" is locked (approved by ${version.approved_by} on ${version.approved_on}). Import into a new version`);
 const r=await rangeOf(db,version).catch(()=>null);
 if(version.kind!=='actuals'){const out=values.filter(v=>v.period<r.from||v.period>r.to);if(out.length)throw Error(`${out.length} value(s) fall outside "${version.name}" (${r.from.slice(0,7)} to ${r.to.slice(0,7)}), first ${out[0].period.slice(0,7)}`);}
 const seen=new Set();for(const v of values){const k=`${v.entity.id}|${v.account.id}|${v.period}`;if(seen.has(k))throw Error(`${v.where}: ${v.entity.name} ${v.account.code} ${v.period.slice(0,7)} appears twice in the file`);seen.add(k);}
 let inserted=0,updated=0,unchanged=0;
 return tx(db,async()=>{
  const changed=[];
  for(const v of values){
   const old=await one(db,'SELECT * FROM lines WHERE version_id=$1 AND entity_id=$2 AND account_id=$3 AND period=$4',[version.id,v.entity.id,v.account.id,v.period]);
   if(old&&Number(old.amount)===v.amount){unchanged++;continue;}
   if(old&&!o.update){changed.push(`${v.entity.name} ${v.account.code} ${v.period.slice(0,7)}: ${old.amount} on file, ${v.amount} in the file`);continue;}
   const rec=old?await patch(db,'lines',old.id,{amount:v.amount,source:JSON.stringify(v.source)}):await insert(db,'lines',{version_id:version.id,entity_id:v.entity.id,account_id:v.account.id,period:v.period,amount:v.amount,source:JSON.stringify(v.source)});
   old?updated++:inserted++;await audit(db,'lines',rec.id,`import ${kind}`,actor,old,rec,path.basename(filename));
  }
  if(changed.length)throw Error(`${changed.length} value(s) differ from what is already on file. Review them, then re-run with --update:\n${changed.slice(0,10).join('\n')}`);
  await db.query('INSERT INTO imports(filename,sha256,kind,row_count,actor) VALUES($1,$2,$3,$4,$5)',[path.basename(filename),createHash('sha256').update(input).digest('hex'),kind,values.length,actor]);
  return {version:version.name,values:values.length,inserted,updated,unchanged,dry_run:Boolean(o['dry-run'])};
 },Boolean(o['dry-run']));
}
async function importAdaptive(db,o,actor){
 const version=await match(db,'version',o.version);const filename=path.resolve(need(o.file,'file'));const input=fs.readFileSync(filename,'utf8');
 const rows=parseCsv(input);if(!rows.length)throw Error('No data rows');const map=readMap(o);const R=await resolver(db,map);
 const headers=Object.keys(rows[0]);const periods=headers.map(h=>[h,periodHeader(h)]).filter(([,p])=>p);
 if(col(rows[0],map,'Account Code','Account')===undefined&&col(rows[0],map,'Account Name')===undefined)throw Error(`No "Account Code" or "Account Name" column. Is this an Adaptive Planning Export Data file? Columns found: ${headers.join(', ')}`);
 if(col(rows[0],map,'Level Name','Level')===undefined)throw Error(`No "Level Name" column. Columns found: ${headers.join(', ')}`);
 if(!periods.length)throw Error(`No month columns found (expected headers like Apr-2026, 04/2026 or 2026-04). Columns found: ${headers.join(', ')}`);
 const values=[],missAcc=new Set(),missLvl=new Set();
 rows.forEach((row,i)=>{const line=i+2;const code=col(row,map,'Account Code','Account'),name=col(row,map,'Account Name'),level=col(row,map,'Level Name','Level');
  const account=R.account(code,name),entity=R.entity(level);
  if(!account)missAcc.add(`${code||''} ${name||''}`.trim());if(!entity)missLvl.add(level);if(!account||!entity)return;
  for(const [h,p] of periods){const a=amount(row[h],`Row ${line}, ${h}`);if(a===null)continue;values.push({entity,account,period:p,amount:a,where:`Row ${line}`,source:{file:path.basename(filename),row:line,column:h,level,account_code:code||null,account_name:name||null}});}
 });
 if(missAcc.size||missLvl.size)throw Error(`Nothing imported. Add these to the map file (docs/replace-adaptive-planning.md):${missAcc.size?`\naccounts with no match: ${[...missAcc].join('; ')}`:''}${missLvl.size?`\nlevels with no match: ${[...missLvl].join('; ')}`:''}`);
 return writeValues(db,{version,values,o,actor,filename,input,kind:'adaptive'});
}
// Monthly totals from the accounting system (Xero, MYOB, any general ledger): Entity, Account Code, Month, Amount.
async function importLedger(db,o,actor){
 const version=await match(db,'version',o.version||'Actuals');const filename=path.resolve(need(o.file,'file'));const input=fs.readFileSync(filename,'utf8');
 const rows=parseCsv(input);if(!rows.length)throw Error('No data rows');const map=readMap(o);const R=await resolver(db,map);
 const values=[],miss=new Set();
 rows.forEach((row,i)=>{const line=i+2;const ent=col(row,map,'Entity'),code=col(row,map,'Account Code','Code'),m=col(row,map,'Month','Period');
  if(m===undefined||code===undefined||ent===undefined)throw Error(`Row ${line}: needs Entity, Account Code, Month and Amount columns. Columns found: ${Object.keys(row).join(', ')}`);
  const entity=R.entity(ent),account=R.account(code,null);if(!entity)miss.add(`entity ${ent}`);if(!account)miss.add(`account ${code}`);if(!entity||!account)return;
  const p=periodHeader(m);if(!p)throw Error(`Row ${line}: month "${m}" is not a month (use YYYY-MM)`);const a=amount(col(row,map,'Amount'),`Row ${line}`);if(a===null)return;
  values.push({entity,account,period:p,amount:a,where:`Row ${line}`,source:{file:path.basename(filename),row:line}});});
 if(miss.size)throw Error(`Nothing imported. No match for: ${[...miss].join('; ')}`);
 return writeValues(db,{version,values,o,actor,filename,input,kind:'ledger'});
}

// ---------------------------------------------------------------- drafts
const slug=s=>String(s).toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/(^-|-$)/g,'');
function draftFile(name,html){return writeOut('drafts',`${name}-${Date.now()}`,html);}
const forEntity=(rows,e)=>rows.filter(r=>r.entity===e.name||String(r.item||'').includes(e.name));

export async function run(db,cmd,o={},args=[]){
 if(!commands.includes(cmd))throw Error(`Unknown command "${cmd}". Run help for the list`);
 if(cmd==='help')return commands.map(command=>({command}));
 if(reads[cmd])return db.query(reads[cmd]);
 if(cmd==='pnl'){const v=o.version?await match(db,'version',o.version):await one(db,'SELECT * FROM versions WHERE id=current_budget()');if(!v)throw Error('No version. Pass --version');
  const r=o.month?{from:month(o.month,'month'),to:month(o.month,'month')}:await rangeOf(db,v);const e=o.entity?await match(db,'entity',o.entity):null;
  const rows=await db.query(`SELECT e.name AS entity,e.currency,a.code,a.name AS account,a.type,sum(l.amount) AS total FROM lines l JOIN entities e ON e.id=l.entity_id JOIN accounts a ON a.id=l.account_id
   WHERE l.version_id=$1 AND l.period BETWEEN $2 AND $3 AND ${PL}${entityFilter(o,4)} GROUP BY e.name,e.currency,a.code,a.name,a.type ORDER BY e.name,a.code`,[v.id,r.from,r.to,...(e?[e.id]:[])]);
  return withTotals(rows,['total']);}
 if(cmd==='variance'){const e=o.entity?await match(db,'entity',o.entity):null;
  return db.query(`SELECT entity,currency,month,code,account,actual,budget,variance,pct,explained FROM v_variance WHERE true${e?' AND entity_id=$1':''} ORDER BY entity,code`,e?[e.id]:[]);}
 if(cmd==='outlook'){const e=o.entity?await match(db,'entity',o.entity):null;
  const rows=await db.query(`SELECT entity,currency,code,account,type,actual_to_date,forecast_rest,outlook,budget,gap FROM v_outlook WHERE true${e?' AND entity_id=$1':''} ORDER BY entity,code`,e?[e.id]:[]);
  return withTotals(rows,['actual_to_date','forecast_rest','outlook','budget','gap']).map(({type,...r})=>r);}
 if(cmd==='compare'){const a=await match(db,'version',o.a),b=await match(db,'version',o.b);if(a.id===b.id)throw Error('Pick two different versions');
  const ra=a.kind==='actuals'?null:await rangeOf(db,a),rb=b.kind==='actuals'?null:await rangeOf(db,b);if(!ra&&!rb)throw Error('Compare a plan with actuals, or two plans');
  const from=[ra?.from,rb?.from].filter(Boolean).sort().pop(),to=[ra?.to,rb?.to].filter(Boolean).sort()[0];if(from>to)throw Error(`${a.name} and ${b.name} share no months`);
  const e=o.entity?await match(db,'entity',o.entity):null;
  const rows=await db.query(`SELECT e.name AS entity,e.currency,a.code,a.name AS account,a.type,coalesce(sum(l.amount) FILTER (WHERE l.version_id=$1),0) AS a_total,coalesce(sum(l.amount) FILTER (WHERE l.version_id=$2),0) AS b_total,
   profit_sign(a.type)*(coalesce(sum(l.amount) FILTER (WHERE l.version_id=$2),0)-coalesce(sum(l.amount) FILTER (WHERE l.version_id=$1),0)) AS difference
   FROM lines l JOIN entities e ON e.id=l.entity_id JOIN accounts a ON a.id=l.account_id WHERE l.version_id IN ($1,$2) AND l.period BETWEEN $3 AND $4 AND ${PL}${entityFilter(o,5)}
   GROUP BY e.name,e.currency,a.code,a.name,a.type ORDER BY e.name,a.code`,[a.id,b.id,from,to,...(e?[e.id]:[])]);
  return withTotals(rows,['a_total','b_total','difference']).map(r=>({entity:r.entity,currency:r.currency,code:r.code,account:r.account,[a.name]:r.a_total,[b.name]:r.b_total,difference:r.difference}));}
 if(cmd==='cash'){const e=o.entity?await match(db,'entity',o.entity):null;
  return db.query(`SELECT c.entity,c.currency,c.month,c.basis,c.closing_cash,c.closing_cash-lag(c.closing_cash) OVER (PARTITION BY c.entity_id ORDER BY c.period) AS change
   FROM v_cash c JOIN v_latest m ON m.entity_id=c.entity_id WHERE c.period>=m.last_actual-interval '2 months'${e?' AND c.entity_id=$1':''} ORDER BY c.entity,c.period`,e?[e.id]:[]);}
 if(cmd==='weekly-review')return {attention:await run(db,'attention'),cash:(await run(db,'cash')).filter(r=>r.basis==='forecast').slice(0,12),covenants:await run(db,'covenants'),tax_calendar:(await run(db,'tax-calendar')).filter(r=>r.state!=='lodged')};
 if(cmd==='month-end')return {to_explain:await run(db,'commentary-due'),close:await run(db,'close'),outlook:(await run(db,'outlook')).filter(r=>r.account==='Net profit'),forecast_not_rolled:await db.query('SELECT entity,months FROM v_unrolled ORDER BY entity')};
 if(cmd==='export'){
  const dir=path.resolve(o.out||path.join(REPO_ROOT,'exports',new Date().toISOString().replace(/[:.]/g,'-')));fs.mkdirSync(dir,{recursive:true});const out=[];
  for(const t of ['entities','accounts','versions','lines','hires','statutory_rates','covenants','commentary','close_tasks','lodgements','distributions','settings','activity','imports']){const file=path.join(dir,t+'.json');if(fs.existsSync(file))throw Error(`Export already exists: ${file}`);const rows=await db.query(`SELECT * FROM ${t} ORDER BY 1`);fs.writeFileSync(file,JSON.stringify(rows,null,2)+'\n');out.push({records:t,count:rows.length,file});}
  return out;}
 if(cmd==='draft-board-pack'){const e=await match(db,'entity',o.entity);const pick=async c=>forEntity(await run(db,c),e);
  const outlook=await pick('outlook'),np=outlook.find(r=>r.account==='Net profit');const v=await db.query('SELECT entity,month,code,account,actual,budget,variance,pct,explained FROM v_variance WHERE entity_id=$1 ORDER BY abs(variance) DESC LIMIT 10',[e.id]);
  const notes=await db.query(`SELECT a.code,a.name AS account,c.note,c.actor FROM commentary c JOIN accounts a ON a.id=c.account_id JOIN v_latest m ON m.entity_id=c.entity_id AND c.period=m.last_actual WHERE c.entity_id=$1 ORDER BY a.code`,[e.id]);
  const file=draftFile(`board-pack-${slug(e.name)}`,page({title:`Board pack: ${e.name}`,subtitle:'DRAFT for the finance lead to check. Nothing has been sent.',sections:[
   {title:'The year',note:np?`Net profit outlook ${np.outlook} ${e.currency} against a budget of ${np.budget} (${np.gap>=0?'ahead':'behind'} by ${Math.abs(np.gap)}).`:'No budget on file.',html:htmlTable(outlook)},
   {title:'Last month against budget: largest variances',html:htmlTable(v)},{title:'What the budget holders said',html:htmlTable(notes)},
   {title:'Cash',html:htmlTable(await pick('cash'))},{title:'Bank covenants',html:htmlTable(await pick('covenants'))},
   {title:'People',html:htmlTable(await pick('headcount'))},{title:'Record checks',html:htmlTable(await pick('compliance'))}]}));
  return {file,entity:e.name};}
 if(cmd==='draft-variance-requests'){const e=o.entity?await match(db,'entity',o.entity):null;
  const rows=(await db.query('SELECT d.*,a.owner_email FROM v_commentary_due d JOIN accounts a ON a.id=d.account_id ORDER BY d.owner,d.entity,d.code')).filter(r=>!e||r.entity_id===e.id);
  if(!rows.length)throw Error('Every variance over the threshold already has a comment');
  const by={};for(const r of rows)(by[r.owner_email||r.owner||'(no budget holder)']||=[]).push(r);const files=[];
  for(const [to,list] of Object.entries(by)){const name=list[0].owner?.split(' ')[0]||'there';
   const body=`To: ${list[0].owner_email||'(no email on file: set the budget holder on the account)'}\nSubject: ${list[0].month} variances to explain\n\nHi ${name},\n\nThese lines came in well away from budget in ${list[0].month}. Could you send me a line on each by the end of the week?\n\n${list.map(r=>`- ${r.entity}, ${r.code} ${r.account}: actual ${r.actual} against budget ${r.budget} ${r.currency} (${r.variance}, ${r.pct??'no budget'}%)`).join('\n')}\n\nThanks.\n\nDRAFT. Not sent. Edit before sending.\n`;
   const file=path.join(path.resolve(process.env.OUTPUT_DIR||REPO_ROOT,'drafts'),`variance-request-${slug(to)}-${Date.now()}.txt`);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,body);files.push({file,to:list[0].owner_email||null,lines:list.length});}
  return files;}
 if(cmd==='draft-lender-certificate'){const e=await match(db,'entity',o.entity);
  const tests=await db.query(`SELECT DISTINCT ON (t.covenant_id) t.lender,t.metric,t.test,t.threshold,t.month AS tested,t.value,t.passes FROM v_covenant_tests t WHERE t.entity_id=$1 AND t.basis='actual'${o.lender?' AND lower(t.lender)=lower($2)':''} ORDER BY t.covenant_id,t.period DESC`,[e.id,...(o.lender?[o.lender]:[])]);
  if(!tests.length)throw Error(`No covenant tests on actuals for ${e.name}`);
  const file=draftFile(`lender-certificate-${slug(e.name)}`,page({title:`Compliance certificate: ${e.name}`,subtitle:'DRAFT. Check every figure against the facility agreement definitions before a director signs. Nothing has been sent.',sections:[
   {title:'Covenant tests',html:htmlTable(tests)},
   {title:'Statement',html:`<p>We confirm that, as at the test dates above, ${esc(e.name)} ${tests.every(t=>t.passes)?'complied with':'did not comply with'} the financial covenants listed. Figures are from the management accounts.</p><p>Signed: ____________________ Director&nbsp;&nbsp;&nbsp;Date: __________</p>`}]}));
  return {file,entity:e.name,tests:tests.length,all_pass:tests.every(t=>t.passes)};}

 const actor=need(o.actor,'actor');
 if(cmd==='import'){if(args[0]==='adaptive')return importAdaptive(db,o,actor);if(args[0]==='ledger')return importLedger(db,o,actor);throw Error('Import supports: import adaptive --version=... --file=... | import ledger --file=...');}
 return tx(db,async()=>{
  if(cmd==='add-entity'){const country=need(o.country,'country').toUpperCase();if(!['NZ','AU'].includes(country))throw Error('country must be NZ or AU');
   const row={name:need(o.name,'name'),country,currency:o.currency?need(o.currency,'currency').toUpperCase():country==='NZ'?'NZD':'AUD',gst_period:o['gst-period']?oneOf(o['gst-period'],'gst-period',['monthly','two-monthly','quarterly','none']):country==='NZ'?'two-monthly':'quarterly'};
   if(!/^[A-Z]{3}$/.test(row.currency))throw Error('currency must be a three-letter code');if(o['tax-from'])row.tax_from=month(o['tax-from'],'tax-from');if(o['adaptive-level'])row.adaptive_level=need(o['adaptive-level'],'adaptive-level');
   if(row.gst_period==='two-monthly'&&country!=='NZ'||row.gst_period==='quarterly'&&country!=='AU')throw Error(`${row.gst_period} GST periods are not set up for ${country}`);
   const r=await insert(db,'entities',row);await audit(db,'entities',r.id,cmd,actor,null,r,'manual entry');return r;}
  if(cmd==='add-account'){const row={code:need(o.code,'code'),name:need(o.name,'name'),type:oneOf(o.type,'type',TYPES)};
   if(o.tag)row.tag=oneOf(o.tag,'tag',['cash','debt','interest','depreciation','tax','wages']);for(const k of ['owner','owner-email','adaptive-code'])if(o[k]!==undefined)row[k.replace(/-/g,'_')]=need(o[k],k);
   const r=await insert(db,'accounts',row);await audit(db,'accounts',r.id,cmd,actor,null,r,'manual entry');return r;}
  if(cmd==='add-version'){const row={name:need(o.name,'name'),kind:oneOf(o.kind,'kind',['budget','forecast','scenario']),starts_on:month(o.starts,'starts'),months:o.months?num(o.months,'months',{min:1}):12};
   if(!Number.isInteger(row.months)||row.months>60)throw Error('months must be a whole number from 1 to 60');if(o.notes)row.notes=need(o.notes,'notes');
   let src=null;if(o['copy-from']){src=await match(db,'version',o['copy-from']);row.based_on=src.id;}
   const r=await insert(db,'versions',row);let copied=0;
   if(src){const shift=o.shift?num(o.shift,'shift'):0,up=o.uplift?num(o.uplift,'uplift'):0;if(!Number.isInteger(shift))throw Error('shift must be a whole number of months');
    const only=o['uplift-only']?oneOf(o['uplift-only'],'uplift-only',['revenue','costs']):null;const types=only==='revenue'?['revenue','other_income']:only==='costs'?['cogs','expense','other_expense']:['revenue','other_income','cogs','expense','other_expense'];
    copied=(await db.query(`INSERT INTO lines(version_id,entity_id,account_id,period,amount,source) SELECT $1,l.entity_id,l.account_id,(l.period+$3*interval '1 month')::date,
      CASE WHEN a.type=ANY($5::text[]) THEN round(l.amount*(1+$4::numeric/100),2) ELSE l.amount END,jsonb_build_object('copied_from',$6::text,'shift_months',$3::int,'uplift_pct',$4::numeric)
      FROM lines l JOIN accounts a ON a.id=l.account_id WHERE l.version_id=$2 AND (l.period+$3*interval '1 month')::date BETWEEN $7::date AND ($7::date+($8::int-1)*interval '1 month')::date RETURNING id`,[r.id,src.id,shift,up,types,src.name,row.starts_on,row.months])).length;
    if(!copied)throw Error(`Nothing in "${src.name}" falls inside the new months. Check --starts and --shift`);}
   await audit(db,'versions',r.id,cmd,actor,null,{...r,copied_lines:copied},src?`copied from ${src.name}`:'manual entry');return {...r,copied_lines:copied};}
  if(cmd==='lock'){const v=await match(db,'version',o.version);if(v.kind==='actuals')throw Error('Actuals are never locked; close a month by loading it');if(v.locked)throw Error(`${v.name} is already locked`);
   const r=await patch(db,'versions',v.id,{locked:true,approved_by:need(o['approved-by'],'approved-by'),approved_on:o.date?date(o.date,'date'):today()});await audit(db,'versions',v.id,cmd,actor,v,r,need(o.evidence,'evidence'));return r;}
  if(cmd==='set'){const v=await match(db,'version',o.version),e=await match(db,'entity',o.entity),a=await match(db,'account',o.account),p=month(o.month,'month'),amt=num(o.amount,'amount');
   const old=await one(db,'SELECT * FROM lines WHERE version_id=$1 AND entity_id=$2 AND account_id=$3 AND period=$4',[v.id,e.id,a.id,p]);
   if(old&&Number(old.amount)===amt)throw Error(`${a.code} ${p.slice(0,7)} is already ${amt}`);
   const r=old?await patch(db,'lines',old.id,{amount:amt}):await insert(db,'lines',{version_id:v.id,entity_id:e.id,account_id:a.id,period:p,amount:amt});
   await audit(db,'lines',r.id,cmd,actor,old,r,need(o.evidence,'evidence'));return {version:v.name,entity:e.name,account:`${a.code} ${a.name}`,month:p.slice(0,7),before:old?.amount??null,amount:r.amount};}
  if(cmd==='roll-forecast'){const src=o.from?await match(db,'version',o.from):await one(db,'SELECT * FROM versions WHERE id=current_forecast()');if(!src)throw Error('No forecast to roll. Pass --from');
   if(src.kind==='actuals')throw Error('Roll from a forecast, budget or scenario');const r=await insert(db,'versions',{name:need(o.name,'name'),kind:'forecast',starts_on:src.starts_on,months:src.months,based_on:src.id,notes:`Rolled from ${src.name}`});
   await db.query('INSERT INTO lines(version_id,entity_id,account_id,period,amount,source) SELECT $1,entity_id,account_id,period,amount,jsonb_build_object(\'copied_from\',$3::text) FROM lines WHERE version_id=$2',[r.id,src.id,src.name]);
   const through=o.through?month(o.through,'through'):null;const out=[];
   for(const e of await db.query('SELECT e.id,e.name,m.last_actual FROM entities e JOIN v_latest m ON m.entity_id=e.id WHERE e.active ORDER BY e.name')){
    const upto=through||e.last_actual;if(!upto)continue;
    await db.query('DELETE FROM lines WHERE version_id=$1 AND entity_id=$2 AND period<=$3',[r.id,e.id,upto]);
    const n=(await db.query(`INSERT INTO lines(version_id,entity_id,account_id,period,amount,source) SELECT $1,entity_id,account_id,period,amount,'{"from":"actuals"}' FROM lines
     WHERE version_id=actuals_id() AND entity_id=$2 AND period BETWEEN $3 AND $4 RETURNING period`,[r.id,e.id,src.starts_on,upto])).length;
    out.push({entity:e.name,actuals_through:upto.slice(0,7),actual_lines:n});}
   await audit(db,'versions',r.id,cmd,actor,null,r,`rolled from ${src.name}`);return {version:r.name,from:src.name,entities:out};}
  if(cmd==='comment'){const e=await match(db,'entity',o.entity),a=await match(db,'account',o.account);
   const p=o.month?month(o.month,'month'):(await one(db,'SELECT last_actual FROM v_latest WHERE entity_id=$1',[e.id])).last_actual;if(!p)throw Error(`No actuals for ${e.name}; pass --month`);
   const r=await insert(db,'commentary',{entity_id:e.id,account_id:a.id,period:p,note:need(o.note,'note'),actor});await audit(db,'commentary',r.id,cmd,actor,null,r,r.note);return r;}
  if(cmd==='add-hire'){const e=await match(db,'entity',o.entity);const row={entity_id:e.id,role:need(o.role,'role'),starts_on:date(o.starts,'starts'),annual_salary:num(o.salary,'salary',{min:1})};
   for(const k of ['person','department','notes'])if(o[k]!==undefined)row[k]=need(o[k],k);if(o.ends)row.ends_on=date(o.ends,'ends');if(o.status)row.status=oneOf(o.status,'status',['planned','filled']);
   if(o.oncost!==undefined)row.oncost_rate=num(o.oncost,'oncost',{min:0});else{const s=await one(db,'SELECT rate FROM statutory_rates WHERE country=$1 AND from_date<=$2 ORDER BY from_date DESC LIMIT 1',[e.country,row.starts_on]);if(!s)throw Error('No statutory rate on file for that date; pass --oncost');row.oncost_rate=s.rate;}
   const r=await insert(db,'hires',row);await audit(db,'hires',r.id,cmd,actor,null,r,'hiring plan');return r;}
  if(cmd==='update-hire'){const h=await match(db,'hire',o.hire);const row={};
   if(o.status)row.status=oneOf(o.status,'status',['planned','filled','cancelled']);for(const k of ['person','department','notes'])if(o[k]!==undefined)row[k]=o[k]==='null'?null:need(o[k],k);
   for(const k of ['starts','ends','reduced-rate-until'])if(o[k]!==undefined)row[{starts:'starts_on',ends:'ends_on','reduced-rate-until':'reduced_rate_until'}[k]]=o[k]==='null'?null:date(o[k],k);
   if(o.salary!==undefined)row.annual_salary=num(o.salary,'salary',{min:1});if(o.oncost!==undefined)row.oncost_rate=num(o.oncost,'oncost',{min:0});
   if(!Object.keys(row).length)throw Error('No fields to change');const r=await patch(db,'hires',h.id,row);await audit(db,'hires',h.id,cmd,actor,h,r,need(o.evidence,'evidence'));return r;}
  if(cmd==='add-covenant'){const e=await match(db,'entity',o.entity);const metric=oneOf(o.metric,'metric',['minimum cash','interest cover','debt to ebitda']);
   const r=await insert(db,'covenants',{entity_id:e.id,lender:need(o.lender,'lender'),metric,test:metric==='debt to ebitda'?'<=':'>=',threshold:num(o.threshold,'threshold'),frequency:o.frequency?oneOf(o.frequency,'frequency',['monthly','quarterly']):'quarterly',evidence:need(o.evidence,'evidence')});
   await audit(db,'covenants',r.id,cmd,actor,null,r,r.evidence);return r;}
  if(cmd==='task'){const e=await match(db,'entity',o.entity);const p=o.month?month(o.month,'month'):(await one(db,'SELECT last_actual FROM v_latest WHERE entity_id=$1',[e.id])).last_actual;if(!p)throw Error('Pass --month');
   const r=await insert(db,'close_tasks',{entity_id:e.id,period:p,task:need(o.task,'task'),owner:o.owner?need(o.owner,'owner'):null,due_on:date(o.due,'due')});await audit(db,'close_tasks',r.id,cmd,actor,null,r,'close checklist');return r;}
  if(cmd==='done'){const ref=need(o.task,'task');const e=o.entity?await match(db,'entity',o.entity):null;
   const rows=await db.query(`SELECT t.*,en.name AS entity FROM close_tasks t JOIN entities en ON en.id=t.entity_id WHERE t.done_on IS NULL AND (t.id::text LIKE $1 OR lower(t.task)=lower($2) OR lower(t.task) LIKE $3)${e?' AND t.entity_id=$4':''} ORDER BY t.due_on`,[idLike(ref),ref,like(ref),...(e?[e.id]:[])]);
   if(rows.length!==1)throw Error(rows.length?`More than one open task matches "${ref}". Add --entity or use an id:\n${rows.map(t=>`${t.id} ${t.entity}: ${t.task}`).join('\n')}`:`No open close task matches "${ref}"`);
   const t=rows[0];delete t.entity;const r=await patch(db,'close_tasks',t.id,{done_on:o.date?date(o.date,'date'):today(),evidence:need(o.evidence,'evidence')});await audit(db,'close_tasks',t.id,cmd,actor,t,r,r.evidence);return r;}
  if(cmd==='lodge'){const e=await match(db,'entity',o.entity);const end=o['period-end']?date(o['period-end'],'period-end'):monthEnd(month(o.month,'month'));
   const cal=await one(db,'SELECT * FROM v_tax_calendar WHERE entity_id=$1 AND period_end=$2',[e.id,end]);if(!cal)throw Error(`${end} is not a ${e.country==='NZ'?'GST':'BAS'} period end for ${e.name} (${e.gst_period}, tracked from ${e.tax_from})`);
   if(cal.lodged_on)throw Error(`Already recorded as lodged on ${cal.lodged_on}`);const lodged=o.lodged?date(o.lodged,'lodged'):today();if(lodged>today())throw Error('lodged cannot be in the future');
   const r=await insert(db,'lodgements',{entity_id:e.id,period_end:end,lodged_on:lodged,reference:o.reference?need(o.reference,'reference'):null,evidence:need(o.evidence,'evidence')});await audit(db,'lodgements',r.id,cmd,actor,null,r,r.evidence);return r;}
  if(cmd==='distribution'){
   if(o.ref){const d=await match(db,'distribution',o.ref);const row={};if(o.status)row.status=oneOf(o.status,'status',['proposed','declared','paid','cancelled']);if(o.declared)row.declared_on=date(o.declared,'declared');
    if(o['pay-on'])row.pay_on=date(o['pay-on'],'pay-on');if(o['approved-by'])row.approved_by=need(o['approved-by'],'approved-by');if(o['in-forecast']!==undefined)row.in_forecast=bool(o['in-forecast'],'in-forecast');
    if(['declared','paid'].includes(row.status)&&!row.declared_on&&!d.declared_on)throw Error('A declared or paid distribution needs --declared=YYYY-MM-DD');
    if(!Object.keys(row).length)throw Error('No fields to change');const r=await patch(db,'distributions',d.id,row);await audit(db,'distributions',d.id,cmd,actor,d,r,need(o.evidence,'evidence'));return r;}
   const e=await match(db,'entity',o.entity);const row={entity_id:e.id,amount:num(o.amount,'amount',{min:0.01}),pay_on:date(o['pay-on'],'pay-on'),status:o.status?oneOf(o.status,'status',['proposed','declared','paid']):'proposed',evidence:need(o.evidence,'evidence')};
   if(o.declared)row.declared_on=date(o.declared,'declared');if(row.status!=='proposed'&&!row.declared_on)throw Error('A declared or paid distribution needs --declared=YYYY-MM-DD');
   if(o['approved-by'])row.approved_by=need(o['approved-by'],'approved-by');if(o['in-forecast']!==undefined)row.in_forecast=bool(o['in-forecast'],'in-forecast');
   const r=await insert(db,'distributions',row);await audit(db,'distributions',r.id,cmd,actor,null,r,r.evidence);return r;}
  if(cmd==='certify'){const d=await match(db,'distribution',o.ref);if(d.solvency_certificate_on)throw Error(`A certificate dated ${d.solvency_certificate_on} is already on file`);
   const r=await patch(db,'distributions',d.id,{solvency_certificate_on:date(o.date??today(),'date')});await audit(db,'distributions',d.id,cmd,actor,d,r,need(o.evidence,'evidence'));return r;}
  throw Error(`Unsupported command ${cmd}`);
 });
}

const FLAGS=new Set(['json','actor','entity','account','version','month','name','country','currency','gst-period','tax-from','adaptive-level','code','type','tag','owner','owner-email','adaptive-code',
 'kind','starts','months','notes','copy-from','shift','uplift','uplift-only','approved-by','date','evidence','amount','from','through','note','role','person','department','ends','salary','oncost','status',
 'hire','reduced-rate-until','lender','metric','threshold','frequency','task','due','period-end','lodged','reference','ref','pay-on','declared','in-forecast','a','b','file','map','dry-run','update','out']);
const BOOL=new Set(['json','dry-run','update']);
export function parse(argv){const args=[],o={};for(let i=0;i<argv.length;i++){const a=argv[i];if(!a.startsWith('--')){args.push(a);continue;}
 const eq=a.indexOf('=');const k=eq<0?a.slice(2):a.slice(2,eq);if(!FLAGS.has(k))throw Error(`Unknown flag --${k}`);
 if(BOOL.has(k)){if(eq>=0)throw Error(`--${k} takes no value`);o[k]=true;continue;}
 const v=eq>=0?a.slice(eq+1):argv[++i];if(v===undefined||(eq<0&&v.startsWith('--')))throw Error(`Missing value for --${k}`);o[k]=v;}
 return {cmd:args.shift()||'help',args,o};}
const RAW=new Set(['code','adaptive_code','reference','month','starts','ends','last_tested','first_forecast_breach','tested','months']);
function cell(v,k){if(v&&typeof v==='object')return JSON.stringify(v);if(!RAW.has(k)&&v!==null&&v!==''&&/^-?\d+(\.\d+)?$/.test(String(v))&&Math.abs(Number(v))>=1000)return Number(v).toLocaleString('en-NZ',{maximumFractionDigits:2});return v;}
function display(result){
 if(Array.isArray(result))return result.length?table(result,Object.keys(result[0]).map(key=>({key,label:key,width:70,format:v=>cell(v,key)}))):'(none)';
 return Object.entries(result).map(([k,v])=>Array.isArray(v)?`\n${k.replace(/_/g,' ')}\n${display(v)}`:v&&typeof v==='object'?`\n${k}\n${display([v])}`:`${k}: ${v}`).join('\n').trim();
}
if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href){let db;try{const {cmd,args,o}=parse(process.argv.slice(2));db=await getDb();const r=await run(db,cmd,o,args);console.log(o.json?JSON.stringify(r,null,2):display(r));}catch(e){console.error(e.message);process.exitCode=1;}finally{if(db)await db.close();}}
