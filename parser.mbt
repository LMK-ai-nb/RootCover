///|
priv struct Parser {
  source : String
  names : Array[String]
  mut pos : Int32
  mut nodes : Int32
  mut depth : Int32
}

///|
fn Parser::peek(self : Parser) -> Int32 {
  while self.pos < self.source.length() &&
        [32, 9, 10, 13].contains(self.source[self.pos].to_int()) {
    self.pos = self.pos + 1
  }
  if self.pos == self.source.length() {
    0
  } else {
    self.source[self.pos].to_int()
  }
}

///|
fn Parser::node(self : Parser, e : Expr) -> Expr raise RootError {
  self.nodes = self.nodes + 1
  guard self.nodes <= 512 else {
    raise Invalid("expression node limit exceeded")
  }
  e
}

///|
fn Parser::sum(self : Parser) -> Expr raise RootError {
  let mut e = self.product()
  while self.peek() == 43 || self.peek() == 45 {
    let op = self.peek()
    self.pos = self.pos + 1
    let b = self.product()
    e = self.node(if op == 43 { Add(e, b) } else { Sub(e, b) })
  }
  e
}

///|
fn Parser::product(self : Parser) -> Expr raise RootError {
  let mut e = self.unary()
  while self.peek() == 42 {
    self.pos = self.pos + 1
    e = self.node(Mul(e, self.unary()))
  }
  e
}

///|
fn Parser::unary(self : Parser) -> Expr raise RootError {
  self.depth = self.depth + 1
  guard self.depth <= 32 else { raise Invalid("parser nesting limit exceeded") }
  let c = self.peek()
  let e = if c == 43 || c == 45 {
    self.pos = self.pos + 1
    let v = self.unary()
    if c == 45 {
      self.node(Sub(Const(0.0), v))
    } else {
      v
    }
  } else {
    self.power_expr()
  }
  self.depth = self.depth - 1
  e
}

///|
fn Parser::power_expr(self : Parser) -> Expr raise RootError {
  let e = self.primary()
  if self.peek() != 94 {
    return e
  }
  self.pos = self.pos + 1
  let _ = self.peek()
  let start = self.pos
  let mut k = 0
  while self.pos < self.source.length() {
    let c = self.source[self.pos].to_int()
    if c < 48 || c > 57 {
      break
    }
    k = k * 10 + c - 48
    guard k <= 16 else { raise Invalid("power must be in 0..16") }
    self.pos = self.pos + 1
  }
  guard self.pos > start else {
    raise Invalid("expected a nonnegative integer power")
  }
  self.node(Pow(e, k))
}

///|
fn Parser::primary(self : Parser) -> Expr raise RootError {
  let c = self.peek()
  if c == 40 {
    self.pos = self.pos + 1
    let e = self.sum()
    guard self.peek() == 41 else {
      raise Invalid("expected closing parenthesis")
    }
    self.pos = self.pos + 1
    return e
  }
  if (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 {
    let start = self.pos
    while self.pos < self.source.length() {
      let q = self.source[self.pos].to_int()
      if !((q >= 65 && q <= 90) ||
        (q >= 97 && q <= 122) ||
        (q >= 48 && q <= 57) ||
        q == 95) {
        break
      }
      self.pos = self.pos + 1
    }
    let name = self.source[start:self.pos].to_owned()
    for i = 0; i < self.names.length(); i = i + 1 {
      if self.names[i] == name {
        return self.node(Variable(i))
      }
    }
    raise Invalid("unknown variable: " + name)
  }
  if c >= 48 && c <= 57 {
    let start = self.pos
    while self.pos < self.source.length() &&
          self.source[self.pos] >= 48 &&
          self.source[self.pos] <= 57 {
      self.pos = self.pos + 1
    }
    if self.pos < self.source.length() && self.source[self.pos] == 46 {
      self.pos = self.pos + 1
      while self.pos < self.source.length() &&
            self.source[self.pos] >= 48 &&
            self.source[self.pos] <= 57 {
        self.pos = self.pos + 1
      }
    }
    if self.pos < self.source.length() &&
      (self.source[self.pos] == 101 || self.source[self.pos] == 69) {
      self.pos = self.pos + 1
      if self.pos < self.source.length() &&
        (self.source[self.pos] == 43 || self.source[self.pos] == 45) {
        self.pos = self.pos + 1
      }
      while self.pos < self.source.length() &&
            self.source[self.pos] >= 48 &&
            self.source[self.pos] <= 57 {
        self.pos = self.pos + 1
      }
    }
    let token = self.source[start:self.pos].to_owned()
    let v = @json.parse(token) catch {
      _ => raise Invalid("invalid numeric literal")
    }
    match v {
      Number(x, repr=_) if !x.is_nan() && !x.is_inf() =>
        return self.node(Const(x))
      _ => raise Invalid("numeric literal must be finite binary64")
    }
  }
  raise Invalid("expected number, variable or parenthesized polynomial")
}

///| Grammar: explicit *, +, -, parentheses and integer ^0..16; unary minus

///|
/// binds below exponentiation. Decimal literals become binary64 constants.
pub fn parse_polynomial(
  source : String,
  names : Array[String],
) -> Expr raise RootError {
  guard source.length() <= 4096 else {
    raise Invalid("equation text exceeds 4096 UTF-16 units")
  }
  let p = { source, names, pos: 0, nodes: 0, depth: 0, }
  let e = p.sum()
  guard p.peek() == 0 else {
    raise Invalid(
      "unexpected token; implicit multiplication, division and functions are unsupported",
    )
  }
  let _ = check_expr(e, names.length(), 0, Ref(0))
  e
}
