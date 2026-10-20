///|
test "cardinality contracts apply to matched keys while coverage is independent" {
  let l = table("l", [Integer(1), Integer(1), Integer(2)])
  let r = table("r", [Integer(1), Integer(1), Integer(3), Integer(3)])
  let p = plan(
    [{ left: "key", right: "key", }],
    cardinality="one_to_one",
    require_left=true,
    require_right=true,
  )
  let result = audit(l, r, p)
  assert_eq(result.left_multiplicity_groups, 1)
  assert_eq(result.right_multiplicity_groups, 1)
  assert_eq(result.issue_count, 5)
  for w in result.witnesses {
    assert_true(verify_witness(l, r, p, w))
  }
}

///|
test "constructive witnesses are complete three-row reproducers and deletion minimal" {
  let l = table("l", [Integer(1), Integer(1)])
  let r = table("r", [Integer(1), Integer(1), Integer(1)])
  let p = basic(cardinality="one_to_one")
  let result = audit(l, r, p)
  for w in result.witnesses {
    let (small_l, small_r) = counterexample(l, r, p, w)
    assert_eq(small_l.rows.length() + small_r.rows.length(), 3)
    assert_true(audit(small_l, small_r, p).witnesses.any(v => v.code == w.code))
    for i in 0..<small_l.rows.length() {
      let reduced = {
        ..small_l,
        rows: small_l.rows.filter(row => row.id != small_l.rows[i].id),
      }
      assert_true(
        !audit(reduced, small_r, p).witnesses.any(v => v.code == w.code),
      )
    }
    for i in 0..<small_r.rows.length() {
      let reduced = {
        ..small_r,
        rows: small_r.rows.filter(row => row.id != small_r.rows[i].id),
      }
      assert_true(
        !audit(small_l, reduced, p).witnesses.any(v => v.code == w.code),
      )
    }
  }
}

///|
test "absence evidence is invalidated when the missing partner exists" {
  let l = table("l", [Integer(1)])
  let r = table("r", [])
  let p = plan([{ left: "key", right: "key", }], require_left=true)
  let w = audit(l, r, p).witnesses[0]
  assert_eq(w.scope, "full_input_absence")
  assert_true(verify_witness(l, r, p, w))
  assert_true(!verify_witness(l, table("r", [Integer(1)]), p, w))
  assert_true(
    try {
      ignore(counterexample(l, r, p, w))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "forged witness row IDs, duplicate IDs and scope claims are rejected" {
  let l = table("l", [Integer(1)])
  let r = table("r", [Integer(1), Integer(1)])
  let p = basic(cardinality="many_to_one")
  let w = audit(l, r, p).witnesses[0]
  assert_true(!verify_witness(l, r, p, { ..w, right_ids: ["0", "0"], }))
  assert_true(!verify_witness(l, r, p, { ..w, left_ids: ["missing"], }))
  assert_true(!verify_witness(l, r, p, { ..w, key: [Text("1")], }))
  assert_true(!verify_witness(l, r, p, { ..w, scope: "full_input_absence", }))
}

///|
test "evidence truncation never truncates issue totals or changes safety" {
  let l = table("l", Array::makei(200, i => Integer(i)))
  let r = table("r", [])
  let p = plan([{ left: "key", right: "key", }], kind="left", require_left=true)
  let result = audit(l, r, p)
  assert_eq(result.issue_count, 200)
  assert_eq(result.witnesses.length(), 128)
  assert_eq(result.witnesses_omitted, 72)
  assert_true(!result.safe)
}
