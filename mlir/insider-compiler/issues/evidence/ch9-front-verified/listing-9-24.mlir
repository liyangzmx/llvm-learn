module {
  func.func @conv1d_8_tensor(%arg0: tensor<11xf32>, %arg1: tensor<4xf32>, %arg2: tensor<8xf32>) -> tensor<8xf32> {
    %c0 = arith.constant 0 : index
    %cst = arith.constant 0.000000e+00 : f32
    %0 = vector.transfer_read %arg0[%c0], %cst {in_bounds = [true]} : tensor<11xf32>, vector<11xf32>
    %1 = vector.transfer_read %arg1[%c0], %cst {in_bounds = [true]} : tensor<4xf32>, vector<4xf32>
    %2 = vector.transfer_read %arg2[%c0], %cst {in_bounds = [true]} : tensor<8xf32>, vector<8xf32>
    %3 = vector.extract_strided_slice %0 {offsets = [0], sizes = [8], strides = [1]} : vector<11xf32> to vector<8xf32>
    %4 = vector.extract_strided_slice %0 {offsets = [1], sizes = [8], strides = [1]} : vector<11xf32> to vector<8xf32>
    %5 = vector.extract_strided_slice %0 {offsets = [2], sizes = [8], strides = [1]} : vector<11xf32> to vector<8xf32>
    %6 = vector.extract_strided_slice %0 {offsets = [3], sizes = [8], strides = [1]} : vector<11xf32> to vector<8xf32>
    %7 = vector.extract %1[0] : f32 from vector<4xf32>
    %8 = vector.extract %1[1] : f32 from vector<4xf32>
    %9 = vector.extract %1[2] : f32 from vector<4xf32>
    %10 = vector.extract %1[3] : f32 from vector<4xf32>
    %11 = vector.outerproduct %3, %7, %2 {kind = #vector.kind<add>} : vector<8xf32>, f32
    %12 = vector.outerproduct %4, %8, %11 {kind = #vector.kind<add>} : vector<8xf32>, f32
    %13 = vector.outerproduct %5, %9, %12 {kind = #vector.kind<add>} : vector<8xf32>, f32
    %14 = vector.outerproduct %6, %10, %13 {kind = #vector.kind<add>} : vector<8xf32>, f32
    %15 = vector.transfer_write %14, %arg2[%c0] {in_bounds = [true]} : vector<8xf32>, tensor<8xf32>
    return %15 : tensor<8xf32>
  }
}
