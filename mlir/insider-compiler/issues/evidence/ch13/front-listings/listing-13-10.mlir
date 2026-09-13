module {
  tt.func @test_splat_elementwise_pattern(%arg0: f32)
      -> (tensor<128x128xf32>, tensor<128x128x!tt.ptr<f32>>) {
    %c1_i64 = arith.constant 1 : i64
    %cst = arith.constant 1.000000e+00 : f32

    %0 = arith.addf %arg0, %cst : f32
    %1 = tt.splat %0 : f32 -> tensor<128x128xf32>
    %2 = tt.int_to_ptr %c1_i64 : i64 -> !tt.ptr<f32>
    %3 = tt.splat %2 : !tt.ptr<f32> -> tensor<128x128x!tt.ptr<f32>>
    tt.return %1, %3 : tensor<128x128xf32>, tensor<128x128x!tt.ptr<f32>>
  }
}
