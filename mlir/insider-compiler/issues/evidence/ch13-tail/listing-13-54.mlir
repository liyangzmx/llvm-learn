#blocked = #triton_gpu.blocked<{sizePerThread = [1], threadsPerWarp = [32], warpsPerCTA = [4], order = [0]}>
module attributes {"triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32, "triton_gpu.target" = "cuda:90", "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func public @select_if_combine(%arg0: tensor<64xf32, #blocked>, %dst_ptr: tensor<64x!tt.ptr<f32>, #blocked>, %cnd: i1) attributes {noinline = false} {
    %cst = arith.constant dense<0.0> : tensor<64xf32, #blocked>
    %cst_1 = arith.constant dense<1.0> : tensor<64xf32, #blocked>
    %sel = arith.select %cnd, %cst, %cst_1 : tensor<64xf32, #blocked>
    scf.if %cnd {
      tt.store %dst_ptr, %arg0 : tensor<64x!tt.ptr<f32>, #blocked>
    }
    tt.store %dst_ptr, %sel : tensor<64x!tt.ptr<f32>, #blocked>
    tt.return
  }
}
