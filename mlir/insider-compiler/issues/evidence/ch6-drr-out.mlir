module {
  func.func @equal(%arg0: i32, %arg1: i32, %arg2: i32, %arg3: i32, %arg4: i32, %arg5: i32) -> i32 {
    %0 = "test.op_p"(%arg0, %arg1, %arg2, %arg3, %arg4, %arg5) : (i32, i32, i32, i32, i32, i32) -> i32
    return %arg1 : i32
  }
  func.func @unequal(%arg0: i32, %arg1: i32, %arg2: i32, %arg3: i32, %arg4: i32, %arg5: i32) -> i32 {
    %0 = "test.op_p"(%arg0, %arg1, %arg2, %arg3, %arg4, %arg5) : (i32, i32, i32, i32, i32, i32) -> i32
    %1 = "test.op_n"(%arg0, %0) : (i32, i32) -> i32
    return %1 : i32
  }
}

