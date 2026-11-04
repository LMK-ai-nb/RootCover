///|
test "adjacent values include signed zero and subnormals" {
  assert_eq(next_up(0.0).reinterpret_as_int64(), 1L)
  assert_eq(next_down(0.0), -1L.reinterpret_as_double())
  assert_eq(next_down(next_up(1.0)), 1.0)
  assert_eq(next_up(next_down(-1.0)), -1.0)
  assert_eq(next_up(@double.max_value), @double.infinity)
  assert_eq(next_down(@double.neg_infinity), @double.neg_infinity)
}

///|
test "arithmetic encloses rounding and sign combinations" {
  let a = interval(-2.0, 3.0)
  let b = interval(4.0, 5.0)
  assert_true(a.mul(b).contains(-10.0))
  assert_true(a.mul(b).contains(15.0))
  assert_true(a.add(b).contains(2.0))
  assert_true(a.sub(b).contains(-7.0))
  assert_true(point(0.1).add(point(0.2)).contains(0.3))
}

///|
test "even powers and overflow remain conservative" {
  let p = interval(-2.0, 3.0).power(2)
  assert_eq(p.lo, 0.0)
  assert_true(p.hi >= 9.0)
  assert_true(interval(-2.0, -1.0).power(2).lo > 0.0)
  assert_true(point(@double.max_value).mul(point(2.0)).hi.is_pos_inf())
  assert_eq(point(0.0).mul(whole()), point(0.0))
}
