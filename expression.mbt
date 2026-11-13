///|
/// Evaluates only defined points and records whether *every* point is defined
/// and differentiable. An empty range proves the entire expression undefined.
fn expression_range_unchecked(
  e : Expr,
  box : Array[Interval],
) -> DomainRange raise RootError {
  match e {
    Const(x) => { range: Some(point(x)), fully_defined: true, smooth: true, }
    Variable(i) => { range: Some(box[i]), fully_defined: true, smooth: true, }
    Apply(op, a) => {
      let v = expression_range_unchecked(a, box)
      match v.range {
        None => v
        Some(x) => {
          let w = elementary(op, x)
          {
            range: w.range,
            fully_defined: v.fully_defined && w.fully_defined,
            smooth: v.smooth && w.smooth,
          }
        }
      }
    }
    Pow(a, k) => {
      let v = expression_range_unchecked(a, box)
      {
        range: v.range.map(x => x.power(k)),
        fully_defined: v.fully_defined,
        smooth: v.smooth,
      }
    }
    Add(a, b) | Sub(a, b) | Mul(a, b) | Div(a, b) => {
      let v = expression_range_unchecked(a, box)
      let w = expression_range_unchecked(b, box)
      match (v.range, w.range) {
        (Some(x), Some(y)) => {
          let z = match e {
            Add(_, _) =>
              { range: Some(x.add(y)), fully_defined: true, smooth: true, }
            Sub(_, _) =>
              { range: Some(x.sub(y)), fully_defined: true, smooth: true, }
            Mul(_, _) =>
              { range: Some(x.mul(y)), fully_defined: true, smooth: true, }
            _ => divided(x, y)
          }
          {
            range: z.range,
            fully_defined: v.fully_defined && w.fully_defined && z.fully_defined,
            smooth: v.smooth && w.smooth && z.smooth,
          }
        }
        _ => { range: None, fully_defined: false, smooth: false, }
      }
    }
  }
}

///|
pub fn evaluate_expression(
  e : Expr,
  box : Array[Interval],
) -> DomainRange raise RootError {
  check_box(box, box.length())
  let _ = check_expr(e, box.length(), 0, Ref(0))
  expression_range_unchecked(e, box)
}

///|
fn unary_slope(op : Unary, v : Interval) -> Interval {
  let state = elementary(op, v)
  if !state.fully_defined || !state.smooth {
    return whole()
  }
  match op {
    Sin => v.cos()
    Cos => v.sin().neg()
    Tan => point(1.0).div(v.cos().mul(v.cos()))
    Exp => v.exp()
    Log => point(1.0).div(v)
    Sqrt => point(1.0).div(point(2.0).mul(elementary_value(Sqrt, v)))
    Abs => point(if v.lo > 0.0 { 1.0 } else { -1.0 })
    Atan => point(1.0).div(point(1.0).add(v.mul(v)))
    Asin | Acos => {
      let d = point(1.0).div(elementary_value(Sqrt, point(1.0).sub(v.mul(v))))
      match op {
        Acos => d.neg()
        _ => d
      }
    }
    Sinh => elementary_value(Cosh, v)
    Cosh => elementary_value(Sinh, v)
    Tanh =>
      point(1.0).sub(elementary_value(Tanh, v).power(2) catch { _ => whole() })
  }
}
