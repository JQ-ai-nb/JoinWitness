import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {resolve} from 'node:path';
import {inspect,pairs,candidate_pairs,export_case} from '../dist/engine.js';
const root=resolve(import.meta.dirname,'..');
const fixture=name=>readFileSync(resolve(root,'examples',name),'utf8');
const cli=(...args)=>spawnSync(process.execPath,['bin/joinwitness.mjs',...args],{cwd:root,encoding:'utf8'});
test('tenant collision exposes seven output rows and a verified three-row witness',()=>{
  const source=fixture('tenant-collision.json'),r=JSON.parse(inspect(source));
  assert.equal(r.audit.inventory.output_rows,'7');assert.equal(r.audit.safe,false);
  assert.equal(r.comparison.candidate.inventory.output_rows,'4');
  assert.equal(r.comparison.lost_pairs,'3');assert.equal(r.comparison.gained_pairs,'0');
  assert.equal(r.comparison.candidate.safe,true);
  const c=JSON.parse(export_case(source,0));assert.equal(c.left.rows.length+c.right.rows.length,3);
  const verified=JSON.parse(inspect(JSON.stringify(c)));assert.equal(verified.witness_valid,true);
});
test('equal row counts do not hide complete pair identity replacement',()=>{
  const r=JSON.parse(inspect(fixture('key-swap.json'))).comparison;
  assert.equal(r.baseline.inventory.output_rows,'2');assert.equal(r.candidate.inventory.output_rows,'2');
  assert.equal(r.retained_pairs,'0');assert.equal(r.lost_pairs,'2');assert.equal(r.gained_pairs,'2');
});
test('null equality and primitive type mismatch create complete-input absence evidence',()=>{
  const r=JSON.parse(inspect(fixture('coverage-gap.json'))).audit;
  assert.deepEqual(r.inventory.unmatched_left,['event-2','event-3','event-4']);
  assert.equal(r.witnesses.length,3);assert.ok(r.witnesses.every(w=>w.scope==='full_input_absence'));
  assert.ok(JSON.parse(export_case(fixture('coverage-gap.json'),0)).error);
});
test('materialization is blocked for unsafe baseline and exact for explicit candidate',()=>{
  const source=fixture('tenant-collision.json');assert.ok(JSON.parse(pairs(source)).error);
  const r=JSON.parse(candidate_pairs(source));assert.equal(r.selected,'candidate');assert.equal(r.pairs.length,4);
  assert.deepEqual(r.pairs[0],{left_id:'order-A1',right_id:'customer-A'});
});
test('raw duplicate decoded keys and rounded-looking fractions are rejected',()=>{
  const source=fixture('tenant-collision.json');
  for(const bad of [source.replace('"schema_version":1','"schema_version":1,"schema_versio\\u006e":1'),source.replace('[7,"A",120]','[7.00000000000000001,"A",120]'),source.replace('[7,"A",120]','[7e0,"A",120]')])assert.equal(JSON.parse(inspect(bad)).error.code,'INVALID_OR_UNSAFE');
});
test('CLI exit codes distinguish safe checks, failed contracts and invalid input',()=>{
  assert.equal(cli('check','examples/key-swap.json').status,0);
  assert.equal(cli('check','examples/tenant-collision.json').status,1);
  assert.equal(cli('materialize','examples/tenant-collision.json').status,2);
  assert.equal(cli('materialize','examples/tenant-collision.json','--candidate').status,0);
  assert.equal(cli('check','missing.json').status,2);
  assert.equal(cli('--help').status,0);
});
test('CLI case export can be independently checked through raw stdin',()=>{
  const c=cli('case','examples/tenant-collision.json','0');assert.equal(c.status,0,c.stderr);
  const r=spawnSync(process.execPath,['bin/joinwitness.mjs','check','-'],{cwd:root,input:c.stdout,encoding:'utf8'});
  assert.equal(r.status,1);assert.equal(JSON.parse(r.stdout).witness_valid,true);
  assert.equal(cli('case','examples/tenant-collision.json','0.5').status,2);
});
test('invalid schema, unknown fields and typed cells fail before analysis',()=>{
  const source=JSON.parse(fixture('key-swap.json'));
  for(const mutate of [x=>x.unknown=1,x=>x.left.rows[0].values=[],x=>x.plan.keys[0].left='missing',x=>x.candidate.nulls='equal',x=>x.left.rows.push(x.left.rows[0])]){
    const v=structuredClone(source);mutate(v);assert.ok(JSON.parse(inspect(JSON.stringify(v))).error);
  }
});
test('forged standalone witness is reported invalid without trusting prose',()=>{
  const c=JSON.parse(export_case(fixture('tenant-collision.json'),0));c.witness.right_ids=[c.witness.right_ids[0],c.witness.right_ids[0]];
  assert.equal(JSON.parse(inspect(JSON.stringify(c))).witness_valid,false);
});
test('Unicode and markup remain literal row provenance',()=>{
  const v=JSON.parse(fixture('key-swap.json'));v.left.rows[0].id='<img src=x onerror=alert(1)> 🔧';
  const r=JSON.parse(inspect(JSON.stringify(v)));assert.ok(r.audit.inventory.groups.some(g=>g.left_ids.includes(v.left.rows[0].id)));
});
test('public case bridge rejects fractional, negative and nonfinite indices',()=>{
  const source=fixture('tenant-collision.json');
  for(const index of [0.5,-1,NaN,Infinity,128])assert.ok(JSON.parse(export_case(source,index)).error);
});
test('contestant identity checker emits valid UTF-8 even under a Windows codepage',{skip:existsSync(resolve(root,'.git'))?false:'Requires Git checkout metadata'},()=>{
  const r=spawnSync('python',['scripts/check_identity.py'],{cwd:root,env:{...process.env,PYTHONIOENCODING:'cp1252'},encoding:'utf8'});
  assert.equal(r.status,0,r.stderr);
  const v=JSON.parse(r.stdout);assert.equal(v.author_and_committer,'JQ-ai-nb / 蒋琦');assert.equal(v.all_identical,true);
});
