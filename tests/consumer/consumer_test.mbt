///|
test "packaged public solver certifies an elementary root" {
  let names = ["x"]
  let system : @rootcover.System = {
    names,
    equations: [@rootcover.parse_expression("exp(x)-2", names)],
  }
  let initial = [@rootcover.interval(0.0, 1.0)]
  let result = @rootcover.solve(system, initial, @rootcover.default_options())
  assert_true(result.complete)
  assert_eq(result.roots.length(), 1)
  assert_true(result.roots[0].enclosure[0].contains(0.6931471805599453))
  assert_true(result.roots[0].certificate.q < 1.0)
  assert_eq(initial[0].lo, 0.0)
  assert_eq(initial[0].hi, 1.0)
}

///|
test "packaged non-square paving preserves a feasible parameter" {
  let names = ["x", "y"]
  let model : @rootcover.ConstraintModel = {
    names,
    constraints: [
      {
        polynomial: @rootcover.parse_expression("x+y", names),
        allowed: @rootcover.interval(1.9, 2.1),
      },
      {
        polynomial: @rootcover.parse_expression("x", names),
        allowed: @rootcover.interval(0.0, 2.0),
      },
      {
        polynomial: @rootcover.parse_expression("y", names),
        allowed: @rootcover.interval(0.0, 2.0),
      },
    ],
  }
  let result = @rootcover.pave(
    model,
    [@rootcover.interval(0.9, 1.1), @rootcover.interval(0.9, 1.1)],
    @rootcover.default_options(),
  )
  assert_true(!result.inside.is_empty())
  assert_true(
    result.inside.any(b => b.box.all(axis => axis.contains(1.0))) ||
    result.unresolved.any(b => b.box.all(axis => axis.contains(1.0))),
  )
  for inner in result.inside {
    assert_true(inner.ranges[0].lo >= 1.9 && inner.ranges[0].hi <= 2.1)
  }
}

///|
test "packaged positive quorum retains only the overlapping alternatives" {
  let model : @rootcover.ConstraintModel = {
    names: ["x"],
    constraints: [
      {
        polynomial: @rootcover.Expr::Variable(0),
        allowed: @rootcover.interval(0.0, 2.0),
      },
      {
        polynomial: @rootcover.Expr::Variable(0),
        allowed: @rootcover.interval(1.0, 3.0),
      },
      {
        polynomial: @rootcover.Expr::Variable(0),
        allowed: @rootcover.interval(20.0, 30.0),
      },
    ],
  }
  let problem : @rootcover.PredicateProblem = {
    model,
    predicate: @rootcover.Predicate::AtLeast(2, [
      @rootcover.Predicate::Atom(0),
      @rootcover.Predicate::Atom(1),
      @rootcover.Predicate::Atom(2),
    ]),
  }
  let result = @rootcover.pave_predicate(
    problem,
    [@rootcover.interval(0.0, 30.0)],
    @rootcover.default_options(),
    @rootcover.default_contractors(),
    @rootcover.default_search(),
  )
  assert_true(result.complete)
  assert_true(result.inside.any(b => b.box[0].contains(1.5)))
  assert_true(result.inside.all(b => !b.box[0].contains(25.0)))
}

///|
fn field(value : Json, key : String) -> Json {
  match value {
    Object(o) => o.get(key).unwrap()
    _ => abort("expected object")
  }
}

///|
test "packaged opaque session can be saved restored and advanced by a consumer" {
  let source =
    #|{"version":1,"mode":"feasibility","variables":["x"],"constraints":[{"expression":"x","range":[-0.25,0.25]}],"box":[[-1,1]],"contractors":{"propagation":false,"newton":false}}
  let session = @rootcover.new_paving_session(source)
  session.advance(1)
  let saved = session.checkpoint()
  let restored = @rootcover.restore_paving_session(saved)
  assert_eq(restored.checkpoint(), saved)
  restored.advance(2)
  let json = @json.parse(restored.snapshot())
  match field(field(json, "stats"), "assessments") {
    Number(n, ..) => assert_eq(n, 3.0)
    _ => abort("expected cumulative assessments")
  }
  let rejected = try {
    @rootcover.new_paving_session("{}") |> ignore
    false
  } catch {
    @rootcover.Invalid(_) => true
  }
  assert_true(rejected)
}

///|
test "packaged domain API distinguishes an undefined expression" {
  let expression = @rootcover.parse_expression("log(x)", ["x"])
  let result = @rootcover.evaluate_expression(expression, [
    @rootcover.interval(-2.0, -1.0),
  ])
  assert_true(result.range is None)
  assert_true(!result.fully_defined)
}
