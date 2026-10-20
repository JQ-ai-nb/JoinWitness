///|
priv struct Bucket {
  key : Array[Cell]
  ids : Array[String]
}

///|
pub(all) struct Inventory {
  left_rows : Int32
  right_rows : Int32
  matched_left : Int32
  matched_right : Int32
  matched_pairs : Int64
  output_rows : Int64
  unmatched_left : Array[String]
  unmatched_right : Array[String]
  excluded_null_left : Array[String]
  excluded_null_right : Array[String]
  groups : Array[Group]
} derive(Eq, ToJson)

///|
fn bucketize(
  t : Table,
  positions : Array[Int32],
  nulls : String,
) -> (Map[String, Bucket], Array[String]) {
  let buckets : Map[String, Bucket] = Map([])
  let excluded = []
  for row in t.rows {
    match key_of(row, positions, nulls) {
      None => excluded.push(row.id)
      Some(key) => {
        let token = encode_key(key)
        match buckets.get(token) {
          Some(b) => b.ids.push(row.id)
          None => buckets[token] = { key, ids: [row.id], }
        }
      }
    }
  }
  for _, b in buckets {
    b.ids.sort()
  }
  excluded.sort()
  (buckets, excluded)
}

///|
/// Count exact row multiplicities without constructing any result pairs.
pub fn inventory(
  left : Table,
  right : Table,
  p : Plan,
) -> Inventory raise JoinError {
  validate_table(left)
  validate_table(right)
  validate_plan(p)
  let li = indexes(left, p.keys, true)
  let ri = indexes(right, p.keys, false)
  inventory_keys(left, right, li, ri, p.nulls, p.kind)
}

///|
/// Internal positions may contain repeated columns when comparing two plans.
fn inventory_keys(
  left : Table,
  right : Table,
  li : Array[Int32],
  ri : Array[Int32],
  nulls : String,
  kind : String,
) -> Inventory {
  let (lb, ln) = bucketize(left, li, nulls)
  let (rb, rn) = bucketize(right, ri, nulls)
  let union : Map[String, Bool] = Map([])
  for token, _ in lb {
    union[token] = true
  }
  for token, _ in rb {
    union[token] = true
  }
  let tokens = []
  for token, _ in union {
    tokens.push(token)
  }
  tokens.sort()
  let groups = []
  let unmatched_left = ln.copy()
  let unmatched_right = rn.copy()
  let mut matched_pairs : Int64 = 0
  let mut matched_left = 0
  let mut matched_right = 0
  for token in tokens {
    let left_ids = match lb.get(token) {
      Some(b) => b.ids
      None => []
    }
    let right_ids = match rb.get(token) {
      Some(b) => b.ids
      None => []
    }
    let key = match (lb.get(token), rb.get(token)) {
      (Some(b), _) | (_, Some(b)) => b.key
      _ => abort("union key missing from both sides")
    }
    let pairs = left_ids.length().to_int64() * right_ids.length().to_int64()
    matched_pairs = matched_pairs + pairs
    if pairs > 0 {
      matched_left = matched_left + left_ids.length()
      matched_right = matched_right + right_ids.length()
    } else {
      for id in left_ids {
        unmatched_left.push(id)
      }
      for id in right_ids {
        unmatched_right.push(id)
      }
    }
    groups.push(Group::{ key, left_ids, right_ids, pairs, })
  }
  unmatched_left.sort()
  unmatched_right.sort()
  let output_rows = matched_pairs +
    (if kind == "left" || kind == "full" {
      unmatched_left.length().to_int64()
    } else {
      0
    }) +
    (if kind == "right" || kind == "full" {
      unmatched_right.length().to_int64()
    } else {
      0
    })
  {
    left_rows: left.rows.length(),
    right_rows: right.rows.length(),
    matched_left,
    matched_right,
    matched_pairs,
    output_rows,
    unmatched_left,
    unmatched_right,
    excluded_null_left: ln,
    excluded_null_right: rn,
    groups,
  }
}
