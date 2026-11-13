///|
pub(all) struct FeasibilityRequest {
  model : ConstraintModel
  box : Array[Interval]
  options : Options
  contractors : ContractorOptions
  search : SearchPolicy
  formula : Predicate?
}

///|
pub fn decode_feasibility_request(
  source : String,
) -> FeasibilityRequest raise RootError {
  decode_feasibility_object(j_document(source))
}

///|
fn decode_feasibility_object(
  o : Map[String, Json],
) -> FeasibilityRequest raise RootError {
  j_only(o, [
    "version", "mode", "variables", "constraints", "box", "options", "contractors",
    "search", "formula",
  ])
  guard request_mode(o) == "feasibility" else {
    raise Invalid("expected feasibility mode")
  }
  guard j_integer(j_required(o, "version"), 1) == 1 else {
    raise Invalid("unsupported request version")
  }
  let names = j_array(j_required(o, "variables")).map(j_text)
  let cs = j_array(j_required(o, "constraints"))
  guard cs.length() >= 1 && cs.length() <= 128 else {
    raise Invalid("require 1..128 constraints")
  }
  let constraints = cs.map(v => {
    let c = j_object(v)
    j_only(c, ["expression", "range", "relation", "rhs"])
    let allowed = match c.get("range") {
      Some(value) => {
        guard c.get("relation") is None && c.get("rhs") is None else {
          raise Invalid("use range or relation/rhs, never both")
        }
        let r = j_array(value)
        guard r.length() == 2 else {
          raise Invalid("each range requires two endpoints")
        }
        let lo = match r[0] {
          Null => @double.neg_infinity
          _ => j_number(r[0])
        }
        let hi = match r[1] {
          Null => @double.infinity
          _ => j_number(r[1])
        }
        interval(lo, hi)
      }
      None => {
        let rhs = j_number(j_required(c, "rhs"))
        match j_text(j_required(c, "relation")) {
          "==" => point(rhs)
          "<=" => interval(@double.neg_infinity, rhs)
          ">=" => interval(rhs, @double.infinity)
          _ =>
            raise Invalid(
              "relation must be ==, <= or >=; strict inequalities are unsupported",
            )
        }
      }
    }
    {
      polynomial: parse_expression(j_text(j_required(c, "expression")), names),
      allowed,
    }
  })
  let model = { names, constraints, }
  validate_constraints(model)
  let formula = match o.get("formula") {
    None => None
    Some(raw) => {
      let p = decode_formula(raw, constraints.length(), 0, Ref(0))
      validate_predicate({ model, predicate: p, })
      Some(p)
    }
  }
  let box = j_array(j_required(o, "box")).map(v => {
    let a = j_array(v)
    guard a.length() == 2 else {
      raise Invalid("each input interval requires two endpoints")
    }
    interval(j_number(a[0]), j_number(a[1]))
  })
  check_box(box, names.length())
  {
    model,
    box,
    options: request_options(o),
    contractors: request_contractors(o),
    search: request_search(o, names.length()),
    formula,
  }
}

///|
fn paving_json(request : FeasibilityRequest, result : PavingResult) -> Json {
  let inside = result.inside.map(b => {
    let value : Json = { "box": box_json(b.box), "ranges": box_json(b.ranges) }
    value
  })
  let unknown = result.unresolved.map(b => {
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
  {
    "version": 1,
    "mode": "feasibility",
    "search": search_json(
      request.search,
      request.options,
      request.model.names.length(),
    ),
    "variables": Json::array(request.model.names.map(x => Json::string(x))),
    "initial_box": box_json(request.box),
    "complete": Json::boolean(result.complete),
    "resolution_met": Json::boolean(result.resolution_met),
    "definitely_empty": Json::boolean(
      result.complete && result.inside.is_empty(),
    ),
    "inner_box_count": Json::number(result.inside.length().to_double()),
    "inside": Json::array(inside),
    "unresolved": Json::array(unknown),
    "stats": {
      "assessments": Json::number(result.assessments.to_double()),
      "excluded": Json::number(result.excluded.to_double()),
      "splits": Json::number(result.splits.to_double()),
      "contractions": Json::number(result.contractions.to_double()),
      "contractor_calls": Json::number(result.contractor_calls.to_double()),
    },
  }
}
