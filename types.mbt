///|
/// Deliberately exact cells. No implicit string/number/bool coercion.
pub(all) enum Cell {
  NullCell
  Text(String)
  Integer(Int32)
  Flag(Bool)
} derive(Eq)

///|
pub(all) struct Row {
  id : String
  values : Array[Cell]
} derive(Eq, ToJson)

///|
/// Columns are an ordered schema; every row has exactly that width.
pub(all) struct Table {
  name : String
  columns : Array[String]
  rows : Array[Row]
} derive(Eq, ToJson)

///|
pub(all) struct KeyPair {
  left : String
  right : String
} derive(Eq, ToJson)

///|
/// Contracts concern matched keys; coverage is checked separately.
pub(all) struct Plan {
  kind : String
  keys : Array[KeyPair]
  nulls : String
  cardinality : String
  require_left : Bool
  require_right : Bool
  max_output : Int32
} derive(Eq, ToJson)

///|
/// Buckets include unmatched non-null keys. Null-ineligible rows are separate.
pub(all) struct Group {
  key : Array[Cell]
  left_ids : Array[String]
  right_ids : Array[String]
  pairs : Int64
} derive(Eq, ToJson)

///|
/// Multiplicity witnesses use three rows; absence witnesses require full input.
pub(all) struct Witness {
  code : String
  scope : String
  key : Array[Cell]
  left_ids : Array[String]
  right_ids : Array[String]
  explanation : String
} derive(Eq, ToJson)

///|
pub(all) suberror JoinError {
  JoinError(String)
} derive(Eq)

///|
fn[T] invalid(message : String) -> T raise JoinError {
  raise JoinError(message)
}

///|
pub impl ToJson for Cell with fn to_json(self) {
  match self {
    NullCell => Json::null()
    Text(s) => Json::string(s)
    Integer(n) => Json::number(n.to_double())
    Flag(b) => Json::boolean(b)
  }
}

///|
pub fn plan(
  keys : Array[KeyPair],
  kind~ : String = "inner",
  nulls~ : String = "never",
  cardinality~ : String = "many_to_one",
  require_left~ : Bool = false,
  require_right~ : Bool = false,
  max_output~ : Int32 = 10000,
) -> Plan raise JoinError {
  let p = {
    keys: keys.copy(),
    kind,
    nulls,
    cardinality,
    require_left,
    require_right,
    max_output,
  }
  validate_plan(p)
  p
}

///|
fn validate_label(s : String) -> Unit raise JoinError {
  if s.length() < 1 || s.length() > 128 {
    invalid("names and IDs require 1..128 UTF-16 units")
  }
}

///|
fn validate_plan(p : Plan) -> Unit raise JoinError {
  if !["inner", "left", "right", "full"].contains(p.kind) {
    invalid("unknown join kind")
  }
  if !["never", "equal"].contains(p.nulls) {
    invalid("nulls must be never or equal")
  }
  if !["one_to_one", "many_to_one", "one_to_many", "many_to_many"].contains(
      p.cardinality,
    ) {
    invalid("unknown cardinality contract")
  }
  if p.keys.length() < 1 || p.keys.length() > 8 {
    invalid("join requires 1..8 key pairs")
  }
  if p.max_output < 0 || p.max_output > 20000 {
    invalid("max_output must be in 0..20000")
  }
  let left : Map[String, Bool] = Map([])
  let right : Map[String, Bool] = Map([])
  for k in p.keys {
    validate_label(k.left)
    validate_label(k.right)
    if left.contains(k.left) || right.contains(k.right) {
      invalid("a join key cannot repeat a column on either side")
    }
    left[k.left] = true
    right[k.right] = true
  }
}

///|
pub fn validate_table(t : Table) -> Unit raise JoinError {
  validate_label(t.name)
  if t.columns.length() < 1 || t.columns.length() > 64 {
    invalid("table requires 1..64 columns")
  }
  if t.rows.length() > 10000 {
    invalid("table row limit is 10000")
  }
  let columns : Map[String, Bool] = Map([])
  for name in t.columns {
    validate_label(name)
    if columns.contains(name) {
      invalid("duplicate column name")
    }
    columns[name] = true
  }
  let ids : Map[String, Bool] = Map([])
  let mut units = 0
  for row in t.rows {
    validate_label(row.id)
    if ids.contains(row.id) {
      invalid("duplicate row ID within table")
    }
    ids[row.id] = true
    if row.values.length() != t.columns.length() {
      invalid("row width differs from table schema")
    }
    for cell in row.values {
      match cell {
        Text(s) => {
          if s.length() > 512 {
            invalid("text cell exceeds 512 UTF-16 units")
          }
          units = units + s.length()
        }
        Integer(n) =>
          if n < -1000000000 || n > 1000000000 {
            invalid("integer cell outside +/-1000000000")
          }
        _ => ()
      }
    }
    if units > 2097152 {
      invalid("table text exceeds 2 Mi UTF-16 units")
    }
  }
}

///|
fn indexes(
  t : Table,
  keys : Array[KeyPair],
  is_left : Bool,
) -> Array[Int32] raise JoinError {
  let result = []
  for key in keys {
    let name = if is_left { key.left } else { key.right }
    let mut found = -1
    for i, column in t.columns {
      if column == name {
        found = i
      }
    }
    if found < 0 {
      invalid("join key column absent from schema")
    }
    result.push(found)
  }
  result
}

///|
/// JSON arrays provide an injective typed tuple encoding, not delimiter joins.
fn key_of(row : Row, positions : Array[Int32], nulls : String) -> Array[Cell]? {
  let result = []
  for pos in positions {
    let cell = row.values[pos]
    if nulls == "never" && cell == NullCell {
      return None
    }
    result.push(cell)
  }
  Some(result)
}

///|
pub fn encode_key(key : Array[Cell]) -> String {
  @json.to_json(key).stringify()
}

///|
/// Explain the exact eligibility/key of one source row under a validated plan.
pub fn row_key(
  t : Table,
  row_id : String,
  p : Plan,
  is_left : Bool,
) -> Array[Cell]? raise JoinError {
  validate_table(t)
  validate_plan(p)
  let positions = indexes(t, p.keys, is_left)
  for row in t.rows {
    if row.id == row_id {
      return key_of(row, positions, p.nulls)
    }
  }
  invalid("row ID not present in supplied table")
}
