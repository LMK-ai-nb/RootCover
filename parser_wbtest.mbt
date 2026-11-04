///|
test "polynomial grammar handles unary precedence and scientific literals" {
  let e = parse_polynomial("-x^2 + 2*x - (1e-2)", ["x"])
  let v = enclose({ names: ["x"], equations: [e], }, [interval(3.0, 3.0)])
  assert_true(v.ranges[0].contains(-3.01))
}

///|
test "ambiguous or unsupported syntax is rejected" {
  let mut rejected = 0
  for
    s in [
      "sin(x)", "x/2", "2x", "x^17", "x^-1", "y+1", "x^2^3", "01+x", "1e999+x", "(x+1",
    ] {
    try {
      let _ = parse_polynomial(s, ["x"])
    } catch {
      _ => rejected = rejected + 1
    }
  }
  assert_eq(rejected, 10)
}

///|
test "parser stops adversarial nesting before stack exhaustion" {
  let mut s = "x"
  for _ in 0..<40 {
    s = "(" + s + ")"
  }
  let mut rejected = false
  try {
    let _ = parse_polynomial(s, ["x"])
  } catch {
    _ => rejected = true
  }
  assert_true(rejected)
}
