# RootCover typed API

Add `LMK-ai-nb/rootcover@0.2.0` to your module, and import `LMK-ai-nb/rootcover`
in the consuming package's `moon.pkg`. Its default alias is `@rootcover`.
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
  assert_false(result.complete)
}
```

`enclose` returns natural interval polynomial ranges and interval forward-mode
Jacobian entries. `assess` classifies one box. `solve` covers a finite initial
region. `decode_request` and `solve_json` are transport-neutral conveniences.
Invalid models/requests raise `RootError::Invalid(String)`.

Inputs and results are not mutated by the solver. The generated public signatures
are in `pkg.generated.mbti`. See `docs/SEMANTICS.md` before interpreting a proof
or a `complete` flag. In particular, this is binary64 polynomial enclosure, not
exact-decimal algebra or a promise to resolve multiple roots.


`ConstraintModel` supports 1..32 polynomial observation bands on 1..6 variables,
without the square-system restriction. `classify_constraints` classifies an entire
box; `pave` returns inside-box certificates and unresolved outer coverage.
`decode_feasibility_request` is the typed parser. `solve_json` dispatches requests
with `mode: "feasibility"`; omitted mode remains backward-compatible root solving.
A feasible box is an entire continuous set, never an individual solution or a
statistical confidence interval. See docs/PAVING.md.
