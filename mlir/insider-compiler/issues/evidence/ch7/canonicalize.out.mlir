module {
  func.func @and_ext(%arg0: i8, %arg1: i8) -> i32 {
    %0 = arith.andi %arg0, %arg1 : i8
    %1 = arith.extui %0 : i8 to i32
    return %1 : i32
  }
}

