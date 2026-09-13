func.func @muladd(%a: f32, %b: f32, %c: f32) -> f32 {
  %m = arith.mulf %a, %b : f32
  %s = arith.addf %m, %c : f32
  return %s : f32
}
