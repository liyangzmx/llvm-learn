module {
  func.func @bad(%a: f16, %b: f32) -> f16 {
    %r = "arith.addf"(%a, %b) : (f16, f32) -> f16
    return %r : f16
  }
}
