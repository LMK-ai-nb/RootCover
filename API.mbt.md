# RootCover typed API

This file describes the local 0.4.0-dev.1 build. It has not been pushed or
published; Mooncakes 0.2.0 does not contain these new interfaces. The package
alias below is `@rootcover`.
The following examples are compiled and executed by `moon test`.

```mbt check nocheck
///|
test "public typed API finds both roots" {
  let x = @rootcover.Expr::Variable(0)
  let s : @rootcover.System = {
    names: ["x"],
    equations: [
      @rootcover.Expr::Sub(
        @rootcover.Expr::Pow(x, 2),
        @rootcover.Expr::Const(4.0),
      ),
    ],
  }
  let r = @rootcover.solve(
    s,
    [@rootcover.interval(-3.0, 3.0)],
    @rootcover.default_options(),
  )
  assert_true(r.complete)
  assert_eq(r.roots.length(), 2)
}

///|
test "public request API preserves unresolved regions" {
  let request = @rootcover.decode_request(
    "{\"version\":1,\"variables\":[\"x\"],\"equations\":[\"x^2\"],\"box\":[[-1,1]],\"options\":{\"max_assessments\":1}}",
  )
  let r = @rootcover.solve(request.system, request.box, request.options)
  assert_false(r.complete)
  assert_true(r.unresolved.length() > 0)
}

///|
test "public API encloses a tolerance-defined feasible set" {
  let model : @rootcover.ConstraintModel = {
    names: ["x"],
    constraints: [
      {
        polynomial: @rootcover.Expr::Variable(0),
        allowed: @rootcover.interval(-0.25, 0.25),
      },
    ],
  }
  let result = @rootcover.pave(model, [@rootcover.interval(-1.0, 1.0)], {
    tolerance: 0.01,
    max_assessments: 4096,
    max_depth: 60,
  })
  assert_true(result.inside.length() > 0)
  assert_true(result.resolution_met)
  assert_true(result.complete)
}

///|
test "elementary expressions solve a logarithmic domain crossing" {
  let r = @rootcover.solve(
    { names: ["x"], equations: [@rootcover.parse_expression("log(x)", ["x"])], },
    [@rootcover.interval(-2.0, 2.0)],
    @rootcover.default_options(),
  )
  assert_true(r.complete)
  assert_eq(r.roots.length(), 1)
  assert_true(r.roots[0].enclosure[0].contains(1.0))
}

///|
test "interval Newton can be called independently" {
  let c = @rootcover.interval_newton(
    { names: ["x"], equations: [@rootcover.parse_expression("x^2-2", ["x"])], },
    [@rootcover.interval(1.0, 2.0)],
  )
  assert_true(c.changed)
  assert_true(c.box.unwrap()[0].contains(1.4142135623730951))
}

///|
test "mixed observation bands have a typed contractor API" {
  let model : @rootcover.ConstraintModel = {
    names: ["x"],
    constraints: [
      {
        polynomial: @rootcover.parse_expression("exp(x)", ["x"]),
        allowed: @rootcover.interval(1.5, 2.0),
      },
    ],
  }
  let c = @rootcover.contract_constraints(
    model,
    [@rootcover.interval(-2.0, 2.0)],
    @rootcover.default_contractors(),
  )
  assert_true(c.box.unwrap()[0].contains(0.5))
  assert_true(c.changed && c.propagation_calls > 0 && c.newton_calls > 0)
}

///|
test "a positive predicate preserves a consensus despite an incompatible atom" {
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
        allowed: @rootcover.interval(10.0, 20.0),
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
  let r = @rootcover.pave_predicate(
    problem,
    [@rootcover.interval(-1.0, 21.0)],
    @rootcover.default_options(),
    @rootcover.default_contractors(),
    @rootcover.default_search(),
  )
  assert_true(r.complete)
  assert_true(r.inside.any(b => b.box[0].contains(1.5)))
}

///|
test "root solving accepts a breadth first search policy" {
  let system : @rootcover.System = {
    names: ["x"],
    equations: [@rootcover.parse_expression("exp(x)-2", ["x"])],
  }
  let policy : @rootcover.SearchPolicy = {
    order: @rootcover.SearchOrder::BreadthFirst,
    split: @rootcover.SplitRule::Scaled,
    absolute_tolerances: Some([0.0000001]),
    relative_tolerance: 0.000001,
  }
  let r = @rootcover.solve_configured(
    system,
    [@rootcover.interval(0.0, 1.0)],
    @rootcover.default_options(),
    @rootcover.default_contractors(),
    policy,
  )
  assert_true(r.complete)
  assert_true(r.roots[0].enclosure[0].contains(0.6931471805599453))
}
```

`parse_expression` accepts arithmetic, division, negative integer powers and
13 elementary functions. `parse_polynomial` remains the legacy strict grammar.
`evaluate_expression` returns a conservative `DomainRange` with full-domain and
smoothness flags; `enclose` returns interval Jacobians and corresponding flags.
Invalid models raise `RootError::Invalid(String)`; inputs are not mutated.

`ConstraintModel` accepts1..128 bands on1..32 variables, including non-square
systems. Its historical field `polynomial` accepts every supported `Expr`.
`contract_constraints` uses `ContractorOptions` (propagation, newton, max_steps,
max_rounds). `interval_newton` is independently callable. A contraction does not
by itself prove existence/uniqueness or feasibility.

`solve` and `pave` use joint contractors by default. The `*_with_contractors`
variants accept explicit controls. `decode_request` and
`decode_feasibility_request` also return the controls selected by JSON.
`solve_json` dispatches roots/feasibility mode; omitted mode means roots.
See docs/NONLINEAR.md and docs/PAVING.md for domain, budget and null-endpoint
semantics. This local API is not yet available in the published0.2.0 module.

`PredicateProblem` adds positive All/Any/AtLeast composition. `classify_predicate`, `contract_predicate` and `pave_predicate` preserve conservative set semantics; no implicit negation or statistical confidence. `SearchPolicy` configures DFS/BFS, per-axis absolute/mixed relative precision and branching. `solve_configured`/`pave_configured` accept it directly. JSON exports both policy and pending/unknown tags. See docs/SET_ALGEBRA.md.
