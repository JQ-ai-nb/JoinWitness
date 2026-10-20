import {spawnSync} from 'node:child_process';
import {mkdirSync,copyFileSync,readdirSync} from 'node:fs';
import {resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const run=spawnSync(process.platform==='win32'?'moon.exe':'moon',['build','api','--target','js','--release','--deny-warn'],{cwd:root,stdio:'inherit'});
if(run.error||run.status!==0){console.error('MoonBit 0.10.16+ is required on PATH.');process.exit(2);}
for(const dir of ['dist','web','web/data','web/licenses','dist/licenses'])mkdirSync(resolve(root,dir),{recursive:true});
for(const dst of ['dist/engine.js','web/engine.js'])copyFileSync(resolve(root,'_build/js/release/build/api/api.js'),resolve(root,dst));
for(const name of readdirSync(resolve(root,'examples')).filter(n=>n.endsWith('.json')))copyFileSync(resolve(root,'examples',name),resolve(root,'web/data',name));
for(const dir of ['dist/licenses','web/licenses'])for(const name of ['LICENSE','NOTICE'])copyFileSync(resolve(root,`third_party/MoonBit-core-${name}.txt`),resolve(root,dir,`MoonBit-core-${name}.txt`));
console.log('Built the shared MoonBit join engine.');
