#!/usr/bin/env node
import {readFileSync,statSync} from 'node:fs';
const args=process.argv.slice(2);
const usage='Usage: node bin/joinwitness.mjs <check|materialize|case> <input.json|-> [--candidate|witness-index]\nExit: 0 safe/output/case exported; 1 contract violation; 2 invalid input, unsafe materialization or I/O.';
if(args.length===1&&['-h','--help'].includes(args[0])){console.log(usage);process.exit(0);}
if(!['check','materialize','case'].includes(args[0])||args.length<2||args.length>3||(args[0]==='check'&&args.length!==2)||(args[0]==='materialize'&&args.length===3&&args[2]!=='--candidate')||(args[0]==='case'&&(args.length!==3||!/^\d{1,3}$/.test(args[2])||Number(args[2])>127))){console.error(usage);process.exit(2);}
try{
  if(args[1]!=='-'&&statSync(args[1]).size>33554432)throw Error('transport input exceeds 32 MiB');
  const source=readFileSync(args[1]==='-'?0:args[1],'utf8');
  if(source.length>8388608)throw Error('input exceeds 8 Mi UTF-16 units');
  const core=await import('../dist/engine.js');
  const raw=args[0]==='check'?core.inspect(source):args[0]==='case'?core.export_case(source,Number(args[2])):args[2]==='--candidate'?core.candidate_pairs(source):core.pairs(source);
  const result=JSON.parse(raw);console.log(raw);
  process.exitCode=result.error?2:args[0]==='check'&&(!result.audit.safe||result.witness_valid===false)?1:0;
}catch(e){console.error(JSON.stringify({error:{code:'IO_OR_RUNTIME',message:e.message}}));process.exitCode=2;}
