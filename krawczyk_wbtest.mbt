///|
test "linear system obtains a strict multivariate certificate" {
  let x = Variable(0)
  let y = Variable(1)
  let s = {
    names: ["x", "y"],
    equations: [Sub(Add(x, y), Const(3.0)), Sub(Sub(x, y), Const(1.0))],
  }
  match assess(s, [interval(0.0, 4.0), interval(0.0, 4.0)]) {
    Unique(c) => {
      assert_true(c.q < 1.0)
      assert_true(c.enclosure[0].contains(2.0))
      assert_true(c.enclosure[1].contains(1.0))
      assert_true(max_width(c.enclosure) < 1.0e-12)
    }
    _ => fail("expected strict certificate")
  }
}

///|
test "range exclusion is sound even when Jacobian is singular" {
  let s = { names: ["x"], equations: [Add(Pow(Variable(0), 2), Const(1.0))], }
  match assess(s, [interval(-4.0, 4.0)]) {
    Excluded(_) => ()
    _ => fail("positive polynomial cannot have a real root")
  }
}

///|
test "singular root stays undecided rather than becoming unique" {
  let s = { names: ["x"], equations: [Pow(Variable(0), 2)], }
  match assess(s, [interval(-1.0, 1.0)]) {
    Undecided(_) => ()
    _ => fail("double root must not receive a uniqueness proof")
  }
}

///|
test "root on a box boundary is not certified as interior" {
  let s = { names: ["x"], equations: [Variable(0)], }
  match assess(s, [interval(0.0, 1.0)]) {
    Unique(_) | Excluded(_) => fail("boundary root needs conservative handling")
    _ => ()
  }
}
