///|
/// A real-expression observation/constraint. The historical field name
/// `polynomial` is retained for typed 0.2 caller compatibility; it accepts Expr
/// division and elementary function nodes as well as polynomials.
pub(all) struct Constraint {
  polynomial : Expr
  allowed : Interval
}

///|
/// Constraints need not be square: 1..128 bands on 1..32 variables.
pub(all) struct ConstraintModel {
  names : Array[String]
  constraints : Array[Constraint]
}

///|
pub(all) struct FeasibleBox {
  box : Array[Interval]
  ranges : Array[Interval]
}

///|
pub(all) enum FeasibilityAssessment {
  Inside(Array[Interval])
  Outside(String)
  Indeterminate
}

///| Inner boxes contain only feasible points. Inner + unresolved boxes enclose

///|
/// every feasible point in the initial domain, including after budget exhaustion.
pub(all) struct PavingResult {
  inside : Array[FeasibleBox]
  unresolved : Array[UnresolvedBox]
  complete : Bool
  resolution_met : Bool
  assessments : Int32
  excluded : Int32
  splits : Int32
  contractions : Int32
  contractor_calls : Int32
}

///|
pub fn validate_constraints(model : ConstraintModel) -> Unit raise RootError {
  validate_polynomials(model.names, model.constraints.map(c => c.polynomial))
  for c in model.constraints {
    guard !c.allowed.lo.is_nan() &&
      !c.allowed.hi.is_nan() &&
      c.allowed.lo <= c.allowed.hi &&
      !c.allowed.lo.is_pos_inf() &&
      !c.allowed.hi.is_neg_inf() else {
      raise Invalid(
        "constraint ranges must be ordered, nonempty real intervals",
      )
    }
  }
}

///|
/// Natural interval extension without unnecessary Jacobian work.
fn range_unchecked(e : Expr, box : Array[Interval]) -> Interval raise RootError {
  expression_range_unchecked(e, box).range.unwrap_or(whole())
}

///|
fn classify_unchecked(
  model : ConstraintModel,
  box : Array[Interval],
) -> FeasibilityAssessment raise RootError {
  let ranges : Array[Interval] = []
  let mut inside = true
  for i = 0; i < model.constraints.length(); i = i + 1 {
    let c = model.constraints[i]
    let state = expression_range_unchecked(c.polynomial, box)
    let r = match state.range {
      None =>
        return Outside("constraint expression is undefined throughout this box")
      Some(r) => r
    }
    if r.hi < c.allowed.lo || r.lo > c.allowed.hi {
      return Outside("constraint \{i} range is disjoint")
    }
    if !state.fully_defined || !(r.lo >= c.allowed.lo && r.hi <= c.allowed.hi) {
      inside = false
    }
    ranges.push(r)
  }
  if inside {
    Inside(ranges)
  } else {
    Indeterminate
  }
}

///|
/// Certifies an entire box, never merely its midpoint.
pub fn classify_constraints(
  model : ConstraintModel,
  box : Array[Interval],
) -> FeasibilityAssessment raise RootError {
  validate_constraints(model)
  check_box(box, model.names.length())
  classify_unchecked(model, box)
}

///| Set inversion by interval subdivision (SIVIA). This is a feasible-set

///|
/// enclosure, not a root count, probability/confidence interval or optimizer.
pub fn pave(
  model : ConstraintModel,
  initial : Array[Interval],
  options : Options,
) -> PavingResult raise RootError {
  pave_with_contractors(model, initial, options, default_contractors())
}

///|
pub fn pave_with_contractors(
  model : ConstraintModel,
  initial : Array[Interval],
  options : Options,
  contractors : ContractorOptions,
) -> PavingResult raise RootError {
  validate_constraints(model)
  check_box(initial, model.names.length())
  validate_options(options)
  validate_contractors(contractors)
  let stack : Array[(Array[Interval], Int32)] = [(initial.map(x => x), 0)]
  let inside : Array[FeasibleBox] = []
  let unresolved : Array[UnresolvedBox] = []
  let mut assessments = 0
  let mut excluded = 0
  let mut splits = 0
  let mut contractions = 0
  let mut contractor_calls = 0
  while !stack.is_empty() {
    let (original, depth) = stack.pop().unwrap()
    let mut box = original
    if assessments >= options.max_assessments {
      unresolved.push({ box, reason: "assessment budget exhausted", })
      continue
    }
    assessments = assessments + 1
    if contractor_calls < contractors.max_steps &&
      (contractors.propagation || contractors.newton) {
      let contracted = contract_unchecked(model, box, {
        propagation: contractors.propagation,
        newton: contractors.newton,
        max_steps: contractors.max_steps - contractor_calls,
        max_rounds: contractors.max_rounds,
      })
      contractor_calls = contractor_calls + contracted.calls
      if contracted.changed {
        contractions = contractions + 1
      }
      match contracted.box {
        None => {
          excluded = excluded + 1
          continue
        }
        Some(b) => box = b
      }
    }
    match classify_unchecked(model, box) {
      Inside(ranges) => inside.push({ box, ranges, })
      Outside(_) => excluded = excluded + 1
      Indeterminate => {
        if max_width(box) <= options.tolerance {
          unresolved.push({
            box,
            reason: "resolution reached without whole-box classification",
          })
          continue
        }
        if depth >= options.max_depth {
          unresolved.push({ box, reason: "depth limit reached", })
          continue
        }
        match bisect_box(box) {
          Some((left, right)) => {
            stack.push((right, depth + 1))
            stack.push((left, depth + 1))
            splits = splits + 1
          }
          None =>
            unresolved.push({
              box,
              reason: "no representable interior split point",
            })
        }
      }
    }
  }
  {
    inside,
    unresolved,
    complete: unresolved.is_empty(),
    resolution_met: unresolved.all(b => max_width(b.box) <= options.tolerance),
    assessments,
    excluded,
    splits,
    contractions,
    contractor_calls,
  }
}
