tt.func @test_combine_dot_add_pattern() -> tensor<128x128xf32> {
  %a = arith.constant dense<1.0> : tensor<128x128xf32>
  %b = arith.constant dense<2.0> : tensor<128x128xf32>
  %zero = arith.constant dense<0.0> : tensor<128x128xf32>
  %d = arith.constant dense<3.0> : tensor<128x128xf32>
  %dot_out = tt.dot %a, %b, %zero
      : tensor<128x128xf32> * tensor<128x128xf32> -> tensor<128x128xf32>
  %res = arith.addf %dot_out, %d : tensor<128x128xf32>
  tt.return %res : tensor<128x128xf32>
}
