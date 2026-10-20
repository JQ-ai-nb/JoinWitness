///|
test "adding tenant key removes cross-tenant pairs without hiding coverage" {
  let l : Table = {
    name: "l",
    columns: ["key", "tenant"],
    rows: [
      { id: "a", values: [Integer(1), Text("A")], },
      { id: "b", values: [Integer(1), Text("B")], },
      { id: "c", values: [Integer(1), Text("C")], },
    ],
  }
  let r : Table = {
    name: "r",
    columns: ["key", "tenant"],
    rows: [
      { id: "x", values: [Integer(1), Text("A")], },
      { id: "y", values: [Integer(1), Text("B")], },
    ],
  }
  let base = basic(cardinality="many_to_one")
  let candidate = plan([
    { left: "key", right: "key", },
    { left: "tenant", right: "tenant", },
  ])
  let diff = compare(l, r, base, candidate)
  assert_eq(diff.baseline.inventory.matched_pairs, 6L)
  assert_eq(diff.candidate.inventory.matched_pairs, 2L)
  assert_eq(diff.retained_pairs, 2L)
  assert_eq(diff.lost_pairs, 4L)
  assert_eq(diff.gained_pairs, 0L)
  assert_eq(diff.newly_unmatched_left, ["c"])
  assert_true(diff.candidate.safe)
}

///|
test "substituting an unrelated key can simultaneously lose and gain pairs" {
  let l : Table = {
    name: "l",
    columns: ["a", "b"],
    rows: [
      { id: "l1", values: [Integer(1), Integer(0)], },
      { id: "l2", values: [Integer(2), Integer(1)], },
    ],
  }
  let r : Table = {
    name: "r",
    columns: ["a", "b"],
    rows: [
      { id: "r1", values: [Integer(1), Integer(1)], },
      { id: "r2", values: [Integer(2), Integer(0)], },
    ],
  }
  let a = plan([{ left: "a", right: "a", }])
  let b = plan([{ left: "b", right: "b", }])
  let diff = compare(l, r, a, b)
  assert_eq(diff.baseline.inventory.matched_pairs, 2L)
  assert_eq(diff.candidate.inventory.matched_pairs, 2L)
  assert_eq(diff.retained_pairs, 0L)
  assert_eq(diff.lost_pairs, 2L)
  assert_eq(diff.gained_pairs, 2L)
}

///|
test "comparison identity and symmetry hold across nullable composite data" {
  let l : Table = {
    name: "l",
    columns: ["a", "b"],
    rows: [
      { id: "a", values: [NullCell, Integer(1)], },
      { id: "b", values: [Integer(1), Integer(2)], },
    ],
  }
  let r : Table = {
    name: "r",
    columns: ["a", "b"],
    rows: [
      { id: "x", values: [NullCell, Integer(1)], },
      { id: "y", values: [Integer(1), Integer(3)], },
    ],
  }
  for nulls in ["never", "equal"] {
    let a = plan([{ left: "a", right: "a", }], nulls~)
    let b = plan([{ left: "b", right: "b", }], nulls~)
    let same = compare(l, r, a, a)
    assert_eq(same.lost_pairs, 0L)
    assert_eq(same.gained_pairs, 0L)
    let ab = compare(l, r, a, b)
    let ba = compare(l, r, b, a)
    assert_eq(ab.retained_pairs, ba.retained_pairs)
    assert_eq(ab.lost_pairs, ba.gained_pairs)
  }
}

///|
test "pair-set intersection agrees with explicit identity-pair oracle" {
  for seed in 0..<80 {
    let rows_l = Array::makei(5, i => Row::{
      id: i.to_string(),
      values: [Integer((seed + i * 7) % 3), Integer((seed * 3 + i) % 4)],
    })
    let rows_r = Array::makei(6, i => Row::{
      id: i.to_string(),
      values: [Integer((seed * 2 + i) % 3), Integer((seed + i * 7) % 4)],
    })
    let l : Table = { name: "l", columns: ["a", "b"], rows: rows_l, }
    let r : Table = { name: "r", columns: ["a", "b"], rows: rows_r, }
    let a = plan([{ left: "a", right: "a", }], cardinality="many_to_many")
    let b = plan([{ left: "b", right: "b", }], cardinality="many_to_many")
    let mut retained : Int64 = 0
    let mut lost : Int64 = 0
    let mut gained : Int64 = 0
    for lr in rows_l {
      for rr in rows_r {
        let in_a = lr.values[0] == rr.values[0]
        let in_b = lr.values[1] == rr.values[1]
        if in_a && in_b {
          retained = retained + 1
        } else if in_a {
          lost = lost + 1
        } else if in_b {
          gained = gained + 1
        }
      }
    }
    let actual = compare(l, r, a, b)
    assert_eq(actual.retained_pairs, retained)
    assert_eq(actual.lost_pairs, lost)
    assert_eq(actual.gained_pairs, gained)
  }
}
