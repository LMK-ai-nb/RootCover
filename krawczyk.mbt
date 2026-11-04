///| A replayable contraction certificate. `domain` contains exactly one root;

///|
/// that root lies in `enclosure`. q bounds ||I - Y J(domain)||_infinity.
pub(all) struct Certificate {
  domain : Array[Interval]
  center : Array[Double]
  preconditioner : Array[Array[Double]]
  image : Array[Interval]
  enclosure : Array[Interval]
  q : Double
}

///|
pub(all) enum Assessment {
  Excluded(String)
  Unique(Certificate)
  Contracted(Array[Interval])
  Undecided(String)
}

///|
/// A floating approximation is only a preconditioner; proof arithmetic is interval arithmetic.
fn inverse(m : Array[Array[Double]]) -> Array[Array[Double]]? {
  let n = m.length()
  let a = m.map(row => row.map(x => x))
  let inv = Array::makei(n, i => {
    Array::makei(n, j => if i == j { 1.0 } else { 0.0 })
  })
  for col = 0; col < n; col = col + 1 {
    let mut pivot = col
    for i = col + 1; i < n; i = i + 1 {
      if a[i][col].abs() > a[pivot][col].abs() {
        pivot = i
      }
    }
    let d = a[pivot][col]
    if d == 0.0 || d.is_nan() || d.is_inf() {
      return None
    }
    let tmp = a[col]
    a[col] = a[pivot]
    a[pivot] = tmp
    let tmp = inv[col]
    inv[col] = inv[pivot]
    inv[pivot] = tmp
    for j = 0; j < n; j = j + 1 {
      a[col][j] = a[col][j] / d
      inv[col][j] = inv[col][j] / d
    }
    for i = 0; i < n; i = i + 1 {
      if i != col {
        let ratio = a[i][col]
        for j = 0; j < n; j = j + 1 {
          a[i][j] = a[i][j] - ratio * a[col][j]
          inv[i][j] = inv[i][j] - ratio * inv[col][j]
        }
      }
    }
  }
  if inv.any(row => row.any(x => x.is_nan() || x.is_inf())) {
    None
  } else {
    Some(inv)
  }
}

///|
fn max_width(box : Array[Interval]) -> Double {
  let mut w = 0.0
  for a in box {
    w = w.max(a.width())
  }
  w
}

///|
fn assess_unchecked(
  system : System,
  box : Array[Interval],
) -> Assessment raise RootError {
  let n = box.length()
  let ev = evaluate_unchecked(system, box)
  if ev.ranges.any(x => !x.contains(0.0)) {
    return Excluded("polynomial range excludes zero")
  }
  let center = box.map(x => x.midpoint())
  let at_center = evaluate_unchecked(system, center.map(point))
  let y = match
    inverse(at_center.jacobian.map(row => row.map(x => x.midpoint()))) {
    Some(y) => y
    None => return Undecided("midpoint Jacobian is singular or nonfinite")
  }
  let b = Array::makei(n, i => {
    Array::makei(n, j => {
      let mut t = point(if i == j { 1.0 } else { 0.0 })
      for k = 0; k < n; k = k + 1 {
        t = t.sub(point(y[i][k]).mul(ev.jacobian[k][j]))
      }
      t
    })
  })
  let mut q = 0.0
  for row in b {
    let mut sum = 0.0
    for t in row {
      sum = next_up(sum + t.magnitude())
    }
    q = q.max(sum)
  }
  let image = Array::makei(n, i => {
    let mut t = point(center[i])
    for k = 0; k < n; k = k + 1 {
      t = t.sub(point(y[i][k]).mul(at_center.ranges[k]))
    }
    for j = 0; j < n; j = j + 1 {
      t = t.add(b[i][j].mul(box[j].sub(point(center[j]))))
    }
    t
  })
  let narrowed : Array[Interval] = []
  let mut strict = q < 1.0
  for i = 0; i < n; i = i + 1 {
    match box[i].intersection(image[i]) {
      None => return Excluded("Krawczyk image is disjoint from the box")
      Some(x) => narrowed.push(x)
    }
    if !(image[i].lo > box[i].lo && image[i].hi < box[i].hi) {
      strict = false
    }
  }
  if strict {
    Unique({
      domain: box.map(x => x),
      center,
      preconditioner: y,
      image,
      enclosure: narrowed,
      q,
    })
  } else if max_width(narrowed) < max_width(box) * 0.8 {
    Contracted(narrowed)
  } else {
    Undecided("no exclusion or strict contraction proved")
  }
}

///|
/// Analyze one finite box. A small residual alone is never a uniqueness certificate.
pub fn assess(
  system : System,
  box : Array[Interval],
) -> Assessment raise RootError {
  validate_system(system)
  check_box(box, system.names.length())
  assess_unchecked(system, box)
}
