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

///|
test "asymmetric partition avoids artificial boundary roots in three dimensions" {
  let pairs = [(-2.5, 3.25), (-3.25, 3.75), (-1.5, 0.5)]
  let system = {
    names: ["a", "b", "c"],
    equations: Array::makei(3, i => {
      Mul(
        Sub(Variable(i), Const(pairs[i].0)),
        Sub(Variable(i), Const(pairs[i].1)),
      )
    }),
  }
  let r = solve(
    system,
    [interval(-3.5, 4.25), interval(-4.25, 4.75), interval(-2.5, 1.5)],
    default_options(),
  )
  assert_true(r.complete)
  assert_eq(r.roots.length(), 8)
}

///|
test "six coupled nonlinear equations cover all sixty-four analytic roots" {
  let equations = Array::makei(6, i => {
    let a = Sub(Pow(Variable(i), 2), Const(1.0))
    let b = Sub(Pow(Variable((i + 1) % 6), 2), Const(1.0))
    Add(a, Mul(Const(0.03125), b))
  })
  let s = { names: ["a", "b", "c", "d", "e", "f"], equations, }
  let r = solve(s, Array::make(6, interval(-1.5, 1.5)), {
    tolerance: 0.0000001,
    max_assessments: 20000,
    max_depth: 60,
  })
  assert_true(r.complete)
  assert_eq(r.roots.length(), 64)
  for mask in 0..<64 {
    assert_true(
      r.roots.any(b => {
        let mut found = true
        for j in 0..<6 {
          let x = if (mask >> j) % 2 == 0 { -1.0 } else { 1.0 }
          if !b.enclosure[j].contains(x) {
            found = false
          }
        }
        found
      }),
    )
  }
}
