///|
fn error_json(message : String) -> String {
  let v : Json = {
    "schema_version": 1,
    "error": { "code": "INVALID_OR_UNSAFE", "message": message },
  }
  v.stringify()
}

///|
pub fn inspect(source : String) -> String {
  @join.inspect_json(source) catch {
    @join.JoinError(message) => error_json(message)
  }
}

///|
pub fn pairs(source : String) -> String {
  @join.materialize_json(source) catch {
    @join.JoinError(message) => error_json(message)
  }
}

///|
pub fn candidate_pairs(source : String) -> String {
  @join.materialize_json(source, use_candidate=true) catch {
    @join.JoinError(message) => error_json(message)
  }
}

///|
pub fn export_case(source : String, index : Double) -> String {
  if index != index ||
    index < 0 ||
    index > 127 ||
    index != index.to_int().to_double() {
    return error_json("witness index must be an integer in 0..127")
  }
  @join.export_case_json(source, index.to_int()) catch {
    @join.JoinError(message) => error_json(message)
  }
}
