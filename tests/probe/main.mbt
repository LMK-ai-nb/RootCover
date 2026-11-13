///|
fn number(v : Json) -> Double {
  match v {
    Number(x, repr=_) => x
    _ => 0.0
  }
}

///|
fn encoded(x : Double) -> Json {
  if x.is_pos_inf() {
    Json::string("Infinity")
  } else if x.is_neg_inf() {
    Json::string("-Infinity")
  } else {
    Json::number(x)
  }
}

///|
/// Test-only public consumer: no numerical algorithms are reimplemented here.
pub fn probe(source : String) -> String {
  try {
    let values = match @json.parse(source) {
      Array(a) => a
      _ => []
    }
    let result = values.map(v => {
      let a = match v {
        Array(a) => a
        _ => []
      }
      let op = match a[0] {
        String(s) => s
        _ => ""
      }
      let x = @root.interval(number(a[1]), number(a[2]))
      let y = if op == "pow" {
        @root.interval(0.0, 0.0)
      } else {
        @root.interval(number(a[3]), number(a[4]))
      }
      let z = match op {
        "add" => x.add(y)
        "sub" => x.sub(y)
        "mul" => x.mul(y)
        _ => x.power(number(a[3]).to_int())
      }
      Json::array([encoded(z.lo), encoded(z.hi)])
    })
    Json::array(result).stringify()
  } catch {
    _ => "{\"error\":true}"
  }
}

///|
/// Test adapter: delegates evaluation and contraction to public typed APIs.
pub fn nonlinear_probe(source : String) -> String {
  try {
    let o = match @json.parse(source) {
      Object(o) => o
      _ => abort("object expected")
    }
    fn text(v : Json) -> String {
      match v {
        String(s) => s
        _ => abort("string expected")
      }
    }
    fn array(v : Json) -> Array[Json] {
      match v {
        Array(a) => a
        _ => abort("array expected")
      }
    }
    fn box(v : Json) -> Array[@root.Interval] raise @root.RootError {
      array(v).map(x => {
        let a = array(x)
        @root.interval(number(a[0]), number(a[1]))
      })
    }
    fn encode_box(b : Array[@root.Interval]) -> Json {
      Json::array(b.map(x => Json::array([encoded(x.lo), encoded(x.hi)])))
    }
    let result : Json = if text(o["operation"]) == "contract" {
      let request = @root.decode_feasibility_request(text(o["request"]))
      let c = if request.formula is Some(predicate) {
        @root.contract_predicate(
          { model: request.model, predicate, },
          request.box,
          request.contractors,
        )
      } else {
        @root.contract_constraints(
          request.model,
          request.box,
          request.contractors,
        )
      }
      {
        "box": match c.box {
          None => Json::null()
          Some(b) => encode_box(b)
        },
        "calls": Json::number(c.calls.to_double()),
        "propagation_calls": Json::number(c.propagation_calls.to_double()),
        "newton_calls": Json::number(c.newton_calls.to_double()),
        "fixed_point": Json::boolean(c.fixed_point),
        "budget_exhausted": Json::boolean(c.budget_exhausted),
      }
    } else {
      let names = array(o["variables"]).map(text)
      let expression = @root.parse_expression(text(o["expression"]), names)
      let input = box(o["box"])
      let v = @root.evaluate_expression(expression, input)
      // enclose is square; repeat the expression for a derivative probe only.
      let ev = @root.enclose(
        { names, equations: Array::make(names.length(), expression), },
        input,
      )
      {
        "range": match v.range {
          None => Json::null()
          Some(r) => Json::array([encoded(r.lo), encoded(r.hi)])
        },
        "fully_defined": Json::boolean(v.fully_defined),
        "smooth": Json::boolean(v.smooth),
        "gradient": encode_box(ev.jacobian[0]),
      }
    }
    result.stringify()
  } catch {
    _ => "{\"error\":true}"
  }
}
