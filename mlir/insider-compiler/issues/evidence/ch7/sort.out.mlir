module {
  func.func @sort(%arg0: i32, %arg1: i32) -> i32 {
    %c0_i32 = arith.constant 0 : i32
    %0 = "foo.mul"(%arg0, %arg1) : (i32, i32) -> i32
    %1 = "foo.mul"(%0, %c0_i32) : (i32, i32) -> i32
    %2 = "foo.add"(%0, %c0_i32) : (i32, i32) -> i32
    %3 = "test.op_commutative"(%2, %0, %1, %c0_i32) : (i32, i32, i32, i32) -> i32
    return %3 : i32
  }
}

