///|
pub(all) struct Request {
  system : System
  box : Array[Interval]
  options : Options
}

///|
fn j_object(value : Json) -> Map[String, Json] raise RootError {
  match value {
    Object(x) => x
    _ => raise Invalid("expected JSON object")
  }
}

///|
fn j_array(value : Json) -> Array[Json] raise RootError {
  match value {
    Array(x) => x
    _ => raise Invalid("expected JSON array")
  }
}

///|
fn j_text(value : Json) -> String raise RootError {
  match value {
    String(x) => x
    _ => raise Invalid("expected JSON string")
  }
}

///|
fn j_number(value : Json) -> Double raise RootError {
  match value {
    Number(x, repr=_) if !x.is_nan() && !x.is_inf() => x
    _ => raise Invalid("expected finite JSON number")
  }
}

///|
fn j_integer(value : Json, maximum : Int32) -> Int32 raise RootError {
  match value {
    Number(x, repr=Some(s)) if s.length() > 0 &&
      s.length() <= 8 &&
      x >= 0.0 &&
      x <= maximum.to_double() => {
      for i in 0..<s.length() {
        guard s[i] >= 48 && s[i] <= 57 else {
          raise Invalid("use a nonnegative decimal integer token")
        }
      }
      x.to_int()
    }
    _ => raise Invalid("integer outside supported range")
  }
}

///|
fn j_required(o : Map[String, Json], key : String) -> Json raise RootError {
  match o.get(key) {
    Some(x) => x
    None => raise Invalid("missing field: " + key)
  }
}

///|
fn j_only(o : Map[String, Json], keys : Array[String]) -> Unit raise RootError {
  for key, _ in o {
    guard keys.contains(key) else { raise Invalid("unknown field: " + key) }
  }
}

///|
/// Duplicate decoded keys, nonfinite numbers, unknown fields and oversized inputs are rejected.
pub fn decode_request(source : String) -> Request raise RootError {
  guard source.length() <= 262144 else {
    raise Invalid("request exceeds 256 Ki UTF-16 units")
  }
  let value = @json.parse(
    source,
    max_nesting_depth=24,
    reject_duplicate_keys=true,
    preserve_number_repr=true,
  ) catch {
    _ =>
      raise Invalid(
        "invalid JSON, duplicate object key or nesting limit exceeded",
      )
  }
  let o = j_object(value)
  j_only(o, ["version", "variables", "equations", "box", "options"])
  guard j_integer(j_required(o, "version"), 1) == 1 else {
    raise Invalid("unsupported request version")
  }
  let names = j_array(j_required(o, "variables")).map(j_text)
  guard names.length() >= 1 && names.length() <= 6 else {
    raise Invalid("require 1..6 variables")
  }
  let eqs = j_array(j_required(o, "equations"))
  guard eqs.length() == names.length() else {
    raise Invalid("equation count must equal variable count")
  }
  let equations = eqs.map(x => parse_polynomial(j_text(x), names))
  let system = { names, equations, }
  validate_system(system)
  let box = j_array(j_required(o, "box")).map(x => {
    let a = j_array(x)
    guard a.length() == 2 else {
      raise Invalid("each interval requires two endpoints")
    }
    interval(j_number(a[0]), j_number(a[1]))
  })
  check_box(box, names.length())
  let defaults = default_options()
  let opt = match o.get("options") {
    Some(x) => j_object(x)
    None => Map([])
  }
  j_only(opt, ["tolerance", "max_assessments", "max_depth"])
  let options = {
    tolerance: match opt.get("tolerance") {
      Some(x) => j_number(x)
      None => defaults.tolerance
    },
    max_assessments: match opt.get("max_assessments") {
      Some(x) => j_integer(x, 20000)
      None => defaults.max_assessments
    },
    max_depth: match opt.get("max_depth") {
      Some(x) => j_integer(x, 80)
      None => defaults.max_depth
    },
  }
  validate_options(options)
  { system, box, options, }
}

///|
fn box_json(box : Array[Interval]) -> Json {
  Json::array(
    box.map(x => Json::array([Json::number(x.lo), Json::number(x.hi)])),
  )
}

///|
/// Serialize finite result bounds and the actual certificate inputs.
pub fn result_json(request : Request, result : SolveResult) -> Json {
  let roots = result.roots.map(root => {
    let c = root.certificate
    let v : Json = {
      "enclosure": box_json(root.enclosure),
      "certificate": {
        "method": "krawczyk_strict_contraction",
        "domain": box_json(c.domain),
        "image": box_json(c.image),
        "center": Json::array(c.center.map(x => Json::number(x))),
        "preconditioner": Json::array(
          c.preconditioner.map(row => Json::array(row.map(x => Json::number(x)))),
        ),
        "contraction_bound": Json::number(c.q),
      },
    }
    v
  })
  let unresolved = result.unresolved.map(u => {
    let v : Json = { "box": box_json(u.box), "reason": Json::string(u.reason) }
    v
  })
  {
    "version": 1,
    "variables": Json::array(request.system.names.map(x => Json::string(x))),
    "initial_box": box_json(request.box),
    "complete": Json::boolean(result.complete),
    "tolerance_met": Json::boolean(result.tolerance_met),
    "root_count": Json::number(result.roots.length().to_double()),
    "roots": Json::array(roots),
    "unresolved": Json::array(unresolved),
    "stats": {
      "assessments": Json::number(result.assessments.to_double()),
      "excluded": Json::number(result.excluded.to_double()),
      "contractions": Json::number(result.contractions.to_double()),
      "splits": Json::number(result.splits.to_double()),
    },
  }
}

///|
/// Transport-neutral request/response entry point. Errors remain typed.
pub fn solve_json(source : String) -> String raise RootError {
  let request = decode_request(source)
  result_json(request, solve(request.system, request.box, request.options)).stringify()
}
