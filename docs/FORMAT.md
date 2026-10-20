# JSON protocol v1

```json
{
  "schema_version": 1,
  "left": { "name": "orders", "columns": ["customer"], "rows": [ { "id": "o1", "values": [7] } ] },
  "right": { "name": "customers", "columns": ["customer"], "rows": [ { "id": "c1", "values": [7] }, { "id": "c2", "values": [7] } ] },
  "plan": { "kind": "inner", "keys": [ { "left": "customer", "right": "customer" } ], "nulls": "never", "cardinality": "many_to_one", "require_left": false, "require_right": false, "max_output": 10000 }
}
```

All row cells are positional according to `columns`, with exactly the schema width. IDs are unique per side. Names and IDs contain 1..128 UTF-16 units. Cells are exact plain-decimal integers within +/-1000000000, booleans, strings up to 512 units, or explicit null. Objects/arrays as cells, implicit missing cells, exponent/fraction numbers, duplicate decoded object keys, unknown fields and excessive nesting are rejected.

The root requires schema_version, left, right and plan. Optional `candidate` is another plan using the same kind/null semantics; `inspect` computes exact pair-set changes. Optional `witness` is checked against the original plan and source tables, producing `witness_valid`; it is never assumed correct from its prose.

Plan defaults: kind `inner`, nulls `never`, cardinality `many_to_one`, require_left/right false, max_output 10000. Only `keys` is required. Explicit null is not a default. Each key specifies possibly different left/right column names; either side cannot repeat a key column. Both schemas are resolved before emitting a result.

`inspect_json` returns an `audit` and, when supplied, a `comparison` and/or `witness_valid`. All potentially large counts are decimal strings; input integers remain numbers. Inventory includes matched-pair and full output cardinality, sorted unmatched IDs, null-ineligible IDs, and canonical-typed-key groups with complete member IDs. Null-ineligible rows do not appear in buckets under `never`; they are still represented in unmatched arrays and outer output counts.

The audit counts all issues but returns at most 128 witnesses; `witnesses_omitted` states the difference. LEFT_MULTIPLICITY/RIGHT_MULTIPLICITY are constructive three-row proofs of the corresponding declared cardinality violation. MISSING_LEFT/MISSING_RIGHT are full-input absence checks. OUTPUT_BUDGET uses the full input cardinality. Unknown codes, repeated witness IDs, mismatched key values, missing source IDs and incorrect scope fail verification.

`materialize_json` runs the original plan; `use_candidate=true` is an explicit typed option. The CLI selects it only via `--candidate`, the browser only after selecting the candidate. All selected-plan contracts must pass before constructing pairs. Optional supplied baseline evidence must verify. Each pair contains optional left_id/right_id; absent sides are omitted fields and mean an outer null extension, not a source-row null cell. Pair output is deterministically sorted.

`export_case_json(source,index)` exports a standalone request with the full schema but exactly three selected source rows plus witness. The source can have a candidate, but the exported case reproduces the original plan's selected constructive violation. It can be passed to `inspect_json` / CLI check independently. Absence and budget evidence cannot be exported as three-row reproducers.

Comparison computes intersection of the two match predicates. retained_pairs is the intersection size, lost_pairs = original matched pairs - intersection, gained_pairs = candidate matched pairs - intersection. These counts describe **matched source ID pairs**, excluding outer null-extension pseudo-pairs. newly_unmatched/recovered left/right lists explicitly report coverage changes. No claim is made that reduced matches are necessarily correct business matches.

Limits: 10000 rows/side, 64 columns, 8 key pairs, 2 Mi text units/side, 8 Mi input units, nesting 24, 20000 output pair cap, 128 returned evidence cases. Typed callers receive `JoinError`; JavaScript returns a structured `INVALID_OR_UNSAFE` envelope; CLI uses exit 0/1/2 as documented in README.
