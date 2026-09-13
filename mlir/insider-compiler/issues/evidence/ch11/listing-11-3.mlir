module attributes {llvm.data_layout = ""} {
  llvm.func @test_scalar(%arg0: f32, %arg1: f32) -> f32 {
    %0 = llvm.fadd %arg0, %arg1 : f32
    llvm.return %0 : f32
  }
}
