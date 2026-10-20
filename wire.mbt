///|
fn parse_text(source : String) -> Json raise JoinError {
  if source.length() > 8388608 {
    invalid("JSON input exceeds 8 Mi UTF-16 units")
  }
  @json.parse(
    source,
    max_nesting_depth=24,
    reject_duplicate_keys=true,
    preserve_number_repr=true,
  ) catch {
    _ => invalid("invalid JSON, duplicate decoded key, or nesting exceeds 24")
  }
}

///|
fn object(value : Json) -> Map[String, Json] raise JoinError {
  match value {
    Object(f) => f
    _ => invalid("expected object")
  }
}

///|
fn only(f : Map[String, Json], allowed : Array[String]) -> Unit raise JoinError {
  for name, _ in f {
    if !allowed.contains(name) {
      invalid("unknown or inapplicable field")
    }
  }
}

///|
fn required(f : Map[String, Json], name : String) -> Json raise JoinError {
  match f.get(name) {
    Some(v) => v
    None => invalid("missing required field: " + name)
  }
}

///|
fn string(value : Json) -> String raise JoinError {
  match value {
    String(s) => s
    _ => invalid("expected string")
  }
}

///|
fn boolean(value : Json) -> Bool raise JoinError {
  match value {
    True => true
    False => false
    _ => invalid("expected boolean")
  }
}

///|
fn array(value : Json, limit : Int32) -> Array[Json] raise JoinError {
  match value {
    Array(a) => {
      if a.length() > limit {
        invalid("array capacity exceeded")
      }
      a
    }
    _ => invalid("expected array")
  }
}

///|
/// Validate the original token, rather than a rounded IEEE value.
fn integer(value : Json) -> Int32 raise JoinError {
  match value {
    Number(n, repr=Some(token)) => {
      if token.length() > 11 || token.length() == 0 {
        invalid("integer token outside supported range")
      }
      for i in 0..<token.length() {
        let ch = token[i]
        if !(ch >= 48 && ch <= 57) && !(i == 0 && ch == 45) {
          invalid(
            "integers require plain decimal notation, no exponent or fraction",
          )
        }
      }
      if n < -1000000000.0 || n > 1000000000.0 {
        invalid("integer outside +/-1000000000")
      }
      n.to_int()
    }
    _ => invalid("expected decimal integer")
  }
}

///|
fn optional_string(
  f : Map[String, Json],
  name : String,
  fallback : String,
) -> String raise JoinError {
  match f.get(name) {
    Some(v) => string(v)
    None => fallback
  }
}

///|
fn optional_bool(
  f : Map[String, Json],
  name : String,
  fallback : Bool,
) -> Bool raise JoinError {
  match f.get(name) {
    Some(v) => boolean(v)
    None => fallback
  }
}

///|
fn read_cell(v : Json) -> Cell raise JoinError {
  match v {
    Null => NullCell
    String(s) => {
      if s.length() > 512 {
        invalid("text cell too long")
      }
      Text(s)
    }
    True => Flag(true)
    False => Flag(false)
    Number(_, ..) => Integer(integer(v))
    _ => invalid("cells must be null, string, boolean or exact integer")
  }
}

///|
fn strings(v : Json, limit : Int32) -> Array[String] raise JoinError {
  array(v, limit).map(string)
}

///|
fn read_table(value : Json) -> Table raise JoinError {
  let f = object(value)
  only(f, ["name", "columns", "rows"])
  let columns = strings(required(f, "columns"), 64)
  let rows = []
  for value in array(required(f, "rows"), 10000) {
    let r = object(value)
    only(r, ["id", "values"])
    rows.push(Row::{
      id: string(required(r, "id")),
      values: array(required(r, "values"), 64).map(read_cell),
    })
  }
  let t = Table::{ name: string(required(f, "name")), columns, rows, }
  validate_table(t)
  t
}

///|
fn read_plan(value : Json) -> Plan raise JoinError {
  let f = object(value)
  only(f, [
    "kind", "keys", "nulls", "cardinality", "require_left", "require_right", "max_output",
  ])
  let keys = []
  for value in array(required(f, "keys"), 8) {
    let k = object(value)
    only(k, ["left", "right"])
    keys.push(KeyPair::{
      left: string(required(k, "left")),
      right: string(required(k, "right")),
    })
  }
  let max_output = match f.get("max_output") {
    Some(v) => integer(v)
    None => 10000
  }
  plan(
    keys,
    kind=optional_string(f, "kind", "inner"),
    nulls=optional_string(f, "nulls", "never"),
    cardinality=optional_string(f, "cardinality", "many_to_one"),
    require_left=optional_bool(f, "require_left", false),
    require_right=optional_bool(f, "require_right", false),
    max_output~,
  )
}

///|
fn read_witness(value : Json) -> Witness raise JoinError {
  let f = object(value)
  only(f, ["code", "scope", "key", "left_ids", "right_ids", "explanation"])
  {
    code: string(required(f, "code")),
    scope: string(required(f, "scope")),
    key: array(required(f, "key"), 8).map(read_cell),
    left_ids: strings(required(f, "left_ids"), 2),
    right_ids: strings(required(f, "right_ids"), 2),
    explanation: string(required(f, "explanation")),
  }
}

///|
priv struct Request {
  left : Table
  right : Table
  plan : Plan
  candidate : Plan?
  witness : Witness?
}

///|
fn request(source : String) -> Request raise JoinError {
  let f = object(parse_text(source))
  only(f, ["schema_version", "left", "right", "plan", "candidate", "witness"])
  if integer(required(f, "schema_version")) != 1 {
    invalid("unsupported schema_version")
  }
  let left = read_table(required(f, "left"))
  let right = read_table(required(f, "right"))
  let p = read_plan(required(f, "plan"))
  // Resolve columns even for metadata plans before any domain result is emitted.
  ignore(indexes(left, p.keys, true))
  ignore(indexes(right, p.keys, false))
  let candidate = match f.get("candidate") {
    Some(v) => {
      let c = read_plan(v)
      ignore(indexes(left, c.keys, true))
      ignore(indexes(right, c.keys, false))
      if p.nulls != c.nulls || p.kind != c.kind {
        invalid("candidate must use the same join kind and null semantics")
      }
      Some(c)
    }
    None => None
  }
  let witness = match f.get("witness") {
    Some(v) => Some(read_witness(v))
    None => None
  }
  { left, right, plan: p, candidate, witness, }
}

///|
/// Optional candidate is compared; optional witness is checked, never ignored.
pub fn inspect_json(source : String) -> String raise JoinError {
  let r = request(source)
  let out : Map[String, Json] = {
    "schema_version": Json::number(1),
    "audit": audit(r.left, r.right, r.plan).to_json(),
  }
  if r.candidate is Some(c) {
    out["comparison"] = compare(r.left, r.right, r.plan, c).to_json()
  }
  if r.witness is Some(w) {
    out["witness_valid"] = Json::boolean(
      verify_witness(r.left, r.right, r.plan, w),
    )
  }
  Json::object(out).stringify()
}

///|
/// This endpoint executes plan, or candidate only when explicitly selected.
pub fn materialize_json(
  source : String,
  use_candidate~ : Bool = false,
) -> String raise JoinError {
  let r = request(source)
  let p = if use_candidate {
    match r.candidate {
      Some(c) => c
      None => invalid("candidate not supplied")
    }
  } else {
    r.plan
  }
  if r.witness is Some(w) {
    if !verify_witness(r.left, r.right, r.plan, w) {
      invalid("supplied witness is invalid")
    }
  }
  let pairs = materialize(r.left, r.right, p)
  let out : Json = {
    "schema_version": 1,
    "selected": if use_candidate {
      "candidate"
    } else {
      "plan"
    },
    "pairs": @json.to_json(pairs),
  }
  out.stringify()
}

///|
/// Export a standalone, auditable three-row reproduction request.
pub fn export_case_json(
  source : String,
  index : Int32,
) -> String raise JoinError {
  let r = request(source)
  let report = audit(r.left, r.right, r.plan)
  if index < 0 || index >= report.witnesses.length() {
    invalid("witness index outside returned evidence")
  }
  let w = report.witnesses[index]
  let (left, right) = counterexample(r.left, r.right, r.plan, w)
  let out : Json = {
    "schema_version": 1,
    "left": left.to_json(),
    "right": right.to_json(),
    "plan": r.plan.to_json(),
    "witness": w.to_json(),
  }
  out.stringify()
}
