module {
  func.func @callee(%arg0: i32) -> i32 {
    return %arg0 : i32
  }
  func.func @caller(%arg0: i32) -> i32 {
    return %arg0 : i32
  }
}

