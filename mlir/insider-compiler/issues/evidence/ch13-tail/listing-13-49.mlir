#blocked = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>
#blocked1 = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [0, 1]}>
#mma = #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = []}>
module attributes {"triton_gpu.num-warps" = 4 : i32, "triton_gpu.target" = "cuda:80"} {
  tt.func @push_elementwise(
      %arg0: tensor<16x16x!tt.ptr<i8>, #blocked> {tt.contiguity = 2 : i32, tt.divisibility = 16 : i32},
      %arg1: tensor<16x16x!tt.ptr<f16>, #blocked1> {tt.contiguity = 2 : i32, tt.divisibility = 16 : i32},
      %arg2: tensor<16x16xf32, #mma>) -> tensor<16x16xf32, #mma> {
    %0 = tt.load %arg0 : tensor<16x16x!tt.ptr<i8>, #blocked>
    %1 = tt.load %arg1 : tensor<16x16x!tt.ptr<f16>, #blocked1>
    %2 = triton_gpu.convert_layout %0 : tensor<16x16xi8, #blocked> -> tensor<16x16xi8, #triton_gpu.dot_op<{opIdx = 0, parent = #mma, kWidth = 4}>>
    %3 = tt.bitcast %2 : tensor<16x16xi8, #triton_gpu.dot_op<{opIdx = 0, parent = #mma, kWidth = 4}>> -> tensor<16x16xf8E5M2, #triton_gpu.dot_op<{opIdx = 0, parent = #mma, kWidth = 4}>>
    %4 = tt.fp_to_fp %3 : tensor<16x16xf8E5M2, #triton_gpu.dot_op<{opIdx = 0, parent = #mma, kWidth = 4}>> -> tensor<16x16xf16, #triton_gpu.dot_op<{opIdx = 0, parent = #mma, kWidth = 4}>>
    %5 = triton_gpu.convert_layout %1 : tensor<16x16xf16, #blocked1> -> tensor<16x16xf16, #triton_gpu.dot_op<{opIdx = 1, parent = #mma, kWidth = 4}>>
    %6 = tt.dot %4, %5, %arg2 : tensor<16x16xf16, #triton_gpu.dot_op<{opIdx = 0, parent = #mma, kWidth = 4}>> * tensor<16x16xf16, #triton_gpu.dot_op<{opIdx = 1, parent = #mma, kWidth = 4}>> -> tensor<16x16xf32, #mma>
    tt.return %6 : tensor<16x16xf32, #mma>
  }
}
