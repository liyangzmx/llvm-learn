func.func @vect() -> vector<4x16xf32> {
  %10 = arith.constant 0.0 : f32
  %11 = vector.broadcast %10 : f32 to vector<16xf32>
  %12 = vector.broadcast %11 : vector<16xf32> to vector<4x16xf32>
  return %12 : vector<4x16xf32>
}
