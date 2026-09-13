#map = affine_map<(d0, d1) -> (d0 + d1, d1 + 16, 32)>
#map1 = affine_map<(d0)[s0] -> (d0 * s0)>
#map2 = affine_map<(d0, d1)[s0] -> (d0, d1 + s0, d1 - s0 - 1, d0 * 4 + d1)>
module attributes {test.ordinary = #map, test.semi = #map1, test.symbolic = #map2} {
  func.func @minimum(%arg0: index, %arg1: index) -> index {
    %0 = arith.cmpi slt, %arg0, %arg1 : index
    %1 = arith.select %0, %arg0, %arg1 : index
    return %1 : index
  }
}

