"""Cross-check real SQL pairs, not just row counts. SQLite 3.39+ required.
Boolean cells have separate MoonBit tests: SQLite has no distinct Boolean type.
"""
import json, pathlib, random, sqlite3, subprocess
root=pathlib.Path(__file__).resolve().parent.parent
assert sqlite3.sqlite_version_info >= (3,39,0),sqlite3.sqlite_version
rng=random.Random(20261020)
requests=[];expected=[]
for case in range(40):
    domain=[None,0,1,"0","1","中文","a:b"]
    lv=[rng.choice(domain) for _ in range(rng.randrange(7))]
    rv=[rng.choice(domain) for _ in range(rng.randrange(7))]
    conn=sqlite3.connect(":memory:")
    conn.execute("create table l (id text, k)");conn.execute("create table r (id text, k)")
    conn.executemany("insert into l values (?,?)",[(f"l{i}",v) for i,v in enumerate(lv)])
    conn.executemany("insert into r values (?,?)",[(f"r{i}",v) for i,v in enumerate(rv)])
    for nulls in ["never","equal"]:
        for kind in ["inner","left","right","full"]:
            predicate="l.k = r.k" if nulls=="never" else "l.k IS r.k"
            pairs=conn.execute(f"select l.id,r.id from l {kind} join r on {predicate}").fetchall()
            expected.append(set(pairs))
            requests.append({"schema_version":1,"left":{"name":"l","columns":["key"],"rows":[{"id":f"l{i}","values":[v]} for i,v in enumerate(lv)]},
              "right":{"name":"r","columns":["key"],"rows":[{"id":f"r{i}","values":[v]} for i,v in enumerate(rv)]},
              "plan":{"kind":kind,"keys":[{"left":"key","right":"key"}],"nulls":nulls,"cardinality":"many_to_many"}})
    conn.close()
js="import{inspect,pairs}from'./dist/engine.js';import{readFileSync}from'node:fs';const r=JSON.parse(readFileSync(0,'utf8'));console.log(JSON.stringify(r.map(x=>{const s=JSON.stringify(x);return{audit:JSON.parse(inspect(s)),pairs:JSON.parse(pairs(s))}})));"
p=subprocess.run(["node","--input-type=module","-e",js],input=json.dumps(requests,ensure_ascii=False),capture_output=True,text=True,encoding="utf-8",cwd=root,check=True)
actual=json.loads(p.stdout)
for i,(r,want) in enumerate(zip(actual,expected)):
    assert "error" not in r["audit"] and "error" not in r["pairs"],(i,r)
    got={(v.get("left_id"),v.get("right_id")) for v in r["pairs"]["pairs"]}
    assert got==want,(i,got,want)
    assert len(r["pairs"]["pairs"])==len(want),(i,"duplicate pair")
    assert int(r["audit"]["audit"]["inventory"]["output_rows"])==len(want),i
print(f"SQLite {sqlite3.sqlite_version} differential oracle: {len(requests)} complete join pair sets matched.")
