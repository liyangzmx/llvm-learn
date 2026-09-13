#map = affine_map<(d0, d1, d2, d3) -> (d0, d1, d3)>
#map1 = affine_map<(d0, d1, d2, d3) -> (d3, d2)>
#map2 = affine_map<(d0, d1, d2, d3) -> (d0, d1, d2)>
module {
  func.func @conv1d_nwc_4x2x8_memref(%arg0: memref<4x6x3xf32>, %arg1: memref<1x3x8xf32>, %arg2: memref<4x2x8xf32>) {
    %c0 = arith.constant 0 : index
    %cst = arith.constant 0.000000e+00 : f32
    %0 = vector.transfer_read %arg0[%c0, %c0, %c0], %cst {in_bounds = [true, true, true]} : memref<4x6x3xf32>, vector<4x4x3xf32>
    %1 = vector.transfer_read %arg1[%c0, %c0, %c0], %cst {in_bounds = [true, true, true]} : memref<1x3x8xf32>, vector<1x3x8xf32>
    %2 = vector.transfer_read %arg2[%c0, %c0, %c0], %cst {in_bounds = [true, true, true]} : memref<4x2x8xf32>, vector<4x2x8xf32>
    %3 = vector.extract_strided_slice %0 {offsets = [0, 0, 0], sizes = [4, 1, 3], strides = [1, 1, 1]} : vector<4x4x3xf32> to vector<4x1x3xf32>
    %4 = vector.extract_strided_slice %0 {offsets = [0, 3, 0], sizes = [4, 1, 3], strides = [1, 1, 1]} : vector<4x4x3xf32> to vector<4x1x3xf32>
    %5 = vector.extract %1[0] : vector<3x8xf32> from vector<1x3x8xf32>
    %6 = vector.extract_strided_slice %2 {offsets = [0, 0, 0], sizes = [4, 1, 8], strides = [1, 1, 1]} : vector<4x2x8xf32> to vector<4x1x8xf32>
    %7 = vector.extract_strided_slice %2 {offsets = [0, 1, 0], sizes = [4, 1, 8], strides = [1, 1, 1]} : vector<4x2x8xf32> to vector<4x1x8xf32>
    %8 = vector.contract {indexing_maps = [#map, #map1, #map2], iterator_types = ["parallel", "parallel", "parallel", "reduction"], kind = #vector.kind<add>} %3, %5, %6 : vector<4x1x3xf32>, vector<3x8xf32> into vector<4x1x8xf32>
    %9 = vector.contract {indexing_maps = [#map, #map1, #map2], iterator_types = ["parallel", "parallel", "parallel", "reduction"], kind = #vector.kind<add>} %4, %5, %7 : vector<4x1x3xf32>, vector<3x8xf32> into vector<4x1x8xf32>
    %10 = vector.insert_strided_slice %8, %2 {offsets = [0, 0, 0], strides = [1, 1, 1]} : vector<4x1x8xf32> into vector<4x2x8xf32>
    %11 = vector.insert_strided_slice %9, %10 {offsets = [0, 1, 0], strides = [1, 1, 1]} : vector<4x1x8xf32> into vector<4x2x8xf32>
    vector.transfer_write %11, %arg2[%c0, %c0, %c0] {in_bounds = [true, true, true]} : vector<4x2x8xf32>, memref<4x2x8xf32>
    return
  }
}
