#ordinary = affine_map<(d0, d1) -> (d0 + d1, d1 + 16, 32)>
#symbolic = affine_map<(d0, d1)[s0] -> (d0, d1 + s0, d1 - s0 - 1, 4 * d0 + d1)>
#semi = affine_map<(d0)[s0] -> (d0 * s0)>
module attributes {test.ordinary = #ordinary, test.symbolic = #symbolic, test.semi = #semi} {
  func.func @minimum(%a: index, %b: index) -> index {
    %r = affine.min affine_map<(d0, d1) -> (d0, d1)>(%a, %b)
    return %r : index
  }
}
