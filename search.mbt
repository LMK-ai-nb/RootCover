///|
/// Search choices affect scheduling/precision, never the proof predicates.
pub(all) enum SearchOrder {
  DepthFirst
  BreadthFirst
}

///|
pub(all) enum SplitRule {
  Widest
  Scaled
  JacobianImpact
}

///|
pub(all) struct SearchPolicy {
  order : SearchOrder
  split : SplitRule
  absolute_tolerances : Array[Double]?
  relative_tolerance : Double
}

///|
pub fn default_search() -> SearchPolicy {
  {
    order: DepthFirst,
    split: Widest,
    absolute_tolerances: None,
    relative_tolerance: 0.0,
  }
}

///|
fn validate_search(policy : SearchPolicy, n : Int32) -> Unit raise RootError {
  guard !policy.relative_tolerance.is_nan() &&
    policy.relative_tolerance >= 0.0 &&
    policy.relative_tolerance <= 1.0 else {
    raise Invalid("relative_tolerance must be finite in 0..1")
  }
  match policy.absolute_tolerances {
    None => ()
    Some(a) => {
      guard a.length() == n && a.all(t => t > 0.0 && !t.is_inf() && !t.is_nan()) else {
        raise Invalid(
          "absolute_tolerances must contain one positive finite value per variable",
        )
      }
    }
  }
}

///|
/// min_abs is zero on a zero-crossing box. The relative rule therefore cannot
/// hide a root near zero behind the magnitude of a distant box endpoint.
fn axis_precision(
  x : Interval,
  i : Int32,
  options : Options,
  policy : SearchPolicy,
) -> Double {
  let absolute = match policy.absolute_tolerances {
    None => options.tolerance
    Some(a) => a[i]
  }
  let minimum = if x.contains(0.0) { 0.0 } else { x.lo.abs().min(x.hi.abs()) }
  absolute.max(next_down(policy.relative_tolerance * minimum).max(0.0))
}

///|
fn precision_met(
  box : Array[Interval],
  options : Options,
  policy : SearchPolicy,
) -> Bool {
  Array::makei(box.length(), i => {
    box[i].width() <= axis_precision(box[i], i, options, policy)
  }).all(x => x)
}

///|
priv struct WorkQueue {
  order : SearchOrder
  mut cells : Array[(Array[Interval], Int32)]
  mut head : Int32
}

///|
fn WorkQueue::new(initial : Array[Interval], order : SearchOrder) -> WorkQueue {
  { order, cells: [(initial.map(x => x), 0)], head: 0, }
}

///|
fn WorkQueue::empty(self : WorkQueue) -> Bool {
  self.head >= self.cells.length()
}

///|
fn WorkQueue::peek(self : WorkQueue) -> (Array[Interval], Int32) {
  match self.order {
    DepthFirst => self.cells[self.cells.length() - 1]
    BreadthFirst => self.cells[self.head]
  }
}

///|
fn WorkQueue::pending(self : WorkQueue) -> Array[(Array[Interval], Int32)] {
  let count = self.cells.length() - self.head
  Array::makei(count, i => {
    match self.order {
      DepthFirst => self.cells[self.cells.length() - i - 1]
      BreadthFirst => self.cells[self.head + i]
    }
  })
}

///|
fn WorkQueue::take(self : WorkQueue) -> (Array[Interval], Int32) {
  match self.order {
    DepthFirst => self.cells.pop().unwrap()
    BreadthFirst => {
      let cell = self.cells[self.head]
      self.head = self.head + 1
      if self.head >= 4096 && self.head * 2 >= self.cells.length() {
        self.cells = Array::makei(self.cells.length() - self.head, i => {
          self.cells[i + self.head]
        })
        self.head = 0
      }
      cell
    }
  }
}

///|
fn WorkQueue::put(
  self : WorkQueue,
  box : Array[Interval],
  depth : Int32,
) -> Unit {
  self.cells.push((box, depth))
}

///|
fn WorkQueue::children(
  self : WorkQueue,
  left : Array[Interval],
  right : Array[Interval],
  depth : Int32,
) -> Unit {
  match self.order {
    DepthFirst => {
      self.put(right, depth)
      self.put(left, depth)
    }
    BreadthFirst => {
      self.put(left, depth)
      self.put(right, depth)
    }
  }
}

///|
/// Relative interval-Jacobian impact is a branching heuristic, not IBEX's full
/// smear implementation. Nonfinite/undefined rows fall back to scaled width.
fn split_with_policy(
  box : Array[Interval],
  options : Options,
  policy : SearchPolicy,
  expressions : Array[Expr],
) -> (Array[Interval], Array[Interval])? raise RootError {
  let impacts = Array::make(box.length(), 0.0)
  match policy.split {
    JacobianImpact =>
      for e in expressions {
        let state = expression_range_unchecked(e, box)
        if !state.fully_defined || !state.smooth {
          continue
        }
        let (_, gradient) = dual(e, box)
        let scores = Array::makei(box.length(), i => {
          gradient[i].magnitude() * box[i].width()
        })
        let mut total = 0.0
        for score in scores {
          total = total + score
        }
        if total > 0.0 && !total.is_inf() && !total.is_nan() {
          for i = 0; i < box.length(); i = i + 1 {
            impacts[i] = impacts[i] + scores[i] / total
          }
        }
      }
    _ => ()
  }
  let mut axis = -1
  let mut score = -1.0
  let mut split = 0.0
  for i = 0; i < box.length(); i = i + 1 {
    let precision = axis_precision(box[i], i, options, policy)
    if box[i].width() <= precision {
      continue
    }
    let mid = box[i].lo * 0.47 + box[i].hi * 0.53
    if !(mid > box[i].lo && mid < box[i].hi) {
      continue
    }
    let normalized = box[i].width() / precision
    let value = match policy.split {
      Widest => box[i].width()
      Scaled => normalized
      JacobianImpact =>
        if impacts.any(x => x > 0.0) {
          impacts[i]
        } else {
          normalized
        }
    }
    if axis < 0 || value > score {
      axis = i
      score = value
      split = mid
    }
  }
  if axis < 0 {
    return None
  }
  let left = box.map(x => x)
  let right = box.map(x => x)
  left[axis] = { lo: box[axis].lo, hi: split, }
  right[axis] = { lo: split, hi: box[axis].hi, }
  Some((left, right))
}

///|
fn request_search(
  o : Map[String, Json],
  n : Int32,
) -> SearchPolicy raise RootError {
  let raw = match o.get("search") {
    None => return default_search()
    Some(v) => j_object(v)
  }
  j_only(raw, ["strategy", "split", "absolute_tolerances", "relative_tolerance"])
  let policy = {
    order: match raw.get("strategy") {
      None => DepthFirst
      Some(v) =>
        match j_text(v) {
          "dfs" => DepthFirst
          "bfs" => BreadthFirst
          _ => raise Invalid("search.strategy must be dfs or bfs")
        }
    },
    split: match raw.get("split") {
      None => Widest
      Some(v) =>
        match j_text(v) {
          "widest" => Widest
          "scaled" => Scaled
          "smear" => JacobianImpact
          _ => raise Invalid("search.split must be widest, scaled or smear")
        }
    },
    absolute_tolerances: match raw.get("absolute_tolerances") {
      None => None
      Some(v) => Some(j_array(v).map(j_number))
    },
    relative_tolerance: match raw.get("relative_tolerance") {
      None => 0.0
      Some(v) => j_number(v)
    },
  }
  validate_search(policy, n)
  policy
}

///|
fn search_json(policy : SearchPolicy, options : Options, n : Int32) -> Json {
  let order = match policy.order {
    DepthFirst => "dfs"
    BreadthFirst => "bfs"
  }
  let split = match policy.split {
    Widest => "widest"
    Scaled => "scaled"
    JacobianImpact => "smear"
  }
  let absolute = match policy.absolute_tolerances {
    None => Array::make(n, options.tolerance)
    Some(a) => a
  }
  {
    "strategy": Json::string(order),
    "split": Json::string(split),
    "absolute_tolerances": Json::array(absolute.map(x => Json::number(x))),
    "relative_tolerance": Json::number(policy.relative_tolerance),
    "relative_scale": "minimum_absolute_value_in_box",
  }
}
