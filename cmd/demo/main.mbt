///|
fn main {
  let l : @join.Table = {
    name: "orders",
    columns: ["customer", "tenant"],
    rows: [
      { id: "order-A", values: [@join.Integer(7), @join.Text("A")], },
      { id: "order-B", values: [@join.Integer(7), @join.Text("B")], },
    ],
  }
  let r : @join.Table = {
    name: "customers",
    columns: ["customer", "tenant"],
    rows: [
      { id: "customer-A", values: [@join.Integer(7), @join.Text("A")], },
      { id: "customer-B", values: [@join.Integer(7), @join.Text("B")], },
    ],
  }
  let base = @join.plan(
    [{ left: "customer", right: "customer", }],
    require_left=true,
  ) catch {
    _ => abort("bad plan")
  }
  let candidate = @join.plan(
    [
      { left: "customer", right: "customer", },
      { left: "tenant", right: "tenant", },
    ],
    require_left=true,
  ) catch {
    _ => abort("bad candidate")
  }
  let result = @join.compare(l, r, base, candidate) catch {
    _ => abort("comparison failed")
  }
  println(
    "baseline pairs=\{result.baseline.inventory.matched_pairs}; candidate=\{result.candidate.inventory.matched_pairs}",
  )
  println(
    "retained=\{result.retained_pairs}, lost=\{result.lost_pairs}, gained=\{result.gained_pairs}",
  )
  let witness = result.baseline.witnesses[0]
  let (a, b) = @join.counterexample(l, r, base, witness) catch {
    _ => abort("cannot export witness")
  }
  println(
    "counterexample rows=\{a.rows.length()+b.rows.length()}; independently verified=\{@join.verify_witness(l,r,base,witness) catch {_=>false}}",
  )
  let output = @join.materialize(l, r, candidate) catch {
    _ => abort("safe materialization failed")
  }
  println("safe materialized pairs=\{output.length()}")
}
