///|
fn table(name : String, values : Array[Cell]) -> Table {
  {
    name,
    columns: ["key"],
    rows: Array::makei(values.length(), i => Row::{
      id: i.to_string(),
      values: [values[i]],
    }),
  }
}

///|
fn basic(
  kind~ : String = "inner",
  nulls~ : String = "never",
  cardinality~ : String = "many_to_many",
) -> Plan raise JoinError {
  plan([{ left: "key", right: "key", }], kind~, nulls~, cardinality~)
}

///|
test "join multiplicity is the product of duplicate counts" {
  let result = inventory(
    table("left", [Integer(1), Integer(1)]),
    table("right", [Integer(1), Integer(1), Integer(1)]),
    basic(),
  )
  assert_eq(result.matched_pairs, 6L)
  assert_eq(result.output_rows, 6L)
  assert_eq(result.matched_left, 2)
  assert_eq(result.matched_right, 3)
}

///|
test "outer joins extend unmatched rows individually, including nulls" {
  let l = table("left", [Integer(1), Integer(2), NullCell, NullCell])
  let r = table("right", [Integer(1), Integer(3), NullCell])
  for pair in [("inner", 1L), ("left", 4L), ("right", 3L), ("full", 6L)] {
    let (kind, count) = pair
    let result = inventory(l, r, basic(kind~))
    assert_eq(result.output_rows, count)
    assert_eq(result.unmatched_left, ["1", "2", "3"])
    assert_eq(result.excluded_null_right, ["2"])
  }
}

///|
test "null-safe comparison is explicit and component-wise" {
  let l = table("left", [NullCell, NullCell, Integer(1), Text("1"), Flag(true)])
  let r = table("right", [NullCell, Integer(1)])
  assert_eq(inventory(l, r, basic()).matched_pairs, 1L)
  assert_eq(inventory(l, r, basic(nulls="equal")).matched_pairs, 3L)
}

///|
test "different column names and composite keys preserve source identities" {
  let l : Table = {
    name: "a",
    columns: ["tenant", "user"],
    rows: [
      { id: "same", values: [Text("east"), Integer(1)], },
      { id: "other", values: [Text("west"), Integer(1)], },
    ],
  }
  let r : Table = {
    name: "b",
    columns: ["uid", "org"],
    rows: [{ id: "same", values: [Integer(1), Text("west")], }],
  }
  let p = plan(
    [{ left: "tenant", right: "org", }, { left: "user", right: "uid", }],
    cardinality="many_to_many",
  )
  let result = inventory(l, r, p)
  assert_eq(result.matched_pairs, 1L)
  assert_eq(result.unmatched_left, ["same"])
  assert_true(row_key(l, "same", p, true) != row_key(r, "same", p, false))
}

///|
test "all small primitive tables agree with an independent nested-loop oracle" {
  let domain = [NullCell, Integer(0), Text("0"), Flag(false)]
  for lm in 0..<64 {
    for rm in 0..<64 {
      let lv = Array::makei(3, i => domain[(lm >> (2 * i)) & 3])
      let rv = Array::makei(3, i => domain[(rm >> (2 * i)) & 3])
      for nulls in ["never", "equal"] {
        let mut pairs : Int64 = 0
        let ml = Array::make(3, false)
        let mr = Array::make(3, false)
        for i in 0..<3 {
          for j in 0..<3 {
            if lv[i] == rv[j] && (nulls == "equal" || lv[i] != NullCell) {
              pairs = pairs + 1
              ml[i] = true
              mr[j] = true
            }
          }
        }
        let ul = ml.filter(x => !x).length()
        let ur = mr.filter(x => !x).length()
        for kind in ["inner", "left", "right", "full"] {
          let expected = pairs +
            (if kind == "left" || kind == "full" { ul.to_int64() } else { 0 }) +
            (if kind == "right" || kind == "full" { ur.to_int64() } else { 0 })
          let actual = inventory(
            table("l", lv),
            table("r", rv),
            basic(kind~, nulls~),
          )
          assert_eq(actual.matched_pairs, pairs)
          assert_eq(actual.output_rows, expected)
        }
      }
    }
  }
}
