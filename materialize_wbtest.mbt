///|
test "safe full join preserves source identities and null extends each orphan" {
  let l = table("l", [Integer(1), Integer(2)])
  let r = table("r", [Integer(1), Integer(3)])
  let result = materialize(l, r, basic(kind="full", cardinality="one_to_one"))
  assert_eq(result.length(), 3)
  assert_true(
    result.contains(Pair::{ left_id: Some("0"), right_id: Some("0"), }),
  )
  assert_true(result.contains(Pair::{ left_id: Some("1"), right_id: None, }))
  assert_true(result.contains(Pair::{ left_id: None, right_id: Some("1"), }))
}

///|
test "preflight blocks huge products before enumerating pairs" {
  let l = table("l", Array::make(10000, Integer(1)))
  let r = table("r", Array::make(10000, Integer(1)))
  let p = plan(
    [{ left: "key", right: "key", }],
    cardinality="many_to_many",
    max_output=20000,
  )
  let report = audit(l, r, p)
  assert_eq(report.inventory.output_rows, 100000000L)
  assert_eq(report.issue_count, 1)
  assert_eq(report.witnesses[0].code, "OUTPUT_BUDGET")
  assert_true(verify_witness(l, r, p, report.witnesses[0]))
  assert_true(
    try {
      ignore(materialize(l, r, p))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "coverage failure blocks output even when the outer join would retain orphans" {
  let l = table("l", [Integer(1)])
  let r = table("r", [])
  let p = plan([{ left: "key", right: "key", }], kind="left", require_left=true)
  assert_true(
    try {
      ignore(materialize(l, r, p))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(materialize(l, r, basic(kind="left")).length(), 1)
}

///|
test "declared row budget boundary is inclusive and empty joins permit zero" {
  let l = table("l", [Integer(1), Integer(1)])
  let r = table("r", [Integer(1), Integer(1)])
  let p = plan(
    [{ left: "key", right: "key", }],
    cardinality="many_to_many",
    max_output=4,
  )
  assert_eq(materialize(l, r, p).length(), 4)
  assert_true(
    try {
      ignore(materialize(l, r, { ..p, max_output: 3, }))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(
    materialize(table("l", []), table("r", []), { ..p, max_output: 0, }).length(),
    0,
  )
}
