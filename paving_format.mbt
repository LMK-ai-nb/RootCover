///|
pub(all) struct FeasibilityRequest {
  model : ConstraintModel
  box : Array[Interval]
  options : Options
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
  j_only(o, ["version", "mode", "variables", "constraints", "box", "options"])
  guard request_mode(o) == "feasibility" else {
    raise Invalid("expected feasibility mode")
  }
  guard j_integer(j_required(o, "version"), 1) == 1 else {
    raise Invalid("unsupported request version")
  }
  let names = j_array(j_required(o, "variables")).map(j_text)
  let cs = j_array(j_required(o, "constraints"))
  guard cs.length() >= 1 && cs.length() <= 32 else {
    raise Invalid("require 1..32 constraints")
  }
  let constraints = cs.map(v => {
    let c = j_object(v)
    j_only(c, ["expression", "range"])
    let r = j_array(j_required(c, "range"))
    guard r.length() == 2 else {
      raise Invalid("each observation range requires two endpoints")
    }
    {
      polynomial: parse_polynomial(j_text(j_required(c, "expression")), names),
      allowed: interval(j_number(r[0]), j_number(r[1])),
    }
  })
  let model = { names, constraints, }
  validate_constraints(model)
  let box = j_array(j_required(o, "box")).map(v => {
    let a = j_array(v)
    guard a.length() == 2 else {
      raise Invalid("each input interval requires two endpoints")
    }
    interval(j_number(a[0]), j_number(a[1]))
  })
  check_box(box, names.length())
  { model, box, options: request_options(o), }
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
    }
    value
  })
  {
    "version": 1,
    "mode": "feasibility",
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
      "contractions": 0,
    },
  }
}
