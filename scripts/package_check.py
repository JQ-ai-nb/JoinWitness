"""Inspect the actual Moon archive for local credentials/build artifacts."""
import pathlib,subprocess,zipfile,json
root=pathlib.Path(__file__).resolve().parent.parent
subprocess.run(['moon','package'],cwd=root,check=True)
archive=max((root/'_build/publish').glob('*.zip'),key=lambda p:p.stat().st_mtime)
with zipfile.ZipFile(archive) as z:
    names=z.namelist()
    for n in names:
        assert not any(p in {'work','credentials.json','.git','_build','dist','artifacts','deliverables','engine.js'} for p in pathlib.PurePosixPath(n).parts),n
    for required in ['LICENSE','audit.mbt','docs/SEMANTICS.md','third_party/MoonBit-core-LICENSE.txt']:
        assert required in names,required
print(json.dumps({'archive':archive.name,'files':len(names),'local_secrets_and_build_output':False}))
