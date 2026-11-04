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
