module {
  func.func private @log1pf(f32) -> f32 attributes {llvm.readnone}
  func.func @log1p(%arg0: f32) -> f32 {
    // log1pf 由运行库提供。
    %0 = call @log1pf(%arg0) : (f32) -> f32
    return %0 : f32
  }
}
