///|
/// Source-row identity pair. None denotes an outer-join null extension.
pub(all) struct Pair {
  left_id : String?
  right_id : String?
} derive(Eq, ToJson)

///|
/// All preflight contracts must pass before any output pair array is built.
pub fn materialize(
  left : Table,
  right : Table,
  p : Plan,
) -> Array[Pair] raise JoinError {
  let report = audit(left, right, p)
  if !report.safe {
    invalid(
      "materialization refused: cardinality, coverage or output budget contract failed",
    )
  }
  let pairs = []
  for group in report.inventory.groups {
    if group.pairs > 0 {
      for l in group.left_ids {
        for r in group.right_ids {
          pairs.push(Pair::{ left_id: Some(l), right_id: Some(r), })
        }
      }
    }
  }
  if p.kind == "left" || p.kind == "full" {
    for id in report.inventory.unmatched_left {
      pairs.push(Pair::{ left_id: Some(id), right_id: None, })
    }
  }
  if p.kind == "right" || p.kind == "full" {
    for id in report.inventory.unmatched_right {
      pairs.push(Pair::{ left_id: None, right_id: Some(id), })
    }
  }
  pairs.sort_by(fn(a, b) {
    match (a.left_id, b.left_id) {
      (Some(x), Some(y)) if x != y => x.compare(y)
      (None, Some(_)) => -1
      (Some(_), None) => 1
      _ =>
        match (a.right_id, b.right_id) {
          (Some(x), Some(y)) => x.compare(y)
          (None, Some(_)) => -1
          (Some(_), None) => 1
          _ => 0
        }
    }
  })
  pairs
}
