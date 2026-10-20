"""Prevent accidental reuse of another contestant's author/committer identity."""
import os,pathlib,subprocess,json,sys
sys.stdout.reconfigure(encoding='utf-8')
root=pathlib.Path(__file__).resolve().parent.parent
actual_root=pathlib.Path(subprocess.check_output(['git','rev-parse','--show-toplevel'],cwd=root).decode('utf-8').strip()).resolve()
assert actual_root==root.resolve(),'Identity verification requires this project Git checkout, not an ancestor repository'
rows=subprocess.check_output(['git','log','--format=%H%x00%an%x00%ae%x00%cn%x00%ce'],cwd=root).decode('utf-8').splitlines()
assert rows,'no history'
for row in rows:
    sha,author,email,committer,committer_email=row.split('\x00')
    assert author==committer=='蒋琦',(sha,'author or committer differs')
    assert email==committer_email=='314918884+JQ-ai-nb@users.noreply.github.com',(sha,'email differs')
repo=os.environ.get('GITHUB_REPOSITORY')
if repo:assert repo.lower()=='jq-ai-nb/joinwitness',repo
manifest=(root/'moon.mod').read_text(encoding='utf-8')
assert 'name = "JQ-ai-nb/joinwitness"' in manifest
assert 'https://github.com/JQ-ai-nb/JoinWitness' in manifest
print(json.dumps({'checked_commits':len(rows),'author_and_committer':'JQ-ai-nb / 蒋琦','all_identical':True},ensure_ascii=False))
