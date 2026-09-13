func.func @test_scalar_bf16(%arg0: bf16, %arg1: bf16) -> bf16 {
  %0 = "arith.addf"(%arg0, %arg1) : (bf16, bf16) -> bf16
  return %0 : bf16
}
