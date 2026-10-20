# Semantic contract

JoinWitness profiles two bounded in-memory tables under a conjunction of equality keys. It does not parse SQL or connect to a database. Cells are null, exact integers, booleans or Unicode text. Text comparison is exact and case sensitive; types never coerce (`1`, `"1"`, and `true` differ). Input row IDs identify provenance and are unique within each side; identical IDs on opposite sides remain distinct.

`nulls=never` models SQL equality: any null key component makes a row ineligible to match. `nulls=equal` models a component-wise null-safe equality, comparable to `IS NOT DISTINCT FROM`. This is explicit and not inferred from the data. Missing array cells are schema errors, never implicit nulls.

Matched key groups contribute `left_count * right_count` pairs. Unmatched rows contribute one null-extended output each in the applicable left/right/full outer join. Profiles compute exact counts without materializing the product. Counts that can be large serialize as decimal strings.

Cardinality contracts apply to **matched groups**: many_to_one requires at most one right row per matched key; one_to_many requires at most one left row; one_to_one requires both; many_to_many imposes no multiplicity restriction. Coverage requirements independently demand that every row on the selected side has a partner. The chosen outer join may retain unmatched rows but does not make coverage true.

Multiplicity violations carry constructive three-row counterexamples: one row on one side and two matching rows on the other. Removing any selected row eliminates that specific multiplicity violation. Absence witnesses are different: a missing partner must be checked against the complete opposite input, not proven by a tiny excerpt. Witness verification always rechecks against the supplied full tables; it is not a cryptographic provenance proof.

Candidate key comparisons use the same inputs, null mode and join kind. Matched-pair intersections are counted by the conjunction of baseline and candidate keys. This yields exact retained/lost/gained pair counts without enumerating large join outputs. A key that reduces duplication may also lose legitimate matches; reports expose both and do not automatically declare a semantic fix.

Limits: 10000 rows per table, 64 columns, 8 public key pairs, 512 UTF-16 units per text cell, 2 Mi text units per table, 8 Mi JSON input units and depth 24. Materialized output has a configurable cap in 0..20000 and requires all declared contracts to pass. Evidence is deterministically bounded and truncation is reported. The host owns IO, storage, trusted inputs and business interpretation of candidate keys.
