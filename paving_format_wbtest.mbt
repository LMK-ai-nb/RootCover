///|
test "JSON dispatch handles nonsquare constraints and preserves root compatibility" {
  let s = "{\"version\":1,\"mode\":\"feasibility\",\"variables\":[\"x\"],\"constraints\":[{\"expression\":\"x\",\"range\":[-2,2]},{\"expression\":\"x^2\",\"range\":[-1,2]}],\"box\":[[-1,1]]}"
  let q = decode_feasibility_request(s)
  let r = pave(q.model, q.box, q.options)
  assert_true(r.complete)
  assert_eq(r.inside.length(), 1)
  assert_true(solve_json(s).contains("\"mode\":\"feasibility\""))
  assert_true(
    solve_json(
      "{\"version\":1,\"variables\":[\"x\"],\"equations\":[\"x\"],\"box\":[[-1,1]]}",
    ).contains("\"mode\":\"roots\""),
  )
}

///|
test "feasibility mode rejects mixed modes malformed bands and duplicate keys" {
  let mut rejected = 0
  let base = "\"version\":1,\"mode\":\"feasibility\",\"variables\":[\"x\"],\"box\":[[-1,1]],"
  for
    s in [
      "{" + base + "\"constraints\":[{\"expression\":\"x\",\"range\":[2,1]}]}",
      "{" + base + "\"constraints\":[]}",
      "{" +
      base +
      "\"constraints\":[{\"expression\":\"x\",\"range\":[0,1]}],\"equations\":[\"x\"]}",
      "{" +
      base +
      "\"constraints\":[{\"expression\":\"x\",\"expression\":\"x^2\",\"range\":[0,1]}]}",
    ] {
    try {
      let _ = solve_json(s)
    } catch {
      _ => rejected = rejected + 1
    }
  }
  assert_eq(rejected, 4)
}
