///|
/// Bounded propagation + preconditioned interval Newton. A stopped contractor
/// returns a conservative box, never a claim of feasibility or uniqueness.
pub(all) struct ContractorOptions {
  propagation : Bool
  newton : Bool
  max_steps : Int32
  max_rounds : Int32
}

///|
pub fn default_contractors() -> ContractorOptions {
  { propagation: true, newton: true, max_steps: 256, max_rounds: 4, }
}

///|
pub(all) struct Contraction {
  box : Array[Interval]?
  calls : Int32
  rounds : Int32
  changed : Bool
  fixed_point : Bool
  budget_exhausted : Bool
  propagation_calls : Int32
  newton_calls : Int32
}

///|
fn same_box(a : Array[Interval], b : Array[Interval]) -> Bool {
  a.length() == b.length() &&
  Array::makei(a.length(), i => a[i] == b[i]).all(x => x)
}

///|
/// Relational division used for multiplication inverses. If zero can satisfy
/// the product equation, no nonzero quotient restriction is imposed.
fn relational_divide(z : Interval, b : Interval) -> Interval? {
  if !b.contains(0.0) {
    return Some(z.div(b))
  }
  if z.contains(0.0) {
    return Some(whole())
  }
  if b.lo == 0.0 && b.hi == 0.0 {
    return None
  }
  if b.lo < 0.0 && b.hi > 0.0 {
    return Some(whole())
  }
  if b.lo == 0.0 {
    if z.lo > 0.0 {
      Some({ lo: next_down(z.lo / b.hi), hi: @double.infinity, })
    } else {
      Some({ lo: @double.neg_infinity, hi: next_up(z.hi / b.hi), })
    }
  } else {
    relational_divide(z.neg(), b.neg())
  }
}

///|
fn positive_nth_root(x : Double, k : Int32) -> Interval raise RootError {
  if k == 1 || x == 0.0 || x.is_pos_inf() {
    return point(x)
  }
  if k == 2 {
    return elementary_value(Sqrt, point(x))
  }
  let mut lo = 0L
  let mut hi = x.max(1.0).reinterpret_as_int64()
  while hi - lo > 1L {
    let mid = lo + (hi - lo) / 2L
    let y = point(mid.reinterpret_as_double()).power(k)
    if y.hi < x {
      lo = mid
    } else if y.lo > x {
      hi = mid
    } else {
      break
    }
  }
  { lo: lo.reinterpret_as_double(), hi: hi.reinterpret_as_double(), }
}

///|
fn inverse_power(
  z : Interval,
  current : Interval,
  k : Int32,
) -> Interval? raise RootError {
  if k == 0 {
    return if z.contains(1.0) { Some(current) } else { None }
  }
  if k % 2 == 1 {
    fn signed_root(t : Double, n : Int32) -> Interval raise RootError {
      if t < 0.0 {
        positive_nth_root(-t, n).neg()
      } else {
        positive_nth_root(t, n)
      }
    }
    return current.intersection({
      lo: signed_root(z.lo, k).lo,
      hi: signed_root(z.hi, k).hi,
    })
  }
  if z.hi < 0.0 {
    return None
  }
  let positive = {
    lo: positive_nth_root(z.lo.max(0.0), k).lo,
    hi: positive_nth_root(z.hi, k).hi,
  }
  match (current.intersection(positive), current.intersection(positive.neg())) {
    (Some(a), Some(b)) => Some(hull(a, b))
    (Some(a), None) | (None, Some(a)) => Some(a)
    _ => None
  }
}

///|
/// Every periodic inverse branch is retained, then hulled. Wide/huge arguments
/// skip inverse pruning rather than silently retaining only the principal branch.
fn periodic_inverse(
  op : Unary,
  target : Interval,
  current : Interval,
) -> Interval? {
  let z = match op {
    Tan => target
    _ =>
      match target.intersection({ lo: -1.0, hi: 1.0, }) {
        None => return None
        Some(x) => x
      }
  }
  if !current.finite() || current.magnitude() > 1.0e6 || current.width() > 64.0 {
    return Some(current)
  }
  let base = match op {
    Sin => elementary_value(Asin, z)
    Cos => elementary_value(Acos, z)
    _ => elementary_value(Atan, z)
  }
  let step = match op {
    Tan => pi_bounds()
    _ => pi_bounds().mul(point(2.0))
  }
  let first = (current.lo / step.midpoint()).to_int() - 3
  let last = (current.hi / step.midpoint()).to_int() + 3
  let mut result : Interval? = None
  for k = first; k <= last; k = k + 1 {
    let shift = point(k.to_double()).mul(step)
    let candidates = match op {
      Sin => [base.add(shift), pi_bounds().sub(base).add(shift)]
      Cos => [base.add(shift), base.neg().add(shift)]
      _ => [base.add(shift)]
    }
    for candidate in candidates {
      match current.intersection(candidate) {
        None => ()
        Some(c) =>
          result = Some(
            match result {
              None => c
              Some(r) => hull(r, c)
            },
          )
      }
    }
  }
  result
}

///|
fn inverse_unary(
  op : Unary,
  z : Interval,
  current : Interval,
) -> Interval? raise RootError {
  let r = match op {
    Sin | Cos | Tan => return periodic_inverse(op, z, current)
    Exp => {
      if z.hi <= 0.0 {
        return None
      }
      elementary_value(Log, z)
    }
    Log => z.exp()
    Sqrt => {
      let y = match z.intersection({ lo: 0.0, hi: @double.infinity, }) {
        None => return None
        Some(y) => y
      }
      y.power(2)
    }
    Abs => {
      let y = match z.intersection({ lo: 0.0, hi: @double.infinity, }) {
        None => return None
        Some(y) => y
      }
      match (current.intersection(y), current.intersection(y.neg())) {
        (Some(a), Some(b)) => hull(a, b)
        (Some(a), None) | (None, Some(a)) => a
        _ => return None
      }
    }
    Atan => {
      let y = match z.intersection(pi_bounds().mul({ lo: -0.5, hi: 0.5, })) {
        None => return None
        Some(y) => y
      }
      elementary_value(Tan, y)
    }
    Asin => {
      let y = match z.intersection(pi_bounds().mul({ lo: -0.5, hi: 0.5, })) {
        None => return None
        Some(y) => y
      }
      y.sin()
    }
    Acos => {
      let y = match z.intersection({ lo: 0.0, hi: pi_bounds().hi, }) {
        None => return None
        Some(y) => y
      }
      y.cos()
    }
    Sinh => {
      fn asinh_point(t : Double) -> Interval raise RootError {
        if t < 0.0 {
          return asinh_point(-t).neg()
        }
        if t.is_pos_inf() {
          return point(t)
        }
        let x = point(t)
        elementary_value(
          Log,
          x.add(elementary_value(Sqrt, x.power(2).add(point(1.0)))),
        )
      }
      { lo: asinh_point(z.lo).lo, hi: asinh_point(z.hi).hi, }
    }
    Cosh => {
      if z.hi < 1.0 {
        return None
      }
      fn acosh_point(t : Double) -> Interval raise RootError {
        let x = point(t.max(1.0))
        elementary_value(
          Log,
          x.add(elementary_value(Sqrt, x.power(2).sub(point(1.0)))),
        )
      }
      let y = { lo: acosh_point(z.lo).lo.max(0.0), hi: acosh_point(z.hi).hi, }
      match (current.intersection(y), current.intersection(y.neg())) {
        (Some(a), Some(b)) => hull(a, b)
        (Some(a), None) | (None, Some(a)) => a
        _ => return None
      }
    }
    Tanh => {
      let y = match z.intersection({ lo: -1.0, hi: 1.0, }) {
        None => return None
        Some(y) => y
      }
      fn atanh_point(t : Double) -> Interval {
        if t <= -1.0 {
          return point(@double.neg_infinity)
        }
        if t >= 1.0 {
          return point(@double.infinity)
        }
        let x = point(t)
        elementary_value(Log, point(1.0).add(x).div(point(1.0).sub(x))).mul(
          point(0.5),
        )
      }
      { lo: atanh_point(y.lo).lo, hi: atanh_point(y.hi).hi, }
    }
  }
  current.intersection(r)
}

///|
/// One HC4-style forward/backward sweep. Arrays belong to the contractor;
/// callers' input boxes are copied at the public boundary.
fn backward(
  e : Expr,
  wanted : Interval,
  box : Array[Interval],
) -> Bool raise RootError {
  let value = match expression_range_unchecked(e, box).range {
    None => return false
    Some(v) => v
  }
  let z = match value.intersection(wanted) {
    None => return false
    Some(v) => v
  }
  match e {
    Const(_) => true
    Variable(i) =>
      match box[i].intersection(z) {
        None => false
        Some(v) => {
          box[i] = v
          true
        }
      }
    Pow(a, k) => {
      let v = match inverse_power(z, range_unchecked(a, box), k) {
        None => return false
        Some(v) => v
      }
      backward(a, v, box)
    }
    Apply(op, a) => {
      let v = match inverse_unary(op, z, range_unchecked(a, box)) {
        None => return false
        Some(v) => v
      }
      backward(a, v, box)
    }
    Add(a, b) | Sub(a, b) | Mul(a, b) | Div(a, b) => {
      let x = range_unchecked(a, box)
      let y = range_unchecked(b, box)
      let left = match e {
        Add(_, _) => Some(z.sub(y))
        Sub(_, _) => Some(z.add(y))
        Mul(_, _) => relational_divide(z, y)
        _ => Some(z.mul(y))
      }
      match left {
        None => return false
        Some(t) => if !backward(a, t, box) { return false }
      }
      let x = match e {
        Div(_, _) => range_unchecked(a, box)
        _ => x
      }
      let right = match e {
        Add(_, _) => Some(z.sub(x))
        Sub(_, _) => Some(x.sub(z))
        Mul(_, _) => relational_divide(z, x)
        _ => relational_divide(x, z)
      }
      match right {
        None => false
        Some(t) => backward(b, t, box)
      }
    }
  }
}

///|
fn variables_used(e : Expr, mask : Array[Bool]) -> Unit {
  match e {
    Const(_) => ()
    Variable(i) => mask[i] = true
    Pow(a, _) | Apply(_, a) => variables_used(a, mask)
    Add(a, b) | Sub(a, b) | Mul(a, b) | Div(a, b) => {
      variables_used(a, mask)
      variables_used(b, mask)
    }
  }
}

///|
/// Preconditioned interval Gauss-Seidel for J(X)*(x-c) in allowed-F(c).
/// A zero-containing diagonal is skipped, not divided away or declared empty.
fn newton_bands(
  model : ConstraintModel,
  box : Array[Interval],
) -> Bool raise RootError {
  let n = box.length()
  let center = box.map(x => x.midpoint())
  if model.constraints.length() >= n {
    let cs = Array::makei(n, i => model.constraints[i])
    let sys = { names: model.names, equations: cs.map(c => c.polynomial), }
    let ev = evaluate_unchecked(sys, box)
    let mid = evaluate_unchecked(sys, center.map(point))
    if ev.fully_defined && ev.smooth && mid.fully_defined {
      match inverse(mid.jacobian.map(row => row.map(x => x.midpoint()))) {
        None => ()
        Some(y) => {
          let matrix = Array::makei(n, i => {
            Array::makei(n, j => {
              let mut t = point(0.0)
              for k = 0; k < n; k = k + 1 {
                t = t.add(point(y[i][k]).mul(ev.jacobian[k][j]))
              }
              t
            })
          })
          let rhs = Array::makei(n, i => {
            let mut t = point(0.0)
            for k = 0; k < n; k = k + 1 {
              t = t.add(point(y[i][k]).mul(cs[k].allowed.sub(mid.ranges[k])))
            }
            t
          })
          for i = 0; i < n; i = i + 1 {
            if matrix[i][i].contains(0.0) {
              continue
            }
            let mut t = rhs[i]
            for j = 0; j < n; j = j + 1 {
              if i != j {
                t = t.sub(matrix[i][j].mul(box[j].sub(point(center[j]))))
              }
            }
            let image = point(center[i]).add(t.div(matrix[i][i]))
            match box[i].intersection(image) {
              None => return false
              Some(v) => box[i] = v
            }
          }
        }
      }
    }
  }
  // Coordinate interval Newton also handles under/overdetermined observation bands.
  for c in model.constraints {
    let state = expression_range_unchecked(c.polynomial, box)
    if !state.fully_defined || !state.smooth {
      continue
    }
    let (_, gradient) = dual(c.polynomial, box)
    for i = 0; i < n; i = i + 1 {
      if gradient[i].contains(0.0) {
        continue
      }
      let fixed = box.map(x => x)
      let m = box[i].midpoint()
      fixed[i] = point(m)
      let f = range_unchecked(c.polynomial, fixed)
      let image = point(m).add(c.allowed.sub(f).div(gradient[i]))
      match box[i].intersection(image) {
        None => return false
        Some(v) => box[i] = v
      }
    }
  }
  true
}

///|
fn validate_contractors(options : ContractorOptions) -> Unit raise RootError {
  guard options.max_steps >= 1 &&
    options.max_steps <= 16384 &&
    options.max_rounds >= 1 &&
    options.max_rounds <= 32 else {
    raise Invalid("contractor max_steps must be 1..16384 and max_rounds 1..32")
  }
}

///|
fn contract_unchecked(
  model : ConstraintModel,
  initial : Array[Interval],
  config : ContractorOptions,
) -> Contraction raise RootError {
  let box = initial.map(x => x)
  let masks = model.constraints.map(c => {
    let mask = Array::make(box.length(), false)
    variables_used(c.polynomial, mask)
    mask
  })
  let mut calls = 0
  let mut propagation_calls = 0
  let mut newton_calls = 0
  let mut rounds = 0
  let mut fixed_point = false
  while rounds < config.max_rounds && calls < config.max_steps {
    rounds = rounds + 1
    let previous = box.map(x => x)
    let mut propagation_complete = true
    if config.propagation {
      let agenda = Array::make(model.constraints.length(), true)
      // Bound each propagation phase so a cyclic agenda cannot starve Newton.
      let reserve = if config.newton && config.max_steps - calls > 1 {
        1
      } else {
        0
      }
      let phase_end = (calls + model.constraints.length() * 4).min(
        config.max_steps - reserve,
      )
      while agenda.any(x => x) && calls < phase_end {
        let mut index = 0
        while !agenda[index] {
          index = index + 1
        }
        agenda[index] = false
        let before = box.map(x => x)
        calls = calls + 1
        propagation_calls = propagation_calls + 1
        let c = model.constraints[index]
        if !backward(c.polynomial, c.allowed, box) {
          return {
            box: None,
            calls,
            rounds,
            changed: true,
            fixed_point: true,
            budget_exhausted: false,
            propagation_calls,
            newton_calls,
          }
        }
        for j = 0; j < agenda.length(); j = j + 1 {
          for i = 0; i < box.length(); i = i + 1 {
            if masks[j][i] && box[i] != before[i] {
              agenda[j] = true
            }
          }
        }
      }
      propagation_complete = !agenda.any(x => x)
    }
    if config.newton && calls < config.max_steps {
      calls = calls + 1
      newton_calls = newton_calls + 1
      if !newton_bands(model, box) {
        return {
          box: None,
          calls,
          rounds,
          changed: true,
          fixed_point: true,
          budget_exhausted: false,
          propagation_calls,
          newton_calls,
        }
      }
    }
    if propagation_complete && same_box(previous, box) {
      fixed_point = true
      break
    }
  }
  {
    box: Some(box),
    calls,
    rounds,
    changed: !same_box(initial, box),
    fixed_point,
    budget_exhausted: !fixed_point &&
    (calls >= config.max_steps || rounds >= config.max_rounds),
    propagation_calls,
    newton_calls,
  }
}

///|
pub fn contract_constraints(
  model : ConstraintModel,
  initial : Array[Interval],
  config : ContractorOptions,
) -> Contraction raise RootError {
  validate_constraints(model)
  check_box(initial, model.names.length())
  validate_contractors(config)
  contract_unchecked(model, initial, config)
}

///|
/// Interval Newton only, independently callable for comparisons and composition.
pub fn interval_newton(
  system : System,
  initial : Array[Interval],
  max_rounds~ : Int32 = 4,
) -> Contraction raise RootError {
  validate_system(system)
  let model = {
    names: system.names,
    constraints: system.equations.map(e => {
      polynomial: e,
      allowed: point(0.0),
    }),
  }
  contract_constraints(model, initial, {
    propagation: false,
    newton: true,
    max_steps: 128,
    max_rounds,
  })
}
