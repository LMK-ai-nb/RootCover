///|
test "a bounded outlier is tolerated only by explicit quorum" {
  let x = Variable(0)
  let model = {
    names: ["x"],
    constraints: [
      { polynomial: x, allowed: interval(0.0, 2.0), },
      { polynomial: x, allowed: interval(1.0, 3.0), },
      { polynomial: x, allowed: interval(10.0, 20.0), },
    ],
  }
  let required = { model, predicate: AtLeast(2, [Atom(0), Atom(1), Atom(2)]), }
  assert_true(classify_predicate(required, [interval(1.25, 1.75)]).truth is Yes)
  assert_true(
    classify_predicate(
      { model, predicate: All([Atom(0), Atom(1), Atom(2)]), },
      [point(1.5)],
    ).truth
    is No,
  )
  let c = contract_predicate(
    required,
    [interval(-1.0, 21.0)],
    default_contractors(),
  )
  assert_true(c.box.unwrap()[0].contains(1.5))
  assert_true(c.box.unwrap()[0].lo >= 1.0 && c.box.unwrap()[0].hi <= 2.0)
}

///|
test "set union retains disconnected alternatives and does not certify its hull" {
  let model = {
    names: ["x"],
    constraints: [
      { polynomial: Variable(0), allowed: interval(-2.0, -1.0), },
      { polynomial: Variable(0), allowed: interval(1.0, 2.0), },
    ],
  }
  let problem = { model, predicate: Any([Atom(0), Atom(1)]), }
  let c = contract_predicate(
    problem,
    [interval(-3.0, 3.0)],
    default_contractors(),
  )
  assert_true(c.box.unwrap()[0].contains(0.0))
  assert_true(classify_predicate(problem, [point(0.0)]).truth is No)
  let r = pave_predicate(
    problem,
    [interval(-3.0, 3.0)],
    { tolerance: 0.01, max_assessments: 1000, max_depth: 60, },
    default_contractors(),
    default_search(),
  )
  for point in [-1.5, 1.5] {
    assert_true(
      r.inside.any(b => b.box[0].contains(point)) ||
      r.unresolved.any(b => b.box[0].contains(point)),
    )
  }
  assert_false(r.inside.any(b => b.box[0].contains(0.0)))
}

///|
test "undefined inactive branches do not invalidate a defined union branch" {
  let model = {
    names: ["x"],
    constraints: [
      { polynomial: Variable(0), allowed: interval(-2.0, -1.0), },
      { polynomial: Apply(Log, Variable(0)), allowed: interval(0.0, 0.2), },
    ],
  }
  let b = [interval(-1.8, -1.2)]
  let r = classify_predicate({ model, predicate: Any([Atom(0), Atom(1)]), }, b)
  assert_true(r.truth is Yes)
  assert_true(r.ranges[1].range is None)
  assert_true(
    classify_predicate({ model, predicate: All([Atom(0), Atom(1)]), }, b).truth
    is No,
  )
}

///|
test "unused atoms are never secretly imposed as mandatory constraints" {
  let model = {
    names: ["x"],
    constraints: [
      { polynomial: Variable(0), allowed: interval(0.0, 1.0), },
      { polynomial: Const(1.0), allowed: point(0.0), },
    ],
  }
  let c = contract_predicate(
    { model, predicate: Atom(0), },
    [interval(-1.0, 2.0)],
    default_contractors(),
  )
  assert_true(c.box.unwrap()[0].contains(0.5))
}

///|
test "quorum validation rejects duplicate votes and invalid thresholds" {
  let model = {
    names: ["x"],
    constraints: [{ polynomial: Variable(0), allowed: point(0.0), }],
  }
  let mut rejected = 0
  for
    p in [
      AtLeast(2, [Atom(0), Atom(0)]),
      AtLeast(0, [Atom(0)]),
      Atom(1),
      All([]),
    ] {
    validate_predicate({ model, predicate: p, }) catch {
      _ => rejected = rejected + 1
    }
  }
  assert_eq(rejected, 4)
}

///|
test "limited branch contraction preserves unprocessed alternatives" {
  let model = {
    names: ["x"],
    constraints: [
      { polynomial: Const(1.0), allowed: point(0.0), },
      { polynomial: Variable(0), allowed: interval(1.0, 2.0), },
    ],
  }
  let c = contract_predicate(
    { model, predicate: Any([Atom(0), Atom(1)]), },
    [interval(-3.0, 3.0)],
    { propagation: true, newton: true, max_steps: 1, max_rounds: 4, },
  )
  assert_true(c.box.unwrap()[0].contains(1.5))
  assert_true(c.budget_exhausted)
}
