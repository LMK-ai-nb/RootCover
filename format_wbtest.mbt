///|
test "strict JSON request runs through the shared typed core" {
  let q = decode_request(
    "{\"version\":1,\"variables\":[\"x\"],\"equations\":[\"x^2-4\"],\"box\":[[-3,3]]}",
  )
  let r = solve(q.system, q.box, q.options)
  assert_true(r.complete)
  assert_eq(r.roots.length(), 2)
  assert_true(
    solve_json(
      "{\"version\":1,\"variables\":[\"x\"],\"equations\":[\"x^2+1\"],\"box\":[[-3,3]]}",
    ).contains("\"root_count\":0"),
  )
}

///|
test "decoded duplicate keys and fractional budget spelling are rejected" {
  let base = "\"variables\":[\"x\"],\"equations\":[\"x\"],\"box\":[[-1,1]]"
  let mut rejected = 0
  for
    s in [
      "{\"version\":1,\"version\":1," + base + "}",
      "{\"version\":1,\"\\u0076ersion\":1," + base + "}",
      "{\"version\":1," +
      base +
      ",\"options\":{\"max_assessments\":10.0000000000000001}}",
      "{\"version\":1," + base + ",\"options\":{\"max_assessments\":1e2}}",
      "{\"version\":1," + base + ",\"typo\":1}",
    ] {
    try {
      let _ = decode_request(s)
    } catch {
      _ => rejected = rejected + 1
    }
  }
  assert_eq(rejected, 5)
}
