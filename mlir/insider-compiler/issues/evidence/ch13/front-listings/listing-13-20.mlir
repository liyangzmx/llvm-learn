// 校订：原书把部分 module attributes 错排进函数体，现移回属性字典。
module attributes {"triton_gpu.num-ctas" = 1 : i32,
    "triton_gpu.num-warps" = 2 : i32, triton_gpu.target = "cuda:80",
    "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func @ops() {
    %a = arith.constant dense<1.00e+00> : tensor<128x32xf16>

    %b = arith.constant dense<2.00e+00> : tensor<32x128xf16>
    %c = arith.constant dense<3.00e+00> : tensor<128x128xf32>
    %0 = tt.dot %a, %b, %c
        : tensor<128x32xf16> * tensor<32x128xf16> -> tensor<128x128xf32>
    tt.return
  }
}
