///|
fn swapped(s : String, before : String, after : String) -> String {
  s.replace(old=before, new=after)
}

///|
fn input_json(left : Table, right : Table, p : Plan) -> String {
  let v : Json = {
    "schema_version": 1,
    "left": left.to_json(),
    "right": right.to_json(),
    "plan": p.to_json(),
  }
  v.stringify()
}

///|
test "wire roundtrip preserves primitive types and independently verifiable case" {
  let source = input_json(
    table("l", [Integer(1)]),
    table("r", [Integer(1), Integer(1)]),
    basic(cardinality="many_to_one"),
  )
  let r = request(export_case_json(source, 0))
  assert_true(
    verify_witness(
      r.left,
      r.right,
      r.plan,
      match r.witness {
        Some(w) => w
        None => abort("missing evidence")
      },
    ),
  )
  assert_eq(r.left.rows.length() + r.right.rows.length(), 3)
  let out = object(parse_text(inspect_json(export_case_json(source, 0))))
  assert_true(boolean(required(out, "witness_valid")))
}

///|
test "strict wire rejects duplicate decoded keys and float rounding camouflage" {
  let source = input_json(
    table("l", [Integer(1)]),
    table("r", [Integer(1)]),
    basic(),
  )
  for
    bad in [
      swapped(
        source, "\"schema_version\":1", "\"schema_version\":1,\"schema_versio\\u006e\":1",
      ),
      swapped(source, "\"values\":[1]", "\"values\":[1.00000000000000001]"),
      swapped(source, "\"values\":[1]", "\"values\":[1e0]"),
      swapped(source, "\"values\":[1]", "\"values\":[1e-999]"),
      swapped(source, "\"values\":[1]", "\"values\":[{}]"),
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

///|
test "wire resolves all schemas before comparing plans and refuses missing candidates" {
  let source = input_json(
    table("l", [Text("x")]),
    table("r", [Text("x")]),
    basic(),
  )
  assert_true(
    try {
      ignore(materialize_json(source, use_candidate=true))
      false
    } catch {
      _ => true
    },
  )
  let bad = swapped(source, "\"left\":\"key\"", "\"left\":\"absent\"")
  assert_true(
    try {
      ignore(inspect_json(bad))
      false
    } catch {
      _ => true
    },
  )
}
