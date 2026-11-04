///|
test "whole feasible and infeasible boxes are classified independently of midpoints" {
  let model = {
    names: ["x"],
    constraints: [{ polynomial: Variable(0), allowed: interval(-1.0, 1.0), }],
  }
  match classify_constraints(model, [interval(-0.5, 0.5)]) {
    Inside(_) => ()
    _ => fail("whole box should be feasible")
  }
  match classify_constraints(model, [interval(2.0, 3.0)]) {
    Outside(_) => ()
    _ => fail("whole box should be outside")
  }
  match classify_constraints(model, [interval(-2.0, 2.0)]) {
    Indeterminate => ()
    _ => fail("feasible midpoint cannot certify the whole box")
  }
}

///|
test "paving separates tolerance bands and preserves possible solutions" {
  let model = {
    names: ["x"],
    constraints: [
      { polynomial: Pow(Variable(0), 2), allowed: interval(0.75, 1.25), },
    ],
  }
  let r = pave(model, [interval(-2.0, 2.0)], {
    tolerance: 0.01,
    max_assessments: 4096,
    max_depth: 60,
  })
  assert_false(r.complete)
  assert_true(r.resolution_met)
  assert_true(r.inside.length() > 0)
  for x in [-1.0, 1.0] {
    assert_true(
      r.inside.any(b => b.box[0].contains(x)) ||
      r.unresolved.any(b => b.box[0].contains(x)),
    )
  }
  for b in r.inside {
    assert_true(b.ranges[0].lo >= 0.75 && b.ranges[0].hi <= 1.25)
  }
}

///|
test "budget and depth limitations retain unresolved outer coverage" {
  let m = {
    names: ["x"],
    constraints: [{ polynomial: Variable(0), allowed: interval(-0.25, 0.25), }],
  }
  let r = pave(m, [interval(-1.0, 1.0)], {
    tolerance: 0.00001,
    max_assessments: 1,
    max_depth: 60,
  })
  assert_false(r.complete)
  assert_false(r.resolution_met)
  assert_eq(r.assessments, 1)
  assert_eq(r.unresolved.length(), 2)
  assert_true(r.unresolved.any(b => b.box[0].contains(0.0)))
  let d = pave(m, [interval(-1.0, 1.0)], {
    tolerance: 0.00001,
    max_assessments: 100,
    max_depth: 1,
  })
  assert_false(d.complete)
  assert_true(d.unresolved.any(b => b.reason.contains("depth")))
}

///|
test "overdetermined inconsistent measurements can be proven empty" {
  let x = Variable(0)
  let m = {
    names: ["x"],
    constraints: [
      { polynomial: x, allowed: interval(0.5, 1.0), },
      { polynomial: x, allowed: interval(-1.0, -0.5), },
    ],
  }
  let r = pave(m, [interval(-1.5, 1.5)], default_options())
  assert_true(r.complete)
  assert_eq(r.inside.length(), 0)
}

///|
test "overflow is conservative and input model is not mutated" {
  let box = [interval(1.0, 2.0)]
  let model = {
    names: ["x"],
    constraints: [
      {
        polynomial: Mul(Const(@double.max_value), Variable(0)),
        allowed: interval(-1.0, 1.0),
      },
    ],
  }
  let r = pave(model, box, default_options())
  assert_true(r.complete)
  assert_eq(r.inside.length(), 0)
  assert_eq(box[0].lo, 1.0)
  assert_eq(box[0].hi, 2.0)
}

///|
test "invalid constraint ranges are rejected" {
  let model = {
    names: ["x"],
    constraints: [{ polynomial: Variable(0), allowed: { lo: 2.0, hi: 1.0, }, }],
  }
  let mut rejected = false
  validate_constraints(model) catch {
    _ => rejected = true
  }
  assert_true(rejected)
}
