///|
test "two simple roots are both enclosed without enumerating starting guesses" {
  let s = { names: ["x"], equations: [Sub(Pow(Variable(0), 2), Const(4.0))], }
  let r = solve(s, [interval(-3.0, 3.0)], default_options())
  assert_true(r.complete)
  assert_true(r.tolerance_met)
  assert_eq(r.roots.length(), 2)
  assert_true(r.roots.any(b => b.enclosure[0].contains(-2.0)))
  assert_true(r.roots.any(b => b.enclosure[0].contains(2.0)))
}

///|
test "a no-root region can be completely excluded" {
  let r = solve(
    { names: ["x"], equations: [Add(Pow(Variable(0), 2), Const(1.0))], },
    [interval(-8.0, 8.0)],
    default_options(),
  )
  assert_true(r.complete)
  assert_eq(r.roots.length(), 0)
  assert_eq(r.unresolved.length(), 0)
}

///|
test "budget exhaustion returns unresolved coverage rather than complete" {
  let o = { tolerance: 0.00000001, max_assessments: 1, max_depth: 60, }
  let r = solve(
    { names: ["x"], equations: [Sub(Pow(Variable(0), 2), Const(4.0))], },
    [interval(-3.0, 3.0)],
    o,
  )
  assert_false(r.complete)
  assert_eq(r.unresolved.length(), 2)
  assert_eq(r.assessments, 1)
  assert_true(r.unresolved[0].box[0].contains(0.0))
}

///|
test "singular roots and boundary roots remain explicitly unresolved" {
  let o = { tolerance: 0.00001, max_assessments: 1000, max_depth: 30, }
  let r = solve(
    { names: ["x"], equations: [Pow(Variable(0), 2)], },
    [interval(-1.0, 1.0)],
    o,
  )
  assert_false(r.complete)
  assert_eq(r.roots.length(), 0)
  assert_true(r.unresolved.any(b => b.box[0].contains(0.0)))
  let r = solve(
    { names: ["x"], equations: [Variable(0)], },
    [interval(0.0, 1.0)],
    o,
  )
  assert_false(r.complete)
  assert_true(r.unresolved.any(b => b.box[0].contains(0.0)))
}

///|
test "geometric intersection solves a coupled two dimensional system" {
  let x = Variable(0)
  let y = Variable(1)
  let s = {
    names: ["x", "y"],
    equations: [Sub(Add(Pow(x, 2), Pow(y, 2)), Const(2.0)), Sub(y, x)],
  }
  let r = solve(
    s,
    [interval(-1.5, 1.5), interval(-1.5, 1.5)],
    default_options(),
  )
  assert_true(r.complete)
  assert_eq(r.roots.length(), 2)
  for a in [-1.0, 1.0] {
    assert_true(
      r.roots.any(b => b.enclosure[0].contains(a) && b.enclosure[1].contains(a)),
    )
  }
}
