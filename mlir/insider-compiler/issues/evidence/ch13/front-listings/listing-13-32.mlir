#blocked = #triton_gpu.blocked<{sizePerThread = [4, 4], threadsPerWarp = [1, 32],
    warpsPerCTA = [32, 1], order = [1, 0], CTAsPerCGA = [1, 1],
    CTASplitNum = [1, 1], CTAOrder = [1, 0]}>
module attributes {triton_gpu.target = "cuda:90", "triton_gpu.num-ctas" = 1 : i32,
    "triton_gpu.num-warps" = 32 : i32, "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func @check_instrShape_per_warps(%arg0: !tt.ptr<f32> {tt.divisibility = 16 : i32}) {
    %mask = arith.constant dense<true> : tensor<128x128xi1, #blocked>

    %zero_f32 = arith.constant dense<0.000000e+00> : tensor<128x128xf32, #blocked>
    %a = arith.constant dense<0.000000e+00>
        : tensor<128x128xf16, #triton_gpu.dot_op<{opIdx = 0, parent = #blocked}>>
    %b = arith.constant dense<0.000000e+00>
        : tensor<128x128xf16, #triton_gpu.dot_op<{opIdx = 1, parent = #blocked}>>
    %result = tt.dot %a, %b, %zero_f32
        : tensor<128x128xf16, #triton_gpu.dot_op<{opIdx = 0, parent = #blocked}>>
        * tensor<128x128xf16, #triton_gpu.dot_op<{opIdx = 1, parent = #blocked}>>
        -> tensor<128x128xf32, #blocked>
    %result_ptr = tt.splat %arg0 : !tt.ptr<f32> -> tensor<128x128x!tt.ptr<f32>, #blocked>
    tt.store %result_ptr, %result, %mask : tensor<128x128x!tt.ptr<f32>, #blocked>
    tt.return
  }
}
