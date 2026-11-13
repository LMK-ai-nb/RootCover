///|
test "elementary interval bounds include extrema and exclude invalid domains" {
  let s = elementary(Sin, interval(-4.0, 4.0))
  assert_eq(s.range.unwrap(), interval(-1.0, 1.0))
  assert_true(s.fully_defined && s.smooth)
  assert_true(elementary(Cos, interval(-0.2, 0.3)).range.unwrap().contains(1.0))
  assert_true(elementary(Log, interval(-3.0, 0.0)).range is None)
  let partial = elementary(Log, interval(-1.0, 2.0))
  assert_false(partial.fully_defined)
  assert_true(partial.range.unwrap().hi > 0.69)
  assert_true(elementary(Sqrt, interval(-1.0, -0.1)).range is None)
  assert_false(elementary(Sqrt, interval(0.0, 1.0)).smooth)
  assert_false(elementary(Tan, interval(1.4, 1.7)).fully_defined)
  assert_true(elementary(Asin, interval(1.1, 2.0)).range is None)
}

///|
test "series bounds and bit-search square root handle extremes" {
  assert_eq(elementary(Exp, point(0.0)).range.unwrap(), point(1.0))
  assert_eq(elementary(Log, point(1.0)).range.unwrap(), point(0.0))
  let root = elementary(Sqrt, point(1L.reinterpret_as_double())).range.unwrap()
  assert_true(root.lo > 2.0e-162 && root.hi < 2.3e-162)
  assert_false(elementary(Exp, point(2000.0)).range.unwrap().lo.is_inf())
  assert_true(elementary(Exp, point(-2000.0)).range.unwrap().contains(0.0))
  assert_eq(
    elementary(Sin, interval(1.0e12, 1.0e12)).range.unwrap(),
    interval(-1.0, 1.0),
  )
  assert_true(elementary(Atan, interval(-10.0, 10.0)).range.unwrap().lo < -1.47)
}

///|
test "extended grammar retains polynomial compatibility and rejects arbitrary calls" {
  let e = parse_expression("exp(x) + log(y) + sin(x*y) + sqrt(y) + x^-2", [
    "x", "y",
  ])
  let r = evaluate_expression(e, [point(1.0), point(4.0)])
  assert_true(r.fully_defined && r.smooth)
  let mut rejected = 0
  for s in ["eval(x)", "sin(x,y)", "x^0.5", "2x", "sin()"] {
    try {
      let _ = parse_expression(s, ["x"])
    } catch {
      _ => rejected = rejected + 1
    }
  }
  assert_eq(rejected, 5)
}

///|
test "interval Newton contracts a nonsingular system and preserves input" {
  let system = { names: ["x"], equations: [parse_expression("x^2-2", ["x"])], }
  let initial = [interval(1.0, 2.0)]
  let result = interval_newton(system, initial)
  let box = result.box.unwrap()
  assert_true(box[0].contains(1.4142135623730951))
  assert_true(box[0].width() < 0.000001)
  assert_true(result.calls > 0 && result.changed)
  assert_eq(initial[0], interval(1.0, 2.0))
}

///|
test "HC4 agenda propagates through twelve variables beyond the former dimension limit" {
  let names = Array::makei(12, i => "v\{i}")
  let constraints = [{ polynomial: Variable(11), allowed: point(0.5), }]
  for i = 10; i >= 0; i = i - 1 {
    constraints.push({
      polynomial: Sub(Variable(i), Variable(i + 1)),
      allowed: point(1.0),
    })
  }
  let model = { names, constraints, }
  let result = contract_constraints(
    model,
    Array::make(12, interval(-20.0, 20.0)),
    { propagation: true, newton: false, max_steps: 1024, max_rounds: 4, },
  )
  let box = result.box.unwrap()
  for i = 0; i < 12; i = i + 1 {
    assert_true(box[i].contains((11 - i).to_double() + 0.5))
    assert_true(box[i].width() < 0.000001)
  }
}

///|
test "periodic inverse propagation preserves every branch" {
  let model = {
    names: ["x"],
    constraints: [{ polynomial: Apply(Sin, Variable(0)), allowed: point(0.0), }],
  }
  let r = contract_constraints(model, [interval(-10.0, 10.0)], {
    propagation: true,
    newton: false,
    max_steps: 20,
    max_rounds: 2,
  })
  let box = r.box.unwrap()
  for k = -3; k <= 3; k = k + 1 {
    assert_true(box[0].contains(k.to_double() * 3.141592653589793))
  }
}

///|
test "domain crossing is not certified feasible or uniquely solvable" {
  let model = {
    names: ["x"],
    constraints: [
      { polynomial: parse_expression("0/x", ["x"]), allowed: point(0.0), },
    ],
  }
  assert_true(
    classify_constraints(model, [interval(-1.0, 1.0)]) is Indeterminate,
  )
  assert_true(classify_constraints(model, [point(0.0)]) is Outside(_))
  assert_true(
    assess({ names: ["x"], equations: [parse_expression("abs(x)", ["x"])], }, [
      interval(-1.0, 1.0),
    ])
    is Undecided(_),
  )
  let roots = solve(
    { names: ["x"], equations: [parse_expression("log(x)", ["x"])], },
    [interval(-2.0, 2.0)],
    default_options(),
  )
  assert_true(roots.complete)
  assert_eq(roots.roots.length(), 1)
  assert_true(roots.roots[0].enclosure[0].contains(1.0))
}

///|
test "a spent propagation budget does not masquerade as a fixed point" {
  let model = {
    names: ["x"],
    constraints: [
      { polynomial: Variable(0), allowed: interval(-2.0, 2.0), },
      { polynomial: Variable(0), allowed: interval(0.5, 1.0), },
    ],
  }
  let r = contract_constraints(model, [interval(-1.0, 1.0)], {
    propagation: true,
    newton: false,
    max_steps: 1,
    max_rounds: 4,
  })
  assert_false(r.fixed_point)
  assert_true(r.budget_exhausted)
  assert_eq(r.box.unwrap()[0], interval(-1.0, 1.0))
}

///|
test "mixed nonlinear equalities inequalities and observation bands parse strictly" {
  let q = decode_feasibility_request(
    "{\"version\":1,\"mode\":\"feasibility\",\"variables\":[\"x\"],\"constraints\":[{\"expression\":\"exp(x)\",\"relation\":\"<=\",\"rhs\":2},{\"expression\":\"x\",\"range\":[null,1]}],\"box\":[[-2,2]],\"contractors\":{\"newton\":false}}",
  )
  assert_false(q.contractors.newton)
  assert_true(q.model.constraints[0].allowed.lo.is_neg_inf())
  let r = pave_with_contractors(q.model, q.box, q.options, q.contractors)
  assert_true(r.inside.length() > 0)
  assert_true(r.contractions > 0)
}

///|
test "a cyclic propagation agenda cannot starve the joint Newton phase" {
  let model = {
    names: ["x", "y"],
    constraints: [
      {
        polynomial: parse_expression("x^2+y^2", ["x", "y"]),
        allowed: interval(1.9, 2.1),
      },
      { polynomial: parse_expression("x-y", ["x", "y"]), allowed: point(0.0), },
    ],
  }
  let r = contract_constraints(
    model,
    [interval(0.5, 2.0), interval(0.5, 2.0)],
    { propagation: true, newton: true, max_steps: 40, max_rounds: 4, },
  )
  assert_true(r.propagation_calls > 0 && r.newton_calls > 0)
  assert_eq(r.calls, r.propagation_calls + r.newton_calls)
  assert_true(r.box.unwrap().all(x => x.contains(1.0)))
}
