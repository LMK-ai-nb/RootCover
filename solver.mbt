///|
pub(all) struct Options {
  tolerance : Double
  max_assessments : Int32
  max_depth : Int32
}

///|
pub fn default_options() -> Options {
  { tolerance: 0.00000001, max_assessments: 4096, max_depth: 60, }
}

///|
pub(all) struct RootBox {
  enclosure : Array[Interval]
  certificate : Certificate
}

///|
pub(all) struct UnresolvedBox {
  box : Array[Interval]
  reason : String
}

///| Complete means every possible root in the initial box belongs to exactly one

///|
/// certified root domain. It says nothing about roots outside that initial box.
pub(all) struct SolveResult {
  roots : Array[RootBox]
  unresolved : Array[UnresolvedBox]
  complete : Bool
  tolerance_met : Bool
  assessments : Int32
  excluded : Int32
  contractions : Int32
  splits : Int32
}

///|
fn validate_options(o : Options) -> Unit raise RootError {
  guard o.tolerance > 0.0 && !o.tolerance.is_nan() && !o.tolerance.is_inf() else {
    raise Invalid("tolerance must be positive and finite")
  }
  guard o.max_assessments >= 1 && o.max_assessments <= 20000 else {
    raise Invalid("max_assessments must be in 1..20000")
  }
  guard o.max_depth >= 1 && o.max_depth <= 80 else {
    raise Invalid("max_depth must be in 1..80")
  }
}

///| All discarded regions are excluded by interval range or Krawczyk arguments.

///|
/// Budget/precision/depth limits preserve remaining boxes explicitly.
pub fn solve(
  system : System,
  initial : Array[Interval],
  options : Options,
) -> SolveResult raise RootError {
  validate_system(system)
  check_box(initial, system.names.length())
  validate_options(options)
  let stack : Array[(Array[Interval], Int32)] = [(initial.map(x => x), 0)]
  let roots : Array[RootBox] = []
  let unresolved : Array[UnresolvedBox] = []
  let mut assessments = 0
  let mut excluded = 0
  let mut contractions = 0
  let mut splits = 0
  while !stack.is_empty() {
    let (box, depth) = stack.pop().unwrap()
    if assessments >= options.max_assessments {
      unresolved.push({ box, reason: "assessment budget exhausted", })
      continue
    }
    assessments = assessments + 1
    match assess_unchecked(system, box) {
      Excluded(_) => excluded = excluded + 1
      Unique(certificate) => {
        let mut enclosure = certificate.enclosure
        // Refinement retains the original existence/uniqueness proof. Failure
        // to improve a tiny box never turns it into an extra root.
        for attempt = 0
            attempt < 12 &&
           assessments < options.max_assessments &&
           max_width(enclosure) > options.tolerance
            attempt = attempt + 1 {
          assessments = assessments + 1
          let next = match assess_unchecked(system, enclosure) {
            Unique(c) => Some(c.enclosure)
            Contracted(b) => Some(b)
            Excluded(_) =>
              raise Invalid(
                "internal inconsistency: certified root was excluded",
              )
            Undecided(_) => None
          }
          match next {
            Some(b) if max_width(b) < max_width(enclosure) => {
              enclosure = b
              contractions = contractions + 1
            }
            _ => break
          }
        }
        roots.push({ enclosure, certificate, })
      }
      Contracted(narrowed) => {
        contractions = contractions + 1
        stack.push((narrowed, depth))
      }
      Undecided(reason) => {
        if max_width(box) <= options.tolerance {
          unresolved.push({
            box,
            reason: "tolerance reached without a uniqueness proof: " + reason,
          })
          continue
        }
        if depth >= options.max_depth {
          unresolved.push({ box, reason: "depth limit reached: " + reason, })
          continue
        }
        let mut axis = 0
        for i = 1; i < box.length(); i = i + 1 {
          if box[i].width() > box[axis].width() {
            axis = i
          }
        }
        // An asymmetric partition avoids repeatedly placing symmetric simple
        // roots on a dyadic interface. Coverage does not depend on the ratio.
        let mid = box[axis].lo * 0.47 + box[axis].hi * 0.53
        if !(mid > box[axis].lo && mid < box[axis].hi) {
          unresolved.push({
            box,
            reason: "no representable interior split point",
          })
          continue
        }
        let left = box.map(x => x)
        let right = box.map(x => x)
        left[axis] = { lo: box[axis].lo, hi: mid, }
        right[axis] = { lo: mid, hi: box[axis].hi, }
        stack.push((right, depth + 1))
        stack.push((left, depth + 1))
        splits = splits + 1
      }
    }
  }
  {
    roots,
    unresolved,
    complete: unresolved.is_empty(),
    tolerance_met: roots.all(x => max_width(x.enclosure) <= options.tolerance),
    assessments,
    excluded,
    contractions,
    splits,
  }
}
