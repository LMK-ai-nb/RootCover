///|
/// Positive set algebra. AtLeast counts child predicates, not statistical
/// confidence. Its count is the MINIMUM satisfied, unlike Codac's outlier q.
pub(all) enum Predicate {
  Atom(Int32)
  All(Array[Predicate])
  Any(Array[Predicate])
  AtLeast(Int32, Array[Predicate])
}

///|
pub(all) enum Truth {
  Yes
  No
  Maybe
}

///|
pub(all) struct PredicateProblem {
  model : ConstraintModel
  predicate : Predicate
}

///|
pub(all) struct PredicateState {
  truth : Truth
  ranges : Array[DomainRange]
  atom_truths : Array[Truth]
}

///|
fn predicates_equal(a : Predicate, b : Predicate) -> Bool {
  fn arrays(a : Array[Predicate], b : Array[Predicate]) -> Bool {
    a.length() == b.length() &&
    Array::makei(a.length(), i => predicates_equal(a[i], b[i])).all(x => x)
  }
  match (a, b) {
    (Atom(i), Atom(j)) => i == j
    (All(x), All(y)) | (Any(x), Any(y)) => arrays(x, y)
    (AtLeast(k, x), AtLeast(l, y)) => k == l && arrays(x, y)
    _ => false
  }
}

///|
fn check_predicate(
  p : Predicate,
  atoms : Int32,
  depth : Int32,
  nodes : Ref[Int32],
) -> Unit raise RootError {
  nodes.val = nodes.val + 1
  guard depth <= 16 && nodes.val <= 512 else {
    raise Invalid("formula exceeds depth16 or512 nodes")
  }
  match p {
    Atom(i) => {
      guard i >= 0 && i < atoms else {
        raise Invalid("formula atom index out of range")
      }
    }
    All(children) | Any(children) | AtLeast(_, children) => {
      guard children.length() > 0 && children.length() <= 128 else {
        raise Invalid("formula group requires1..128 children")
      }
      for child in children {
        check_predicate(child, atoms, depth + 1, nodes)
      }
      match p {
        AtLeast(k, _) => {
          guard k >= 1 && k <= children.length() else {
            raise Invalid("at_least count must be1..child count")
          }
          for i = 0; i < children.length(); i = i + 1 {
            for j = 0; j < i; j = j + 1 {
              guard !predicates_equal(children[i], children[j]) else {
                raise Invalid(
                  "duplicate at_least child would count the same predicate twice",
                )
              }
            }
          }
        }
        _ => ()
      }
    }
  }
}

///|
pub fn validate_predicate(problem : PredicateProblem) -> Unit raise RootError {
  validate_constraints(problem.model)
  check_predicate(
    problem.predicate,
    problem.model.constraints.length(),
    0,
    Ref(0),
  )
}

///|
fn quorum_truth(k : Int32, values : Array[Truth]) -> Truth {
  let mut yes = 0
  let mut possible = 0
  for value in values {
    match value {
      Yes => {
        yes = yes + 1
        possible = possible + 1
      }
      Maybe => possible = possible + 1
      No => ()
    }
  }
  if yes >= k {
    Yes
  } else if possible < k {
    No
  } else {
    Maybe
  }
}

///|
fn formula_truth(p : Predicate, atoms : Array[Truth]) -> Truth {
  match p {
    Atom(i) => atoms[i]
    All(children) =>
      quorum_truth(
        children.length(),
        children.map(x => formula_truth(x, atoms)),
      )
    Any(children) => quorum_truth(1, children.map(x => formula_truth(x, atoms)))
    AtLeast(k, children) =>
      quorum_truth(k, children.map(x => formula_truth(x, atoms)))
  }
}

///|
fn predicate_state_unchecked(
  problem : PredicateProblem,
  box : Array[Interval],
) -> PredicateState raise RootError {
  let ranges = problem.model.constraints.map(c => {
    expression_range_unchecked(c.polynomial, box)
  })
  let atom_truths = Array::makei(ranges.length(), i => {
    let state = ranges[i]
    let allowed = problem.model.constraints[i].allowed
    match state.range {
      None => No
      Some(r) =>
        if r.hi < allowed.lo || r.lo > allowed.hi {
          No
        } else if state.fully_defined &&
          r.lo >= allowed.lo &&
          r.hi <= allowed.hi {
          Yes
        } else {
          Maybe
        }
    }
  })
  { truth: formula_truth(problem.predicate, atom_truths), ranges, atom_truths, }
}

///|
/// Undefined atoms are false; positive alternatives can be satisfied by other
/// defined atoms. No negation/complement is implicitly added to the language.
pub fn classify_predicate(
  problem : PredicateProblem,
  box : Array[Interval],
) -> PredicateState raise RootError {
  validate_predicate(problem)
  check_box(box, problem.model.names.length())
  predicate_state_unchecked(problem, box)
}

///|
/// Hull of coordinatewise regions covered by at least k candidate boxes.
/// This is an outer contractor, NOT a test proving joint feasibility.
fn quorum_hull(
  boxes : Array[Array[Interval]],
  k : Int32,
  n : Int32,
) -> Array[Interval]? {
  if boxes.length() < k {
    return None
  }
  let result : Array[Interval] = []
  for axis = 0; axis < n; axis = axis + 1 {
    let mut low = @double.infinity
    let mut high = @double.neg_infinity
    for candidate in boxes {
      for endpoint in [candidate[axis].lo, candidate[axis].hi] {
        let mut count = 0
        for b in boxes {
          if b[axis].contains(endpoint) {
            count = count + 1
          }
        }
        if count >= k {
          low = low.min(endpoint)
          high = high.max(endpoint)
        }
      }
    }
    if low > high {
      return None
    }
    result.push({ lo: low, hi: high, })
  }
  Some(result)
}

///|
priv struct PredicateBudget {
  mut calls : Int32
  mut propagation : Int32
  mut newton : Int32
  mut all_fixed : Bool
}

///|
fn contract_selection(
  indices : Array[Int32],
  model : ConstraintModel,
  box : Array[Interval],
  config : ContractorOptions,
  budget : PredicateBudget,
) -> Array[Interval]? raise RootError {
  let remaining = config.max_steps - budget.calls
  if remaining <= 0 {
    budget.all_fixed = false
    return Some(box.map(x => x))
  }
  let selected = {
    names: model.names,
    constraints: indices.map(i => model.constraints[i]),
  }
  let c = contract_unchecked(selected, box, {
    propagation: config.propagation,
    newton: config.newton,
    max_steps: if indices.length() == 1 {
      remaining.min(32)
    } else {
      remaining
    },
    max_rounds: config.max_rounds,
  })
  budget.calls = budget.calls + c.calls
  budget.propagation = budget.propagation + c.propagation_calls
  budget.newton = budget.newton + c.newton_calls
  budget.all_fixed = budget.all_fixed && c.fixed_point
  c.box
}

///|
fn contract_formula(
  p : Predicate,
  model : ConstraintModel,
  initial : Array[Interval],
  config : ContractorOptions,
  budget : PredicateBudget,
) -> Array[Interval]? raise RootError {
  match p {
    Atom(i) => contract_selection([i], model, initial, config, budget)
    All(children) => {
      let indices : Array[Int32] = []
      let mut flat = true
      for child in children {
        match child {
          Atom(i) => if !indices.contains(i) { indices.push(i) }
          _ => flat = false
        }
      }
      if flat {
        return contract_selection(indices, model, initial, config, budget)
      }
      let mut box = initial.map(x => x)
      for child in children {
        match contract_formula(child, model, box, config, budget) {
          None => return None
          Some(b) => box = b
        }
      }
      Some(box)
    }
    Any(children) | AtLeast(_, children) => {
      let k = match p {
        AtLeast(k, _) => k
        _ => 1
      }
      let branches : Array[Array[Interval]] = []
      for child in children {
        match contract_formula(child, model, initial, config, budget) {
          None => ()
          Some(b) => branches.push(b)
        }
      }
      quorum_hull(branches, k, initial.length())
    }
  }
}

///|
fn contract_predicate_unchecked(
  problem : PredicateProblem,
  initial : Array[Interval],
  config : ContractorOptions,
) -> Contraction raise RootError {
  let budget = { calls: 0, propagation: 0, newton: 0, all_fixed: true, }
  let mut box = initial.map(x => x)
  let mut rounds = 0
  let mut fixed = false
  while rounds < config.max_rounds && budget.calls < config.max_steps {
    rounds = rounds + 1
    budget.all_fixed = true
    let before = box
    match
      contract_formula(problem.predicate, problem.model, box, config, budget) {
      None =>
        return {
          box: None,
          calls: budget.calls,
          rounds,
          changed: true,
          fixed_point: true,
          budget_exhausted: false,
          propagation_calls: budget.propagation,
          newton_calls: budget.newton,
        }
      Some(b) => box = b
    }
    if same_box(before, box) && budget.all_fixed {
      fixed = true
      break
    }
  }
  {
    box: Some(box),
    calls: budget.calls,
    rounds,
    changed: !same_box(initial, box),
    fixed_point: fixed,
    budget_exhausted: !fixed,
    propagation_calls: budget.propagation,
    newton_calls: budget.newton,
  }
}

///|
pub fn contract_predicate(
  problem : PredicateProblem,
  initial : Array[Interval],
  config : ContractorOptions,
) -> Contraction raise RootError {
  validate_predicate(problem)
  check_box(initial, problem.model.names.length())
  validate_contractors(config)
  contract_predicate_unchecked(problem, initial, config)
}

///|
fn referenced_expressions(problem : PredicateProblem) -> Array[Expr] {
  let used = Array::make(problem.model.constraints.length(), false)
  fn visit(p : Predicate, used : Array[Bool]) -> Unit {
    match p {
      Atom(i) => used[i] = true
      All(children) | Any(children) | AtLeast(_, children) =>
        for c in children {
          visit(c, used)
        }
    }
  }
  visit(problem.predicate, used)
  let expressions : Array[Expr] = []
  for i = 0; i < used.length(); i = i + 1 {
    if used[i] {
      expressions.push(problem.model.constraints[i].polynomial)
    }
  }
  expressions
}

///|
pub(all) struct PredicateBox {
  box : Array[Interval]
  evidence : PredicateState
}

///|
pub(all) struct PredicateResult {
  inside : Array[PredicateBox]
  unresolved : Array[UnresolvedBox]
  complete : Bool
  resolution_met : Bool
  assessments : Int32
  excluded : Int32
  contractions : Int32
  contractor_calls : Int32
  splits : Int32
}

///|
pub fn pave_predicate(
  problem : PredicateProblem,
  initial : Array[Interval],
  options : Options,
  contractors : ContractorOptions,
  search : SearchPolicy,
) -> PredicateResult raise RootError {
  validate_predicate(problem)
  check_box(initial, problem.model.names.length())
  validate_options(options)
  validate_contractors(contractors)
  validate_search(search, problem.model.names.length())
  let queue = WorkQueue::new(initial, search.order)
  let expressions = referenced_expressions(problem)
  let inside : Array[PredicateBox] = []
  let unresolved : Array[UnresolvedBox] = []
  let mut assessments = 0
  let mut excluded = 0
  let mut contractions = 0
  let mut contractor_calls = 0
  let mut splits = 0
  while !queue.empty() {
    let (original, depth) = queue.take()
    let mut box = original
    if assessments >= options.max_assessments {
      unresolved.push({ box, reason: "assessment budget exhausted", })
      continue
    }
    assessments = assessments + 1
    if contractor_calls < contractors.max_steps &&
      (contractors.propagation || contractors.newton) {
      let c = contract_predicate_unchecked(problem, box, {
        propagation: contractors.propagation,
        newton: contractors.newton,
        max_steps: contractors.max_steps - contractor_calls,
        max_rounds: contractors.max_rounds,
      })
      contractor_calls = contractor_calls + c.calls
      if c.changed {
        contractions = contractions + 1
      }
      match c.box {
        None => {
          excluded = excluded + 1
          continue
        }
        Some(b) => box = b
      }
    }
    let evidence = predicate_state_unchecked(problem, box)
    match evidence.truth {
      Yes => inside.push({ box, evidence, })
      No => excluded = excluded + 1
      Maybe => {
        if precision_met(box, options, search) {
          unresolved.push({
            box,
            reason: "resolution reached without whole-formula classification",
          })
          continue
        }
        if depth >= options.max_depth {
          unresolved.push({ box, reason: "depth limit reached", })
          continue
        }
        match split_with_policy(box, options, search, expressions) {
          None =>
            unresolved.push({
              box,
              reason: "no representable interior split point",
            })
          Some((left, right)) => {
            queue.children(left, right, depth + 1)
            splits = splits + 1
          }
        }
      }
    }
  }
  {
    inside,
    unresolved,
    complete: unresolved.is_empty(),
    resolution_met: unresolved.all(b => precision_met(b.box, options, search)),
    assessments,
    excluded,
    contractions,
    contractor_calls,
    splits,
  }
}
