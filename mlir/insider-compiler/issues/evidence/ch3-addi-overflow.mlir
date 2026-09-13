func.func @sum(%a: i32, %b: i32) -> i32 {
  %r = arith.addi %a, %b overflow<nsw, nuw> : i32
  return %r : i32
}
