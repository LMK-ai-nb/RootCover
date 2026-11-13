///|
fn request_contractors(
  o : Map[String, Json],
) -> ContractorOptions raise RootError {
  let defaults = default_contractors()
  let c = match o.get("contractors") {
    None => return defaults
    Some(v) => j_object(v)
  }
  j_only(c, ["propagation", "newton", "max_steps", "max_rounds"])
  fn boolean(v : Json) -> Bool raise RootError {
    match v {
      True => true
      False => false
      _ => raise Invalid("contractor flag must be boolean")
    }
  }
  let config = {
    propagation: match c.get("propagation") {
      None => defaults.propagation
      Some(v) => boolean(v)
    },
    newton: match c.get("newton") {
      None => defaults.newton
      Some(v) => boolean(v)
    },
    max_steps: match c.get("max_steps") {
      None => defaults.max_steps
      Some(v) => j_integer(v, 16384)
    },
    max_rounds: match c.get("max_rounds") {
      None => defaults.max_rounds
      Some(v) => j_integer(v, 32)
    },
  }
  validate_contractors(config)
  config
}
