tt.func @test_combine_dot_add_pattern() -> tensor<128x128xf32> {
  %cst = arith.constant dense<1.000000e+00> : tensor<128x128xf32>
  %cst_0 = arith.constant dense<2.000000e+00> : tensor<128x128xf32>
  %cst_1 = arith.constant dense<3.000000e+00> : tensor<128x128xf32>
  %0 = tt.dot %cst, %cst_0, %cst_1
      : tensor<128x128xf32> * tensor<128x128xf32> -> tensor<128x128xf32>
  tt.return %0 : tensor<128x128xf32>
}
