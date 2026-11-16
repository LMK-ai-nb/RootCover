///|
fn decode_formula(
  value : Json,
  atoms : Int32,
  depth : Int32,
  nodes : Ref[Int32],
) -> Predicate raise RootError {
  nodes.val = nodes.val + 1
  guard depth <= 16 && nodes.val <= 512 else {
    raise Invalid("formula too deep or large")
  }
  match value {
    Number(_, repr=_) => {
      let i = j_integer(value, 127)
      guard i < atoms else { raise Invalid("formula atom index out of range") }
      Atom(i)
    }
    _ => {
      let o = j_object(value)
      guard o.length() == 1 else {
        raise Invalid("formula requires exactly one operator")
      }
      match (o.get("all"), o.get("any"), o.get("at_least")) {
        (Some(a), _, _) =>
          All(j_array(a).map(x => decode_formula(x, atoms, depth + 1, nodes)))
        (_, Some(a), _) =>
          Any(j_array(a).map(x => decode_formula(x, atoms, depth + 1, nodes)))
        (_, _, Some(a)) => {
          let q = j_object(a)
          j_only(q, ["count", "of"])
          let k = j_integer(j_required(q, "count"), 128)
          AtLeast(
            k,
            j_array(j_required(q, "of")).map(x => {
              decode_formula(x, atoms, depth + 1, nodes)
            }),
          )
        }
        _ => raise Invalid("unknown formula operator; use all, any or at_least")
      }
    }
  }
}

///|
fn formula_json(p : Predicate) -> Json {
  match p {
    Atom(i) => Json::number(i.to_double())
    All(children) => { "all": Json::array(children.map(formula_json)) }
    Any(children) => { "any": Json::array(children.map(formula_json)) }
    AtLeast(k, children) =>
      {
        "at_least": {
          "count": Json::number(k.to_double()),
          "of": Json::array(children.map(formula_json)),
        },
      }
  }
}

///|
fn truth_json(truth : Truth) -> Json {
  Json::string(
    match truth {
      Yes => "true"
      No => "false"
      Maybe => "unknown"
    },
  )
}

///|
fn predicate_json(
  request : FeasibilityRequest,
  predicate : Predicate,
  result : PredicateResult,
) -> Json {
  let inside = result.inside.map(b => {
    let evidence = Array::makei(b.evidence.ranges.length(), i => {
      let state = b.evidence.ranges[i]
      let r : Json = {
        "truth": truth_json(b.evidence.atom_truths[i]),
        "fully_defined": Json::boolean(state.fully_defined),
        "range": match state.range {
          None => Json::null()
          Some(a) => Json::array([endpoint_json(a.lo), endpoint_json(a.hi)])
        },
      }
      r
    })
    let value : Json = {
      "box": box_json(b.box),
      "atoms": Json::array(evidence),
      "formula_truth": "true",
    }
    value
  })
  let unresolved = result.unresolved.map(b => {
    let value : Json = {
      "box": box_json(b.box),
      "reason": Json::string(b.reason),
      "status": Json::string(
        if b.reason == "assessment budget exhausted" ||
          b.reason == "session paused with pending work" {
          "pending"
        } else {
          "unknown"
        },
      ),
    }
    value
  })
  let mut pending_count = 0
  for b in result.unresolved {
    if b.reason == "assessment budget exhausted" ||
      b.reason == "session paused with pending work" {
      pending_count = pending_count + 1
    }
  }
  {
    "version": 1,
    "mode": "feasibility",
    "certificate_kind": "positive_formula_interval_truth",
    "formula": formula_json(predicate),
    "variables": Json::array(request.model.names.map(Json::string)),
    "search": search_json(
      request.search,
      request.options,
      request.model.names.length(),
    ),
    "initial_box": box_json(request.box),
    "inside": Json::array(inside),
    "unresolved": Json::array(unresolved),
    "inner_box_count": Json::number(result.inside.length().to_double()),
    "complete": Json::boolean(result.complete),
    "resolution_met": Json::boolean(result.resolution_met),
    "status": Json::string(
      if result.complete && result.inside.is_empty() {
        "unsatisfiable"
      } else if result.complete {
        "satisfied"
      } else {
        "unknown"
      },
    ),
    "unresolved_count": Json::number(result.unresolved.length().to_double()),
    "counts": {
      "inside": Json::number(result.inside.length().to_double()),
      "unknown": Json::number((result.unresolved.length() - pending_count).to_double()),
      "pending": Json::number(pending_count.to_double()),
      "excluded": Json::number(result.excluded.to_double()),
    },
    "options": {
      "tolerance": Json::number(request.options.tolerance),
      "max_assessments": Json::number(request.options.max_assessments.to_double()),
      "max_depth": Json::number(request.options.max_depth.to_double()),
    },
    "contractors": {
      "propagation": Json::boolean(request.contractors.propagation),
      "newton": Json::boolean(request.contractors.newton),
      "max_steps": Json::number(request.contractors.max_steps.to_double()),
      "max_rounds": Json::number(request.contractors.max_rounds.to_double()),
    },
    "definitely_empty": Json::boolean(
      result.complete && result.inside.is_empty(),
    ),
    "stats": {
      "assessments": Json::number(result.assessments.to_double()),
      "excluded": Json::number(result.excluded.to_double()),
      "contractions": Json::number(result.contractions.to_double()),
      "contractor_calls": Json::number(result.contractor_calls.to_double()),
      "splits": Json::number(result.splits.to_double()),
    },
  }
}
