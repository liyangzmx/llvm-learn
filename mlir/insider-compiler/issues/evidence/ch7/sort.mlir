func.func @sort(%a: i32, %b: i32) -> i32 {
  %c = arith.constant 0 : i32
  %m = "foo.mul"(%a, %b) : (i32, i32) -> i32
  %n = "foo.mul"(%m, %c) : (i32, i32) -> i32
  %a0 = "foo.add"(%m, %c) : (i32, i32) -> i32
  %r = "test.op_commutative"(%c, %m, %n, %a0) : (i32, i32, i32, i32) -> i32
  return %r : i32
}
