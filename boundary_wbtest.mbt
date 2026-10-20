///|
test "typed schemas reject duplicate columns and duplicate source IDs" {
  let t = table("t", [Integer(1)])
  assert_true(
    try {
      validate_table({ ..t, columns: ["a", "a"], })
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      validate_table({ ..t, rows: [t.rows[0], t.rows[0]], })
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      validate_table({
        ..t,
        rows: [{ id: "x", values: [Text("a".repeat(513))], }],
      })
      false
    } catch {
      _ => true
    },
  )
}

///|
test "an empty table pair passes all cardinality and coverage contracts" {
  for kind in ["inner", "left", "right", "full"] {
    let p = plan(
      [{ left: "key", right: "key", }],
      kind~,
      cardinality="one_to_one",
      require_left=true,
      require_right=true,
      max_output=0,
    )
    assert_true(audit(table("l", []), table("r", []), p).safe)
    assert_eq(materialize(table("l", []), table("r", []), p).length(), 0)
  }
}

///|
test "unmatched duplicate keys do not violate matched-group cardinality" {
  let l = table("l", [Integer(1)])
  let r = table("r", [Integer(1), Integer(2), Integer(2)])
  let p = basic(cardinality="one_to_one", kind="full")
  let result = audit(l, r, p)
  assert_true(result.safe)
  assert_eq(result.inventory.output_rows, 3L)
  assert_eq(result.right_multiplicity_groups, 0)
}

///|
test "null source values and outer-join null extensions remain distinguishable" {
  let l = table("l", [NullCell])
  let r = table("r", [NullCell])
  let ordinary = materialize(l, r, basic(kind="full"))
  assert_eq(ordinary.length(), 2)
  assert_true(ordinary.any(p => p.left_id == None))
  let safe = materialize(l, r, basic(kind="full", nulls="equal"))
  assert_eq(safe.length(), 1)
  assert_true(safe[0].left_id == Some("0") && safe[0].right_id == Some("0"))
}

///|
test "null in any composite key position excludes the entire match" {
  let l : Table = {
    name: "l",
    columns: ["a", "b"],
    rows: [{ id: "l", values: [Integer(1), NullCell], }],
  }
  let r : Table = {
    name: "r",
    columns: ["a", "b"],
    rows: [{ id: "r", values: [Integer(1), NullCell], }],
  }
  let p = plan([{ left: "a", right: "a", }, { left: "b", right: "b", }])
  assert_eq(inventory(l, r, p).matched_pairs, 0L)
  assert_eq(inventory(l, r, { ..p, nulls: "equal", }).matched_pairs, 1L)
}

///|
test "budget witness can only certify an actual complete-input overflow" {
  let l = table("l", [Integer(1)])
  let r = table("r", [Integer(1)])
  let p = plan([{ left: "key", right: "key", }], max_output=0)
  let w = audit(l, r, p).witnesses[0]
  assert_true(verify_witness(l, r, p, w))
  assert_true(!verify_witness(l, r, { ..p, max_output: 1, }, w))
  assert_true(!verify_witness(l, r, p, { ..w, scope: "constructive", }))
}

///|
test "inventory and evidence are invariant to input row permutation" {
  let l = table("l", [Integer(2), Integer(1), Integer(1), NullCell])
  let r = table("r", [Integer(1), Integer(2), Integer(1), NullCell])
  let p = plan(
    [{ left: "key", right: "key", }],
    cardinality="one_to_one",
    require_left=true,
  )
  let expected = audit(l, r, p).to_json().stringify()
  let reversed_l = { ..l, rows: l.rows.rev(), }
  let reversed_r = { ..r, rows: r.rows.rev(), }
  assert_eq(audit(reversed_l, reversed_r, p).to_json().stringify(), expected)
}

///|
test "case export detaches source rows from the original input" {
  let l = table("l", [Integer(1)])
  let r = table("r", [Integer(1), Integer(1)])
  let p = basic(cardinality="many_to_one")
  let (a, _) = counterexample(l, r, p, audit(l, r, p).witnesses[0])
  a.rows[0].values[0] = Integer(99)
  assert_true(l.rows[0].values[0] == Integer(1))
}

///|
test "unknown witness codes never count as verified evidence" {
  let l = table("l", [Integer(1)])
  let r = table("r", [Integer(1), Integer(1)])
  let p = basic(cardinality="many_to_one")
  let w = audit(l, r, p).witnesses[0]
  assert_true(!verify_witness(l, r, p, { ..w, code: "TRUST_ME", }))
}

///|
test "strict input rejects excessive nesting, unknown fields and explicit null defaults" {
  assert_true(
    try {
      ignore(inspect_json("[".repeat(30) + "0" + "]".repeat(30)))
      false
    } catch {
      _ => true
    },
  )
  let source = input_json(
    table("l", [Integer(1)]),
    table("r", [Integer(1)]),
    basic(),
  )
  for
    bad in [
      swapped(
        source, "\"schema_version\":1", "\"schema_version\":1,\"extra\":true",
      ),
      swapped(source, "\"nulls\":\"never\"", "\"nulls\":null"),
    ] {
    assert_true(
      try {
        ignore(inspect_json(bad))
        false
      } catch {
        _ => true
      },
    )
  }
}
