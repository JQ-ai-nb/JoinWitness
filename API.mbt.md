# Executable typed API

```mbt check
///|
test "documented typed counterexample and join inspection" {
  let left : @joinwitness.Table = {
    name: "orders",
    columns: ["customer"],
    rows: [{ id: "order-1", values: [@joinwitness.Integer(7)], }],
  }
  let right : @joinwitness.Table = {
    name: "customers",
    columns: ["customer"],
    rows: [
      { id: "customer-A", values: [@joinwitness.Integer(7)], },
      { id: "customer-B", values: [@joinwitness.Integer(7)], },
    ],
  }
  let plan = @joinwitness.plan([{ left: "customer", right: "customer", }])
  let report = @joinwitness.audit(left, right, plan)
  assert_eq(report.inventory.output_rows, 2L)
  assert_true(!report.safe)
  let witness = report.witnesses[0]
  assert_true(@joinwitness.verify_witness(left, right, plan, witness))
  let (small_left, small_right) = @joinwitness.counterexample(
    left, right, plan, witness,
  )
  assert_eq(small_left.rows.length() + small_right.rows.length(), 3)
}
```
