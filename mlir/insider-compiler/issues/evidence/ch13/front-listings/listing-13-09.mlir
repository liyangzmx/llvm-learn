module {
  tt.func @test_splat_elementwise_pattern(%arg0: f32)
      -> (tensor<128x128xf32>, tensor<128x128x!tt.ptr<f32>>) {
    %c1_i64 = arith.constant 1 : i64
    %cst = arith.constant dense<1.000000e+00> : tensor<128x128xf32>
    %0 = tt.splat %arg0 : f32 -> tensor<128x128xf32>
    %1 = arith.addf %cst, %0 : tensor<128x128xf32>
    %2 = tt.splat %c1_i64 : i64 -> tensor<128x128xi64>
    %3 = tt.int_to_ptr %c1_i64 : i64 -> !tt.ptr<f32>
    %4 = tt.splat %3 : !tt.ptr<f32> -> tensor<128x128x!tt.ptr<f32>>
    %5 = tt.int_to_ptr %2 : tensor<128x128xi64> -> tensor<128x128x!tt.ptr<f32>>
    tt.return %1, %4 : tensor<128x128xf32>, tensor<128x128x!tt.ptr<f32>>
  }
}
