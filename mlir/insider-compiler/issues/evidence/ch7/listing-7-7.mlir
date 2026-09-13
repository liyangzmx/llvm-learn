func.func @check_cummutative_cse(%a: i32, %b: i32) -> i32 {
  %1 = arith.addi %a, %b : i32
  %3 = arith.muli %1, %1 : i32
  return %3 : i32
}
