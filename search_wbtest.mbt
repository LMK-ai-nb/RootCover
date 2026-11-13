///|
test "breadth first search distributes a small budget across both singular branches" {
  let system = {
    names: ["x"],
    equations: [Pow(Sub(Pow(Variable(0), 2), Const(1.0)), 2)],
  }
  let options = { tolerance: 0.000001, max_assessments: 3, max_depth: 60, }
  let off = { propagation: false, newton: false, max_steps: 1, max_rounds: 1, }
  let dfs = solve_configured(
    system,
    [interval(-2.0, 2.0)],
    options,
    off,
    default_search(),
  )
  let bfs = solve_configured(system, [interval(-2.0, 2.0)], options, off, {
    order: BreadthFirst,
    split: Widest,
    absolute_tolerances: None,
    relative_tolerance: 0.0,
  })
  assert_false(dfs.complete)
  assert_false(bfs.complete)
  assert_true(dfs.unresolved.any(b => b.box[0].width() > 1.8))
  assert_true(bfs.unresolved.all(b => b.box[0].width() < 1.6))
  for p in [-1.0, 1.0] {
    assert_true(bfs.unresolved.any(b => b.box[0].contains(p)))
  }
}

///|
test "scaled branching respects variable units and pending boxes preserve a solution" {
  let model = {
    names: ["x", "y"],
    constraints: [
      {
        polynomial: parse_expression("(x-1000000)+1000000*y", ["x", "y"]),
        allowed: point(0.0),
      },
    ],
  }
  let r = pave_configured(
    model,
    [interval(1000000.0, 1000100.0), interval(-0.001, 0.001)],
    { tolerance: 0.000001, max_assessments: 1, max_depth: 60, },
    { propagation: false, newton: false, max_steps: 1, max_rounds: 1, },
    {
      order: BreadthFirst,
      split: Scaled,
      absolute_tolerances: Some([10.0, 0.000001]),
      relative_tolerance: 0.0,
    },
  )
  assert_eq(r.unresolved.length(), 2)
  assert_true(
    r.unresolved.all(b => b.box[0].lo == 1000000.0 && b.box[0].hi == 1000100.0),
  )
  assert_true(r.unresolved.all(b => b.box[1].width() < 0.0011))
  assert_true(
    r.unresolved.any(b => b.box[0].contains(1000000.0) && b.box[1].contains(0.0)),
  )
}

///|
test "relative stopping is conservative at zero and does not certify feasibility" {
  let policy = {
    order: DepthFirst,
    split: Scaled,
    absolute_tolerances: None,
    relative_tolerance: 0.00001,
  }
  let options = { tolerance: 0.00000001, max_assessments: 1, max_depth: 60, }
  assert_true(precision_met([interval(1000000.0, 1000001.0)], options, policy))
  assert_false(precision_met([interval(-0.001, 0.001)], options, policy))
  let model = {
    names: ["x"],
    constraints: [
      {
        polynomial: parse_expression("x-1000000.5", ["x"]),
        allowed: point(0.0),
      },
    ],
  }
  let r = pave_configured(
    model,
    [interval(1000000.0, 1000001.0)],
    options,
    { propagation: false, newton: false, max_steps: 1, max_rounds: 1, },
    policy,
  )
  assert_true(r.resolution_met)
  assert_false(r.complete)
  assert_eq(r.inside.length(), 0)
}

///|
test "queue compaction does not drop pending breadth first work" {
  let q = WorkQueue::new([point(-1.0)], BreadthFirst)
  for i = 0; i < 5000; i = i + 1 {
    q.put([point(i.to_double())], 0)
  }
  assert_eq(q.take().0[0].lo, -1.0)
  for i = 0; i < 5000; i = i + 1 {
    assert_eq(q.take().0[0].lo, i.to_double())
  }
  assert_true(q.empty())
}
