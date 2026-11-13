///|
priv enum SessionEvent {
  Accept
  Reject
  Hold(String)
  Divide(Int32, Double)
}

///|
priv enum SessionClass {
  AllInside(Array[Interval])
  FormulaInside(PredicateState)
  AllOutside
  Uncertain
}

///|
priv enum SessionOutcome {
  Inner(FeasibleBox)
  FormulaInner(PredicateBox)
  Outer
  Unknown(Array[Interval], String)
  Children(Array[Interval], Array[Interval], Int32, Double)
}

///|
/// An owned feasible-set search. Fields are private to prevent callers replacing
/// a frontier or evidence without the coverage checks used by restoration.
struct PavingSession {
  source : String
  request : FeasibilityRequest
  queue : WorkQueue
  expressions : Array[Expr]
  inside : Array[FeasibleBox]
  formula_inside : Array[PredicateBox]
  unknown : Array[UnresolvedBox]
  events : Array[SessionEvent]
  mut assessments : Int32
  mut excluded : Int32
  mut contractions : Int32
  mut contractor_calls : Int32
  mut splits : Int32
  mut replayed_events : Int32
  mut replayed_leaf_checks : Int32
}

///|
pub fn new_paving_session(source : String) -> PavingSession raise RootError {
  let request = decode_feasibility_request(source)
  let expressions = match request.formula {
    None => request.model.constraints.map(c => c.polynomial)
    Some(predicate) =>
      referenced_expressions({ model: request.model, predicate, })
  }
  {
    source,
    request,
    queue: WorkQueue::new(request.box, request.search.order),
    expressions,
    inside: [],
    formula_inside: [],
    unknown: [],
    events: [],
    assessments: 0,
    excluded: 0,
    contractions: 0,
    contractor_calls: 0,
    splits: 0,
    replayed_events: 0,
    replayed_leaf_checks: 0,
  }
}

///|
fn PavingSession::session_contraction(
  self : PavingSession,
  box : Array[Interval],
) -> Contraction raise RootError {
  let config = self.request.contractors
  if self.contractor_calls < config.max_steps &&
    (config.propagation || config.newton) {
    let remaining = {
      propagation: config.propagation,
      newton: config.newton,
      max_steps: config.max_steps - self.contractor_calls,
      max_rounds: config.max_rounds,
    }
    match self.request.formula {
      None => contract_unchecked(self.request.model, box, remaining)
      Some(predicate) =>
        contract_predicate_unchecked(
          { model: self.request.model, predicate, },
          box,
          remaining,
        )
    }
  } else {
    {
      box: Some(box),
      calls: 0,
      rounds: 0,
      changed: false,
      fixed_point: false,
      budget_exhausted: false,
      propagation_calls: 0,
      newton_calls: 0,
    }
  }
}

///|
fn PavingSession::session_classify(
  self : PavingSession,
  box : Array[Interval],
) -> SessionClass raise RootError {
  match self.request.formula {
    None =>
      match classify_unchecked(self.request.model, box) {
        Inside(ranges) => AllInside(ranges)
        Outside(_) => AllOutside
        Indeterminate => Uncertain
      }
    Some(predicate) => {
      let evidence = predicate_state_unchecked(
        { model: self.request.model, predicate, },
        box,
      )
      match evidence.truth {
        Yes => FormulaInside(evidence)
        No => AllOutside
        Maybe => Uncertain
      }
    }
  }
}

///|
fn PavingSession::session_stop(
  self : PavingSession,
  box : Array[Interval],
  depth : Int32,
) -> String? {
  if precision_met(box, self.request.options, self.request.search) {
    Some("resolution")
  } else if depth >= self.request.options.max_depth {
    Some("depth")
  } else {
    None
  }
}

///|
fn PavingSession::session_reason(self : PavingSession, code : String) -> String {
  match code {
    "resolution" =>
      if self.request.formula is Some(_) {
        "resolution reached without whole-formula classification"
      } else {
        "resolution reached without whole-box classification"
      }
    "depth" => "depth limit reached"
    _ => "no representable interior split point"
  }
}

///|
fn session_children(
  box : Array[Interval],
  axis : Int32,
  point : Double,
) -> SessionOutcome raise RootError {
  guard axis >= 0 &&
    axis < box.length() &&
    point > box[axis].lo &&
    point < box[axis].hi else {
    raise Invalid("checkpoint split must be strictly inside its derived box")
  }
  let left = box.map(x => x)
  let right = box.map(x => x)
  left[axis] = { lo: box[axis].lo, hi: point, }
  right[axis] = { lo: point, hi: box[axis].hi, }
  Children(left, right, axis, point)
}

///|
/// All operations which may raise finish BEFORE removing the pending cell.
fn PavingSession::session_next(
  self : PavingSession,
  contracted : Contraction,
  depth : Int32,
) -> SessionOutcome raise RootError {
  let box = match contracted.box {
    None => return Outer
    Some(b) => b
  }
  match self.session_classify(box) {
    AllInside(ranges) => return Inner({ box, ranges, })
    FormulaInside(evidence) => return FormulaInner({ box, evidence, })
    AllOutside => return Outer
    Uncertain => ()
  }
  if self.session_stop(box, depth) is Some(code) {
    return Unknown(box, code)
  }
  match
    split_with_policy(
      box,
      self.request.options,
      self.request.search,
      self.expressions,
    ) {
    None => Unknown(box, "representation")
    Some((left, _)) => {
      for i = 0; i < box.length(); i = i + 1 {
        if left[i].hi != box[i].hi {
          return session_children(box, i, left[i].hi)
        }
      }
      raise Invalid("internal split did not divide a coordinate")
    }
  }
}

///|
fn PavingSession::session_commit(
  self : PavingSession,
  c : Contraction,
  outcome : SessionOutcome,
) -> Unit {
  let (_, depth) = self.queue.take()
  self.assessments = self.assessments + 1
  self.contractor_calls = self.contractor_calls + c.calls
  if c.changed {
    self.contractions = self.contractions + 1
  }
  let event = match outcome {
    Inner(b) => {
      self.inside.push(b)
      Accept
    }
    FormulaInner(b) => {
      self.formula_inside.push(b)
      Accept
    }
    Outer => {
      self.excluded = self.excluded + 1
      Reject
    }
    Unknown(box, code) => {
      self.unknown.push({ box, reason: self.session_reason(code), })
      Hold(code)
    }
    Children(left, right, axis, point) => {
      self.queue.children(left, right, depth + 1)
      self.splits = self.splits + 1
      Divide(axis, point)
    }
  }
  self.events.push(event)
}

///|
/// Advance at most `steps` assessments. The request's original total budget,
/// depth, precision, global contractor allowance and FIFO/LIFO order persist.
pub fn PavingSession::advance(
  self : PavingSession,
  steps : Int32,
) -> Unit raise RootError {
  guard steps >= 1 && steps <= 20000 else {
    raise Invalid("session steps must be1..20000")
  }
  let end = (self.assessments + steps).min(self.request.options.max_assessments)
  while !self.queue.empty() && self.assessments < end {
    let (box, depth) = self.queue.peek()
    let contracted = self.session_contraction(box)
    let outcome = self.session_next(contracted, depth)
    self.session_commit(contracted, outcome)
  }
}

///|
fn PavingSession::session_result(self : PavingSession) -> Json {
  let unresolved = self.unknown.map(x => x)
  let pending = self.queue.pending()
  let reason = if self.assessments >= self.request.options.max_assessments {
    "assessment budget exhausted"
  } else {
    "session paused with pending work"
  }
  for (box, _) in pending {
    unresolved.push({ box, reason, })
  }
  let complete = unresolved.is_empty()
  let resolution_met = unresolved.all(b => {
    precision_met(b.box, self.request.options, self.request.search)
  })
  let result = match self.request.formula {
    None =>
      paving_json(self.request, {
        inside: self.inside,
        unresolved,
        complete,
        resolution_met,
        assessments: self.assessments,
        excluded: self.excluded,
        contractions: self.contractions,
        contractor_calls: self.contractor_calls,
        splits: self.splits,
      })
    Some(predicate) =>
      predicate_json(self.request, predicate, {
        inside: self.formula_inside,
        unresolved,
        complete,
        resolution_met,
        assessments: self.assessments,
        excluded: self.excluded,
        contractions: self.contractions,
        contractor_calls: self.contractor_calls,
        splits: self.splits,
      })
  }
  let object = match result {
    Object(o) => o
    _ => abort("result object")
  }
  object.set("session", {
    "checkpoint_version": 1,
    "pending_boxes": Json::number(pending.length().to_double()),
    "terminal_unknown_boxes": Json::number(self.unknown.length().to_double()),
    "can_advance": Json::boolean(
      !self.queue.empty() &&
      self.assessments < self.request.options.max_assessments,
    ),
    "hard_assessment_limit": Json::number(
      self.request.options.max_assessments.to_double(),
    ),
    "replayed_events": Json::number(self.replayed_events.to_double()),
    "replayed_leaf_checks": Json::number(self.replayed_leaf_checks.to_double()),
    "coverage": "verified_from_initial_box",
  })
  Json::object(object)
}

///|
pub fn PavingSession::snapshot(self : PavingSession) -> String {
  self.session_result().stringify()
}

///|
fn PavingSession::session_checkpoint(self : PavingSession) -> Json {
  let events = self.events.map(e => {
    let value : Json = match e {
      Accept => { "kind": "inside" }
      Reject => { "kind": "outside" }
      Hold(code) => { "kind": "unknown", "reason": Json::string(code) }
      Divide(axis, point) =>
        {
          "kind": "split",
          "axis": Json::number(axis.to_double()),
          "point": Json::number(point),
        }
    }
    value
  })
  {
    "checkpoint_version": 1,
    "kind": "rootcover.feasibility",
    "request": Json::string(self.source),
    "events": Json::array(events),
  }
}

///|
pub fn PavingSession::checkpoint(self : PavingSession) -> String {
  self.session_checkpoint().stringify()
}

///|
pub fn PavingSession::envelope(self : PavingSession) -> String {
  let value : Json = {
    "result": self.session_result(),
    "checkpoint": self.session_checkpoint(),
  }
  value.stringify()
}

///|
fn decode_session_event(value : Json) -> SessionEvent raise RootError {
  let o = j_object(value)
  match j_text(j_required(o, "kind")) {
    "inside" => {
      j_only(o, ["kind"])
      Accept
    }
    "outside" => {
      j_only(o, ["kind"])
      Reject
    }
    "unknown" => {
      j_only(o, ["kind", "reason"])
      let code = j_text(j_required(o, "reason"))
      guard ["resolution", "depth", "representation"].contains(code) else {
        raise Invalid("unknown checkpoint stop reason")
      }
      Hold(code)
    }
    "split" => {
      j_only(o, ["kind", "axis", "point"])
      Divide(
        j_integer(j_required(o, "axis"), 31),
        j_number(j_required(o, "point")),
      )
    }
    _ => raise Invalid("unknown checkpoint event")
  }
}

///|
/// Restore by verifying a covering trace, not trusting cached inner/outer boxes.
/// Splits are geometric partitions; contraction and terminal classifications
/// are recomputed. Missing events leave pending regions, never false completion.
pub fn restore_paving_session(source : String) -> PavingSession raise RootError {
  guard source.length() <= 4194304 else {
    raise Invalid("checkpoint exceeds4 Mi UTF-16 units")
  }
  let raw = @json.parse(
    source,
    max_nesting_depth=24,
    reject_duplicate_keys=true,
    preserve_number_repr=true,
  ) catch {
    _ =>
      raise Invalid("invalid checkpoint JSON, duplicate key or nesting limit")
  }
  let o = j_object(raw)
  j_only(o, ["checkpoint_version", "kind", "request", "events"])
  guard j_integer(j_required(o, "checkpoint_version"), 1) == 1 &&
    j_text(j_required(o, "kind")) == "rootcover.feasibility" else {
    raise Invalid("unsupported checkpoint format")
  }
  let session = new_paving_session(j_text(j_required(o, "request")))
  let events = j_array(j_required(o, "events"))
  guard events.length() <= session.request.options.max_assessments else {
    raise Invalid("checkpoint exceeds the original assessment budget")
  }
  for value in events {
    guard !session.queue.empty() else {
      raise Invalid("checkpoint has events after search completion")
    }
    let event = decode_session_event(value)
    let (original, depth) = session.queue.peek()
    let c = session.session_contraction(original)
    let outcome = match c.box {
      None =>
        match event {
          Reject => Outer
          _ =>
            raise Invalid(
              "checkpoint event disagrees with an empty contracted box",
            )
        }
      Some(box) =>
        match event {
          Accept =>
            match session.session_classify(box) {
              AllInside(ranges) => Inner({ box, ranges, })
              FormulaInside(evidence) => FormulaInner({ box, evidence, })
              _ =>
                raise Invalid(
                  "checkpoint inner cell failed whole-box verification",
                )
            }
          Reject =>
            match session.session_classify(box) {
              AllOutside => Outer
              _ =>
                raise Invalid(
                  "checkpoint outside cell could contain feasible points",
                )
            }
          Hold(code) => {
            match code {
              "resolution" => {
                guard precision_met(
                  box,
                  session.request.options,
                  session.request.search,
                ) else {
                  raise Invalid("checkpoint resolution stop is premature")
                }
              }
              "depth" => {
                guard depth >= session.request.options.max_depth else {
                  raise Invalid("checkpoint depth stop is premature")
                }
              }
              _ => {
                let policy = { ..session.request.search, split: Widest, }
                guard split_with_policy(box, session.request.options, policy, [])
                  is None else {
                  raise Invalid(
                    "checkpoint representation stop has a valid split",
                  )
                }
              }
            }
            Unknown(box, code)
          }
          Divide(axis, point) => {
            guard session.session_stop(box, depth) is None else {
              raise Invalid(
                "checkpoint splits beyond its depth or precision limit",
              )
            }
            session_children(box, axis, point)
          }
        }
    }
    session.session_commit(c, outcome)
    match event {
      Accept | Reject =>
        session.replayed_leaf_checks = session.replayed_leaf_checks + 1
      _ => ()
    }
    session.replayed_events = session.replayed_events + 1
  }
  session
}
