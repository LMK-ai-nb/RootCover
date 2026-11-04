///|
/// A bounded observation/constraint: polynomial(x) must lie in allowed.
pub(all) struct Constraint {
  polynomial : Expr
  allowed : Interval
}

///|
/// Constraints need not be square: 1..32 bands on 1..6 variables.
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
}

///|
pub fn validate_constraints(model : ConstraintModel) -> Unit raise RootError {
  validate_polynomials(model.names, model.constraints.map(c => c.polynomial))
  for c in model.constraints {
    guard c.allowed.finite() else {
      raise Invalid("constraint ranges must be finite ordered intervals")
    }
  }
}

///|
/// Natural interval extension without unnecessary Jacobian work.
fn range_unchecked(e : Expr, box : Array[Interval]) -> Interval raise RootError {
  match e {
    Const(x) => point(x)
    Variable(i) => box[i]
    Add(a, b) => range_unchecked(a, box).add(range_unchecked(b, box))
    Sub(a, b) => range_unchecked(a, box).sub(range_unchecked(b, box))
    Mul(a, b) => range_unchecked(a, box).mul(range_unchecked(b, box))
    Pow(a, k) => range_unchecked(a, box).power(k)
  }
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
    let r = range_unchecked(c.polynomial, box)
    if r.hi < c.allowed.lo || r.lo > c.allowed.hi {
      return Outside("constraint \{i} range is disjoint")
    }
    if !(r.lo >= c.allowed.lo && r.hi <= c.allowed.hi) {
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
  validate_constraints(model)
  check_box(initial, model.names.length())
  validate_options(options)
  let stack : Array[(Array[Interval], Int32)] = [(initial.map(x => x), 0)]
  let inside : Array[FeasibleBox] = []
  let unresolved : Array[UnresolvedBox] = []
  let mut assessments = 0
  let mut excluded = 0
  let mut splits = 0
  while !stack.is_empty() {
    let (box, depth) = stack.pop().unwrap()
    if assessments >= options.max_assessments {
      unresolved.push({ box, reason: "assessment budget exhausted", })
      continue
    }
    assessments = assessments + 1
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
  }
}
