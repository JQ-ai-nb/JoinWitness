import{performance}from'node:perf_hooks';
import{mkdirSync,writeFileSync}from'node:fs';
import{inspect}from'../dist/engine.js';
const make=(count,dense)=>{
  const table=name=>({name,columns:['customer','tenant'],rows:Array.from({length:count},(_,i)=>({id:`${name}-${i}`,values:[dense?0:i%100,Math.floor(i/100)]}))});
  const plan={keys:[{left:'customer',right:'customer'}],cardinality:dense?'many_to_many':'many_to_one',max_output:20000};
  const request={schema_version:1,left:table('left'),right:table('right'),plan};
  if(!dense)request.candidate={...plan,keys:[...plan.keys,{left:'tenant',right:'tenant'}]};
  return JSON.stringify(request);
};
const results=[];
for(const [name,count,dense]of[['dense_guard',10000,true],['composite_comparison',5000,false]]){
  const source=make(count,dense);for(let i=0;i<3;i++)inspect(source);
  const samples=[];let raw;
  for(let i=0;i<10;i++){const start=performance.now();raw=inspect(source);samples.push(performance.now()-start);}
  const report=JSON.parse(raw);if(report.error)throw Error(report.error.message);
  if(dense){if(report.audit.inventory.output_rows!=='100000000'||report.audit.safe)throw Error('dense guard assertion');}
  else if(report.comparison.retained_pairs!=='5000'||report.comparison.lost_pairs!=='245000'||!report.comparison.candidate.safe)throw Error('comparison assertion');
  samples.sort((a,b)=>a-b);results.push({workload:name,rows_per_side:count,input_bytes:Buffer.byteLength(source),output_bytes:Buffer.byteLength(raw),samples_ms:samples,median_ms:(samples[4]+samples[5])/2,max_ms:samples[9],matched_pairs:report.audit.inventory.matched_pairs,candidate_pairs:report.comparison?.candidate.inventory.matched_pairs});
}
const output={node:process.version,os:process.platform,arch:process.arch,warmups:3,samples:10,scope:'strict parsing, complete join preflight, evidence, optional pair-set comparison and full JSON output; no materialized product',results};
mkdirSync('artifacts',{recursive:true});writeFileSync('artifacts/benchmark.json',JSON.stringify(output,null,2)+'\n');console.log(JSON.stringify(output,null,2));
