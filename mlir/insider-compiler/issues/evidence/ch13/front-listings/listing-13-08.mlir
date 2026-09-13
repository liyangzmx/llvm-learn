tt.func @test_splat_elementwise_pattern(%arg0: f32)
    -> (tensor<128x128xf32>, tensor<128x128x!tt.ptr<f32>>) {
  %c1 = arith.constant 1 : i64
  %a = arith.constant dense<1.0> : tensor<128x128xf32>
  %b = tt.splat %arg0 : f32 -> tensor<128x128xf32>
  %add = arith.addf %a, %b : tensor<128x128xf32>
  %c1_t = tt.splat %c1 : i64 -> tensor<128x128xi64>
  %ptr = tt.int_to_ptr %c1_t : tensor<128x128xi64> -> tensor<128x128x!tt.ptr<f32>>
  tt.return %add, %ptr : tensor<128x128xf32>, tensor<128x128x!tt.ptr<f32>>
}
