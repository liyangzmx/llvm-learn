module {
  func.func @check_cummutative_cse(%arg0: i32, %arg1: i32) -> i32 {
    %0 = arith.addi %arg0, %arg1 : i32
    %1 = arith.muli %0, %0 : i32
    return %1 : i32
  }
}

