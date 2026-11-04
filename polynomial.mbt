///|
/// Polynomial expressions use exact binary64 input constants; no transcendental functions.
pub(all) enum Expr {
  Const(Double)
  Variable(Int32)
  Add(Expr, Expr)
  Sub(Expr, Expr)
  Mul(Expr, Expr)
  Pow(Expr, Int32)
} derive(Debug)

///|
pub extend Expr with @debug.Debug::{to_repr}

///|
/// A square polynomial system, with 1..6 named variables.
pub(all) struct System {
  names : Array[String]
  equations : Array[Expr]
}

///|
pub(all) struct Evaluation {
  ranges : Array[Interval]
  jacobian : Array[Array[Interval]]
}

///|
fn valid_name(s : String) -> Bool {
  if s.length() == 0 || s.length() > 32 {
    return false
  }
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i].to_int()
    if !((c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122) ||
      c == 95 ||
      (i > 0 && c >= 48 && c <= 57)) {
      return false
    }
  }
  true
}

///|
fn check_expr(
  e : Expr,
  n : Int32,
  depth : Int32,
  count : Ref[Int32],
) -> Int32 raise RootError {
  count.val = count.val + 1
  guard depth <= 32 && count.val <= 512 else {
    raise Invalid("expression size/depth limit exceeded")
  }
  let degree = match e {
    Const(x) => {
      guard !x.is_nan() && !x.is_inf() else {
        raise Invalid("nonfinite constant")
      }
      0
    }
    Variable(i) => {
      guard i >= 0 && i < n else { raise Invalid("unknown variable index") }
      1
    }
    Add(a, b) | Sub(a, b) =>
      check_expr(a, n, depth + 1, count).max(check_expr(b, n, depth + 1, count))
    Mul(a, b) =>
      check_expr(a, n, depth + 1, count) + check_expr(b, n, depth + 1, count)
    Pow(a, k) => {
      guard k >= 0 && k <= 16 else { raise Invalid("power must be in 0..16") }
      check_expr(a, n, depth + 1, count) * k
    }
  }
  guard degree <= 32 else {
    raise Invalid("total polynomial degree exceeds 32")
  }
  degree
}

///|
pub fn validate_system(system : System) -> Unit raise RootError {
  let n = system.names.length()
  guard n >= 1 && n <= 6 && system.equations.length() == n else {
    raise Invalid("require 1..6 variables and equally many equations")
  }
  for i = 0; i < n; i = i + 1 {
    guard valid_name(system.names[i]) else {
      raise Invalid("variable names must be ASCII identifiers of length 1..32")
    }
    for j = 0; j < i; j = j + 1 {
      guard system.names[i] != system.names[j] else {
        raise Invalid("duplicate variable name")
      }
    }
  }
  let count = Ref(0)
  for e in system.equations {
    let _ = check_expr(e, n, 0, count)
  }
}

///|
fn check_box(box : Array[Interval], n : Int32) -> Unit raise RootError {
  guard box.length() == n else { raise Invalid("box dimension mismatch") }
  for a in box {
    guard a.finite() else {
      raise Invalid("box must have finite ordered endpoints")
    }
  }
}

///|
/// Interval forward-mode differentiation. All scalar operations enclose rounding.
fn dual(
  e : Expr,
  box : Array[Interval],
) -> (Interval, Array[Interval]) raise RootError {
  let n = box.length()
  match e {
    Const(x) => (point(x), Array::make(n, point(0.0)))
    Variable(i) =>
      (box[i], Array::makei(n, j => point(if i == j { 1.0 } else { 0.0 })))
    Add(a, b) => {
      let (v, g) = dual(a, box)
      let (w, h) = dual(b, box)
      (v.add(w), Array::makei(n, i => g[i].add(h[i])))
    }
    Sub(a, b) => {
      let (v, g) = dual(a, box)
      let (w, h) = dual(b, box)
      (v.sub(w), Array::makei(n, i => g[i].sub(h[i])))
    }
    Mul(a, b) => {
      let (v, g) = dual(a, box)
      let (w, h) = dual(b, box)
      (v.mul(w), Array::makei(n, i => g[i].mul(w).add(v.mul(h[i]))))
    }
    Pow(a, k) => {
      let (v, g) = dual(a, box)
      let d = if k == 0 {
        point(0.0)
      } else {
        point(k.to_double()).mul(v.power(k - 1))
      }
      (v.power(k), g.map(x => d.mul(x)))
    }
  }
}

///|
fn evaluate_unchecked(
  system : System,
  box : Array[Interval],
) -> Evaluation raise RootError {
  let ranges : Array[Interval] = []
  let jacobian : Array[Array[Interval]] = []
  for e in system.equations {
    let (v, g) = dual(e, box)
    ranges.push(v)
    jacobian.push(g)
  }
  { ranges, jacobian, }
}

///|
/// Enclose every polynomial and Jacobian entry on a finite closed box.
pub fn enclose(
  system : System,
  box : Array[Interval],
) -> Evaluation raise RootError {
  validate_system(system)
  check_box(box, system.names.length())
  evaluate_unchecked(system, box)
}
