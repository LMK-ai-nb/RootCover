///|
/// Closed interval. NaN endpoints are never constructed by public helpers.
pub(all) struct Interval {
  lo : Double
  hi : Double
} derive(Eq, Debug)

///|
pub suberror RootError {
  Invalid(String)
} derive(Debug)

///|
/// Adjacent IEEE-754 binary64 value, with gradual underflow.
pub fn next_up(x : Double) -> Double {
  if x.is_nan() || x.is_pos_inf() {
    return x
  }
  if x == 0.0 {
    return 1L.reinterpret_as_double()
  }
  let bits = x.reinterpret_as_int64()
  (if x > 0.0 { bits + 1L } else { bits - 1L }).reinterpret_as_double()
}

///|
pub fn next_down(x : Double) -> Double {
  -next_up(-x)
}

///|
pub fn interval(lo : Double, hi : Double) -> Interval raise RootError {
  guard !lo.is_nan() && !hi.is_nan() && lo <= hi else {
    raise Invalid("invalid interval endpoints")
  }
  { lo, hi, }
}

///|
fn point(x : Double) -> Interval {
  { lo: x, hi: x, }
}

///|
fn whole() -> Interval {
  { lo: @double.neg_infinity, hi: @double.infinity, }
}

///|
pub fn Interval::contains(self : Interval, x : Double) -> Bool {
  self.lo <= x && x <= self.hi
}

///|
pub fn Interval::width(self : Interval) -> Double {
  next_up(self.hi - self.lo)
}

///|
pub fn Interval::midpoint(self : Interval) -> Double {
  (self.lo / 2.0 + self.hi / 2.0).max(self.lo).min(self.hi)
}

///|
pub fn Interval::add(self : Interval, other : Interval) -> Interval {
  let a = self.lo + other.lo
  let b = self.hi + other.hi
  if a.is_nan() || b.is_nan() {
    whole()
  } else {
    { lo: next_down(a), hi: next_up(b), }
  }
}

///|
pub fn Interval::neg(self : Interval) -> Interval {
  { lo: -self.hi, hi: -self.lo, }
}

///|
pub fn Interval::sub(self : Interval, other : Interval) -> Interval {
  self.add(other.neg())
}

///|
pub fn Interval::mul(self : Interval, other : Interval) -> Interval {
  if (self.lo == 0.0 && self.hi == 0.0) || (other.lo == 0.0 && other.hi == 0.0) {
    return point(0.0)
  }
  let xs = [
    self.lo * other.lo,
    self.lo * other.hi,
    self.hi * other.lo,
    self.hi * other.hi,
  ]
  if xs.any(x => x.is_nan()) {
    return whole()
  }
  let mut lo = xs[0]
  let mut hi = xs[0]
  for x in xs {
    lo = lo.min(x)
    hi = hi.max(x)
  }
  { lo: next_down(lo), hi: next_up(hi), }
}

///|
/// Integer powers exploit even-power nonnegativity, while enclosing rounding.
pub fn Interval::power(self : Interval, n : Int32) -> Interval raise RootError {
  guard n >= 0 && n <= 16 else { raise Invalid("power must be in 0..16") }
  if n == 0 {
    return point(1.0)
  }
  if n == 1 {
    return self
  }
  if n % 2 == 0 {
    let h = self.power(n / 2)
    let m = h.mul(h)
    if h.contains(0.0) {
      { lo: 0.0, hi: m.hi, }
    } else {
      { lo: m.lo.max(0.0), hi: m.hi, }
    }
  } else {
    self.power(n - 1).mul(self)
  }
}

///|
pub fn Interval::intersection(self : Interval, other : Interval) -> Interval? {
  let lo = self.lo.max(other.lo)
  let hi = self.hi.min(other.hi)
  if lo <= hi {
    Some({ lo, hi, })
  } else {
    None
  }
}

///|
pub fn Interval::magnitude(self : Interval) -> Double {
  self.lo.abs().max(self.hi.abs())
}

///|
pub fn Interval::finite(self : Interval) -> Bool {
  !self.lo.is_nan() &&
  !self.hi.is_nan() &&
  !self.lo.is_inf() &&
  !self.hi.is_inf() &&
  self.lo <= self.hi
}

///|
pub extend Interval with Eq::{equal, not_equal}

///|
pub extend Interval with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend RootError with @moonbitlang/core/debug.Debug::{to_repr}
