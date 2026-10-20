///|
test "validated schema distinguishes real nulls from missing cells" {
  validate_table({
    name: "t",
    columns: ["id"],
    rows: [{ id: "r", values: [NullCell], }],
  })
  assert_true(
    try {
      validate_table({
        name: "t",
        columns: ["id"],
        rows: [{ id: "r", values: [], }],
      })
      false
    } catch {
      _ => true
    },
  )
}

///|
test "plans reject repeated keys and unsupported modes" {
  let key = KeyPair::{ left: "a", right: "b", }
  ignore(plan([key]))
  assert_true(
    try {
      ignore(plan([key, key]))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(plan([key], nulls="implicit"))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "typed tuple keys cannot collide through delimiters or primitive coercion" {
  assert_true(
    encode_key([Text("a:b"), Text("c")]) != encode_key([Text("a"), Text("b:c")]),
  )
  assert_true(encode_key([Integer(1)]) != encode_key([Text("1")]))
  assert_true(encode_key([Flag(true)]) != encode_key([Integer(1)]))
}
