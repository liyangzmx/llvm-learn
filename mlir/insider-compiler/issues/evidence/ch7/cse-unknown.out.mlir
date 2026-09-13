module {
  func.func @unknown(%arg0: i32) -> (i32, i32) {
    %0 = "unknown.op"(%arg0) : (i32) -> i32
    %1 = "unknown.op"(%arg0) : (i32) -> i32
    return %0, %1 : i32, i32
  }
}

