///|
test "interval automatic Jacobian encloses analytic derivatives" {
  let x = Variable(0)
  let y = Variable(1)
  let system = {
    names: ["x", "y"],
    equations: [Sub(Add(Pow(x, 2), Pow(y, 2)), Const(5.0)), Sub(x, y)],
  }
  let r = enclose(system, [interval(1.0, 2.0), interval(1.0, 3.0)])
  assert_true(r.ranges[0].contains(-3.0))
  assert_true(r.ranges[0].contains(8.0))
  assert_true(r.jacobian[0][0].contains(2.0))
  assert_true(r.jacobian[0][0].contains(4.0))
  assert_true(r.jacobian[0][1].contains(6.0))
  assert_true(r.jacobian[1][0].contains(1.0))
  assert_true(r.jacobian[1][1].contains(-1.0))
}

///|
test "constant and zero powers have zero derivative" {
  let r = enclose({ names: ["x"], equations: [Pow(Variable(0), 0)], }, [
    interval(-3.0, 2.0),
  ])
  assert_true(r.ranges[0].contains(1.0))
  assert_true(r.jacobian[0][0].contains(0.0))
}

///|
test "invalid systems fail before evaluation" {
  let mut rejected = 0
  for
    system in [
      { names: ["x"], equations: [Variable(1)], },
      { names: ["x", "x"], equations: [Const(0.0), Const(0.0)], },
      { names: ["x"], equations: [Pow(Variable(0), 17)], },
      { names: ["x"], equations: [Const(@double.infinity)], },
    ] {
    validate_system(system) catch {
      _ => rejected = rejected + 1
    }
  }
  assert_eq(rejected, 4)
}
