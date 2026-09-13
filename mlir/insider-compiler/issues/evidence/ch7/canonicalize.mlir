func.func @and_ext(%x: i8, %y: i8) -> i32 {
  %a = arith.extui %x : i8 to i32
  %b = arith.extui %y : i8 to i32
  %r = arith.andi %a, %b : i32
  return %r : i32
}
