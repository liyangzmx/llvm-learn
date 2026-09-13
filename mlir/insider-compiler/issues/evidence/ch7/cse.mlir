func.func @check_cummutative_cse(%a: i32, %b: i32) -> i32 {
  %1 = arith.addi %a, %b : i32
  %2 = arith.addi %b, %a : i32
  %3 = arith.muli %1, %2 : i32
  return %3 : i32
}
