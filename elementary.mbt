///|
/// Elementary functions use interval series/remainder bounds, not an assumed
/// error bound on the host's libm. Arguments beyond the reduction budget widen.
pub(all) enum Unary {
  Sin
  Cos
  Tan
  Exp
  Log
  Sqrt
  Abs
  Atan
  Asin
  Acos
  Sinh
  Cosh
  Tanh
}

///|
pub extend Unary with @debug.Debug::{to_repr}

///|
pub impl @debug.Debug for Unary with fn to_repr(self) {
  @debug.Repr(
    match self {
      Sin => "sin"
      Cos => "cos"
      Tan => "tan"
      Exp => "exp"
      Log => "log"
      Sqrt => "sqrt"
      Abs => "abs"
      Atan => "atan"
      Asin => "asin"
      Acos => "acos"
      Sinh => "sinh"
      Cosh => "cosh"
      Tanh => "tanh"
    },
  )
}

///|
pub(all) struct DomainRange {
  range : Interval?
  fully_defined : Bool
  smooth : Bool
}

///|
fn pi_bounds() -> Interval {
  { lo: 3.141592653589793, hi: 3.1415926535897936, }
}

///|
fn hull(a : Interval, b : Interval) -> Interval {
  { lo: a.lo.min(b.lo), hi: a.hi.max(b.hi), }
}

///|
pub fn Interval::div(self : Interval, b : Interval) -> Interval {
  if b.contains(0.0) {
    return whole()
  }
  self.mul({ lo: next_down(1.0 / b.hi), hi: next_up(1.0 / b.lo), })
}

///|
pub fn Interval::abs(self : Interval) -> Interval {
  if self.lo >= 0.0 {
    self
  } else if self.hi <= 0.0 {
    self.neg()
  } else {
    { lo: 0.0, hi: self.magnitude(), }
  }
}

///|
/// Valid division over defined points; a zero denominator is never a solution.
fn divided(a : Interval, b : Interval) -> DomainRange {
  if b.lo == 0.0 && b.hi == 0.0 {
    { range: None, fully_defined: false, smooth: false, }
  } else if b.contains(0.0) {
    {
      range: Some(if a.lo == 0.0 && a.hi == 0.0 { point(0.0) } else { whole() }),
      fully_defined: false,
      smooth: false,
    }
  } else {
    { range: Some(a.div(b)), fully_defined: true, smooth: true, }
  }
}

///|
fn exp_scalar(x : Double) -> Interval {
  if x.is_neg_inf() {
    return point(0.0)
  }
  if x > 1024.0 {
    return { lo: next_down(@double.infinity), hi: @double.infinity, }
  }
  if x < -1024.0 {
    return { lo: 0.0, hi: 2.2250738585072014e-308, }
  }
  if x == 0.0 {
    return point(1.0)
  }
  let mut r = x
  let mut k = 0
  while r.abs() > 0.5 {
    r = r * 0.5
    k = k + 1
  }
  let mut term = point(1.0)
  let mut sum = term
  for n = 1; n <= 20; n = n + 1 {
    term = term.mul(point(r)).div(point(n.to_double()))
    sum = sum.add(term)
  }
  // exp(|r|)<2, so the degree-20 remainder is < 2*(1/2)^21/21! < 1.0e-24.
  sum = sum.add({ lo: -1.0e-24, hi: 1.0e-24, })
  for i = 0; i < k; i = i + 1 {
    sum = sum.mul(sum)
  }
  { lo: sum.lo.max(0.0), hi: sum.hi, }
}

///|
pub fn Interval::exp(self : Interval) -> Interval {
  { lo: exp_scalar(self.lo).lo, hi: exp_scalar(self.hi).hi, }
}

///|
fn log_scalar(x : Double) -> Interval {
  if x <= 0.0 {
    return point(@double.neg_infinity)
  }
  if x.is_pos_inf() {
    return point(@double.infinity)
  }
  if x == 1.0 {
    return point(0.0)
  }
  let mut m = x
  let mut k = 0
  while m < 1.0 {
    m = m * 2.0
    k = k - 1
  }
  while m >= 2.0 {
    m = m * 0.5
    k = k + 1
  }
  let z = point(m).sub(point(1.0)).div(point(m).add(point(1.0)))
  let square = z.mul(z)
  let mut term = z
  let mut sum = z
  for n = 1; n <= 24; n = n + 1 {
    term = term.mul(square)
    sum = sum.add(term.div(point((2 * n + 1).to_double())))
  }
  // |z| < .34; remainder after z^49/49 is < 2*.34^51/(51*(1-.34^2)) < 1.0e-23.
  sum
  .mul(point(2.0))
  .add({ lo: -1.0e-23, hi: 1.0e-23, })
  .add(
    point(k.to_double()).mul({ lo: 0.6931471805599453, hi: 0.6931471805599454, }),
  )
}

///|
/// Binary search on positive floating-point bit patterns. Comparing x/c with c
/// avoids squaring overflow/underflow; the hull of c and x/c brackets sqrt(x).
fn sqrt_scalar(x : Double) -> Interval {
  if x == 0.0 || x.is_pos_inf() {
    return point(x)
  }
  let mut low = 0L
  let mut high = x.max(1.0).reinterpret_as_int64()
  while high - low > 1L {
    let mid = low + (high - low) / 2L
    let c = mid.reinterpret_as_double()
    let q = { lo: next_down(x / c), hi: next_up(x / c), }
    if q.lo > c {
      low = mid
    } else if q.hi < c {
      high = mid
    } else {
      return hull(point(c), q)
    }
  }
  { lo: low.reinterpret_as_double(), hi: high.reinterpret_as_double(), }
}

///|
fn trig_scalar(x : Double, cosine : Bool) -> Interval {
  if x.abs() > 1.0e6 || x.is_inf() {
    return { lo: -1.0, hi: 1.0, }
  }
  if x == 0.0 {
    return point(if cosine { 1.0 } else { 0.0 })
  }
  let k = (x / 1.5707963267948966).to_int()
  let r = point(x).sub(point(k.to_double()).mul(pi_bounds().mul(point(0.5))))
  // Truncation gives |r| up to pi/2, so reduce one extra quadrant if needed.
  if r.magnitude() > 1.0 {
    let step = if x > 0.0 { 1 } else { -1 }
    return trig_reduced(x, k + step, cosine)
  }
  trig_series(r, k, cosine)
}

///|
fn trig_reduced(x : Double, k : Int32, cosine : Bool) -> Interval {
  let r = point(x).sub(point(k.to_double()).mul(pi_bounds().mul(point(0.5))))
  if r.magnitude() > 1.0 {
    return { lo: -1.0, hi: 1.0, }
  }
  trig_series(r, k, cosine)
}

///|
fn trig_series(r : Interval, k : Int32, cosine : Bool) -> Interval {
  let quadrant = (k % 4 + 4) % 4
  let use_cos = if cosine { quadrant % 2 == 0 } else { quadrant % 2 == 1 }
  let negative = if cosine {
    quadrant == 1 || quadrant == 2
  } else {
    quadrant == 2 || quadrant == 3
  }
  let mut term = if use_cos { point(1.0) } else { r }
  let mut sum = term
  let minus_square = r.mul(r).neg()
  for n = 1; n <= 12; n = n + 1 {
    let a = if use_cos { 2 * n - 1 } else { 2 * n }
    term = term.mul(minus_square).div(point((a * (a + 1)).to_double()))
    sum = sum.add(term)
  }
  // |r|<=1; both omitted Taylor tails are less than 1/26! < 1.0e-25.
  sum = sum.add({ lo: -1.0e-25, hi: 1.0e-25, })
  if negative {
    sum = sum.neg()
  }
  { lo: sum.lo.max(-1.0), hi: sum.hi.min(1.0), }
}

///|
fn trig_range(x : Interval, cosine : Bool) -> Interval {
  if !x.finite() || x.magnitude() > 1.0e6 || x.width() >= 6.283185307179586 {
    return { lo: -1.0, hi: 1.0, }
  }
  let mut r = hull(trig_scalar(x.lo, cosine), trig_scalar(x.hi, cosine))
  let first = (x.lo / 1.5707963267948966).to_int() - 2
  let last = (x.hi / 1.5707963267948966).to_int() + 2
  for k = first; k <= last; k = k + 1 {
    let critical = pi_bounds().mul(point(k.to_double() * 0.5))
    if critical.intersection(x) is Some(_) {
      let q = (k % 4 + 4) % 4
      if (cosine && q == 0) || (!cosine && q == 1) {
        r = hull(r, point(1.0))
      }
      if (cosine && q == 2) || (!cosine && q == 3) {
        r = hull(r, point(-1.0))
      }
    }
  }
  r
}

///|
pub fn Interval::sin(self : Interval) -> Interval {
  trig_range(self, false)
}

///|
pub fn Interval::cos(self : Interval) -> Interval {
  trig_range(self, true)
}

///|
fn atan_scalar(x : Double) -> Interval {
  if x < 0.0 {
    return atan_scalar(-x).neg()
  }
  if x > 1.0 {
    return pi_bounds()
      .mul(point(0.5))
      .sub({
        lo: atan_scalar(next_down(1.0 / x).max(0.0)).lo,
        hi: atan_scalar(next_up(1.0 / x)).hi,
      })
  }
  // The reciprocal reduction must enclose the rounded 1/x, not treat it as exact.
  let z = if x > 0.5 {
    point(x).sub(point(1.0)).div(point(x).add(point(1.0)))
  } else {
    point(x)
  }
  let mut term = z
  let mut sum = z
  let square = z.mul(z).neg()
  for n = 1; n <= 40; n = n + 1 {
    term = term.mul(square)
    sum = sum.add(term.div(point((2 * n + 1).to_double())))
  }
  let result = sum.add({ lo: -1.0e-25, hi: 1.0e-25, })
  if x > 0.5 {
    pi_bounds().mul(point(0.25)).add(result)
  } else {
    result
  }
}

///|
fn atan_range(x : Interval) -> Interval {
  // Apply the reciprocal identity with an outward reciprocal interval.
  fn endpoint(x : Double) -> Interval {
    if x < 0.0 {
      return endpoint(-x).neg()
    }
    if x > 1.0 {
      let a = next_down(1.0 / x).max(0.0)
      let b = next_up(1.0 / x)
      return pi_bounds()
        .mul(point(0.5))
        .sub({ lo: atan_scalar(a).lo, hi: atan_scalar(b).hi, })
    }
    atan_scalar(x)
  }
  { lo: endpoint(x.lo).lo, hi: endpoint(x.hi).hi, }
}

///|
fn asin_scalar(x : Double) -> Interval {
  if x == 0.0 {
    return point(0.0)
  }
  if x == 1.0 {
    return pi_bounds().mul(point(0.5))
  }
  if x < 0.0 {
    return asin_scalar(-x).neg()
  }
  let mut lo = 0.0
  let mut hi = pi_bounds().hi * 0.5
  for i = 0; i < 64; i = i + 1 {
    let mid = lo * 0.5 + hi * 0.5
    if !(mid > lo && mid < hi) {
      break
    }
    let v = trig_scalar(mid, false)
    if v.hi < x {
      lo = mid
    } else if v.lo > x {
      hi = mid
    } else {
      let a = lo * 0.5 + mid * 0.5
      let b = mid * 0.5 + hi * 0.5
      let old_lo = lo
      let old_hi = hi
      if trig_scalar(a, false).hi < x {
        lo = a
      }
      if trig_scalar(b, false).lo > x {
        hi = b
      }
      if lo == old_lo && hi == old_hi {
        break
      }
    }
  }
  { lo, hi, }
}

///|
pub fn elementary(op : Unary, x : Interval) -> DomainRange {
  let mut total = true
  let mut smooth = true
  let r = match op {
    Sin => x.sin()
    Cos => x.cos()
    Tan => {
      let c = x.cos()
      if c.contains(0.0) {
        total = false
        smooth = false
        whole()
      } else {
        x.sin().div(c)
      }
    }
    Exp => x.exp()
    Log => {
      if x.hi <= 0.0 {
        return { range: None, fully_defined: false, smooth: false, }
      }
      total = x.lo > 0.0
      smooth = total
      {
        lo: if total {
          log_scalar(x.lo).lo
        } else {
          @double.neg_infinity
        },
        hi: log_scalar(x.hi).hi,
      }
    }
    Sqrt => {
      if x.hi < 0.0 {
        return { range: None, fully_defined: false, smooth: false, }
      }
      total = x.lo >= 0.0
      smooth = x.lo > 0.0
      { lo: sqrt_scalar(x.lo.max(0.0)).lo, hi: sqrt_scalar(x.hi).hi, }
    }
    Abs => {
      smooth = x.lo > 0.0 || x.hi < 0.0
      x.abs()
    }
    Atan => atan_range(x)
    Asin | Acos => {
      let clipped = match x.intersection({ lo: -1.0, hi: 1.0, }) {
        None => return { range: None, fully_defined: false, smooth: false, }
        Some(a) => a
      }
      total = x.lo >= -1.0 && x.hi <= 1.0
      smooth = x.lo > -1.0 && x.hi < 1.0
      let a = {
        lo: asin_scalar(clipped.lo).lo,
        hi: asin_scalar(clipped.hi).hi,
      }
      match op {
        Acos => pi_bounds().mul(point(0.5)).sub(a)
        _ => a
      }
    }
    Sinh => x.exp().sub(x.neg().exp()).mul(point(0.5))
    Cosh => {
      let a = x.abs()
      fn c(t : Double) -> Interval {
        point(t).exp().add(point(-t).exp()).mul(point(0.5))
      }
      { lo: c(a.lo).lo.max(1.0), hi: c(a.hi).hi, }
    }
    Tanh => {
      fn t(v : Double) -> Interval {
        let e = point(v.abs()).mul(point(-2.0)).exp()
        let r = point(1.0).sub(e).div(point(1.0).add(e))
        if v < 0.0 {
          r.neg()
        } else {
          r
        }
      }
      { lo: t(x.lo).lo.max(-1.0), hi: t(x.hi).hi.min(1.0), }
    }
  }
  { range: Some(r), fully_defined: total, smooth, }
}

///|
fn elementary_value(op : Unary, x : Interval) -> Interval {
  elementary(op, x).range.unwrap_or(whole())
}
