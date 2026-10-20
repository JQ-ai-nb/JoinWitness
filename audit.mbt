///|
pub(all) struct Audit {
  schema_version : Int32
  plan : Plan
  inventory : Inventory
  left_multiplicity_groups : Int32
  right_multiplicity_groups : Int32
  issue_count : Int32
  safe : Bool
  witnesses : Array[Witness]
  witnesses_omitted : Int32
} derive(ToJson)

///|
fn row_index(t : Table) -> Map[String, Row] {
  let result : Map[String, Row] = Map([])
  for row in t.rows {
    result[row.id] = row
  }
  result
}

///|
fn evidence(
  out : Array[Witness],
  code : String,
  scope : String,
  key : Array[Cell],
  left_ids : Array[String],
  right_ids : Array[String],
  explanation : String,
) -> Unit {
  if out.length() < 128 {
    out.push({ code, scope, key, left_ids, right_ids, explanation, })
  }
}

///|
/// Preflight every contract, while returning at most 128 explicit witnesses.
pub fn audit(left : Table, right : Table, p : Plan) -> Audit raise JoinError {
  let inv = inventory(left, right, p)
  let witnesses = []
  let mut issues = 0
  let mut left_bad = 0
  let mut right_bad = 0
  for group in inv.groups {
    if group.pairs == 0 {
      continue
    }
    if group.left_ids.length() > 1 &&
      ["one_to_one", "one_to_many"].contains(p.cardinality) {
      left_bad = left_bad + 1
      issues = issues + 1
      evidence(
        witnesses,
        "LEFT_MULTIPLICITY",
        "constructive",
        group.key.copy(),
        [group.left_ids[0], group.left_ids[1]],
        [group.right_ids[0]],
        "Two left facts match the same right fact; three rows reproduce the violation.",
      )
    }
    if group.right_ids.length() > 1 &&
      ["one_to_one", "many_to_one"].contains(p.cardinality) {
      right_bad = right_bad + 1
      issues = issues + 1
      evidence(
        witnesses,
        "RIGHT_MULTIPLICITY",
        "constructive",
        group.key.copy(),
        [group.left_ids[0]],
        [group.right_ids[0], group.right_ids[1]],
        "One left fact matches two right facts; three rows reproduce the violation.",
      )
    }
  }
  let li = indexes(left, p.keys, true)
  let ri = indexes(right, p.keys, false)
  let lr = row_index(left)
  let rr = row_index(right)
  if p.require_left {
    for id in inv.unmatched_left {
      issues = issues + 1
      let key = match key_of(lr[id], li, "equal") {
        Some(k) => k
        None => abort("null-safe projection must produce a key")
      }
      evidence(
        witnesses,
        "MISSING_RIGHT",
        "full_input_absence",
        key,
        [id],
        [],
        "This left fact has no eligible matching partner in the complete right table.",
      )
    }
  }
  if p.require_right {
    for id in inv.unmatched_right {
      issues = issues + 1
      let key = match key_of(rr[id], ri, "equal") {
        Some(k) => k
        None => abort("null-safe projection must produce a key")
      }
      evidence(
        witnesses,
        "MISSING_LEFT",
        "full_input_absence",
        key,
        [],
        [id],
        "This right fact has no eligible matching partner in the complete left table.",
      )
    }
  }
  if inv.output_rows > p.max_output.to_int64() {
    issues = issues + 1
    evidence(
      witnesses,
      "OUTPUT_BUDGET",
      "full_input",
      [],
      [],
      [],
      "Exact output cardinality exceeds the declared materialization budget.",
    )
  }
  {
    schema_version: 1,
    plan: { ..p, keys: p.keys.copy(), },
    inventory: inv,
    left_multiplicity_groups: left_bad,
    right_multiplicity_groups: right_bad,
    issue_count: issues,
    safe: issues == 0,
    witnesses_omitted: issues - witnesses.length(),
    witnesses,
  }
}

///|
fn selected(t : Table, ids : Array[String]) -> Array[Row]? {
  let lookup = row_index(t)
  let rows = []
  let seen : Map[String, Bool] = Map([])
  for id in ids {
    if seen.contains(id) {
      return None
    }
    seen[id] = true
    match lookup.get(id) {
      Some(row) => rows.push(row)
      None => return None
    }
  }
  Some(rows)
}

///|
fn compatible(
  a : Row,
  b : Row,
  li : Array[Int32],
  ri : Array[Int32],
  nulls : String,
) -> Bool {
  match (key_of(a, li, nulls), key_of(b, ri, nulls)) {
    (Some(x), Some(y)) => x == y
    _ => false
  }
}

///|
/// Recheck claimed evidence against the supplied complete source tables.
/// Explanation prose is not authenticated; only code/scope/keys/row IDs are facts.
pub fn verify_witness(
  left : Table,
  right : Table,
  p : Plan,
  w : Witness,
) -> Bool raise JoinError {
  validate_table(left)
  validate_table(right)
  validate_plan(p)
  let li = indexes(left, p.keys, true)
  let ri = indexes(right, p.keys, false)
  let ls = match selected(left, w.left_ids) {
    Some(rows) => rows
    None => return false
  }
  let rs = match selected(right, w.right_ids) {
    Some(rows) => rows
    None => return false
  }
  match w.code {
    "LEFT_MULTIPLICITY" | "RIGHT_MULTIPLICITY" => {
      if w.scope != "constructive" {
        return false
      }
      if w.code == "LEFT_MULTIPLICITY" {
        if !["one_to_one", "one_to_many"].contains(p.cardinality) ||
          ls.length() != 2 ||
          rs.length() != 1 {
          return false
        }
      } else if !["one_to_one", "many_to_one"].contains(p.cardinality) ||
        ls.length() != 1 ||
        rs.length() != 2 {
        return false
      }
      for l in ls {
        if key_of(l, li, p.nulls) != Some(w.key) {
          return false
        }
        for r in rs {
          if !compatible(l, r, li, ri, p.nulls) {
            return false
          }
        }
      }
      true
    }
    "MISSING_RIGHT" => {
      if w.scope != "full_input_absence" ||
        !p.require_left ||
        ls.length() != 1 ||
        rs.length() != 0 {
        return false
      }
      if key_of(ls[0], li, "equal") != Some(w.key) {
        return false
      }
      !right.rows.any(r => compatible(ls[0], r, li, ri, p.nulls))
    }
    "MISSING_LEFT" => {
      if w.scope != "full_input_absence" ||
        !p.require_right ||
        rs.length() != 1 ||
        ls.length() != 0 {
        return false
      }
      if key_of(rs[0], ri, "equal") != Some(w.key) {
        return false
      }
      !left.rows.any(l => compatible(l, rs[0], li, ri, p.nulls))
    }
    "OUTPUT_BUDGET" =>
      w.scope == "full_input" &&
      w.key.length() == 0 &&
      ls.length() == 0 &&
      rs.length() == 0 &&
      inventory(left, right, p).output_rows > p.max_output.to_int64()
    _ => false
  }
}

///|
/// Export a complete three-row reproducer; absence cannot use this mechanism.
pub fn counterexample(
  left : Table,
  right : Table,
  p : Plan,
  w : Witness,
) -> (Table, Table) raise JoinError {
  if w.scope != "constructive" || !verify_witness(left, right, p, w) {
    invalid(
      "only valid constructive multiplicity witnesses have three-row reproducers",
    )
  }
  let ls = match selected(left, w.left_ids) {
    Some(rows) => rows
    None => abort("verified IDs disappeared")
  }
  let rs = match selected(right, w.right_ids) {
    Some(rows) => rows
    None => abort("verified IDs disappeared")
  }
  (
    {
      ..left,
      columns: left.columns.copy(),
      rows: ls.map(r => { ..r, values: r.values.copy(), }),
    },
    {
      ..right,
      columns: right.columns.copy(),
      rows: rs.map(r => { ..r, values: r.values.copy(), }),
    },
  )
}
