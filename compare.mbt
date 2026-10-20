///|
pub(all) struct Comparison {
  schema_version : Int32
  baseline : Audit
  candidate : Audit
  retained_pairs : Int64
  lost_pairs : Int64
  gained_pairs : Int64
  newly_unmatched_left : Array[String]
  newly_unmatched_right : Array[String]
  recovered_left : Array[String]
  recovered_right : Array[String]
} derive(ToJson)

///|
fn list_minus(a : Array[String], b : Array[String]) -> Array[String] {
  let lookup : Map[String, Bool] = Map([])
  for id in b {
    lookup[id] = true
  }
  a.filter(id => !lookup.contains(id))
}

///|
/// Exact pair-set changes. Reduced output does not prove a business-correct key.
pub fn compare(
  left : Table,
  right : Table,
  baseline : Plan,
  candidate : Plan,
) -> Comparison raise JoinError {
  if baseline.kind != candidate.kind || baseline.nulls != candidate.nulls {
    invalid("comparison requires identical join kind and null semantics")
  }
  let before = audit(left, right, baseline)
  let after = audit(left, right, candidate)
  let li = indexes(left, baseline.keys, true)
  let ri = indexes(right, baseline.keys, false)
  for pos in indexes(left, candidate.keys, true) {
    li.push(pos)
  }
  for pos in indexes(right, candidate.keys, false) {
    ri.push(pos)
  }
  // Conjunction of both match predicates equals intersection of their pair sets.
  let retained = inventory_keys(left, right, li, ri, baseline.nulls, "inner").matched_pairs
  {
    schema_version: 1,
    baseline: before,
    candidate: after,
    retained_pairs: retained,
    lost_pairs: before.inventory.matched_pairs - retained,
    gained_pairs: after.inventory.matched_pairs - retained,
    newly_unmatched_left: list_minus(
      after.inventory.unmatched_left,
      before.inventory.unmatched_left,
    ),
    newly_unmatched_right: list_minus(
      after.inventory.unmatched_right,
      before.inventory.unmatched_right,
    ),
    recovered_left: list_minus(
      before.inventory.unmatched_left,
      after.inventory.unmatched_left,
    ),
    recovered_right: list_minus(
      before.inventory.unmatched_right,
      after.inventory.unmatched_right,
    ),
  }
}
