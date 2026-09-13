#AL = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8],
    warpsPerCTA = [4, 1], order = [1, 0]}>
#BL = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32],
    warpsPerCTA = [4, 1], order = [1, 0]}>
#A = #triton_gpu.shared<{vec = 2, perPhase = 2, maxPhase = 4, order = [1, 0]}>
#B = #triton_gpu.shared<{vec = 2, perPhase = 2, maxPhase = 4, order = [1, 0]}>
#C = #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1]}>
#A_OP = #triton_gpu.dot_op<{opIdx = 0, parent = #C, kWidth = 2}>
#B_OP = #triton_gpu.dot_op<{opIdx = 1, parent = #C, kWidth = 2}>
// 使用 4 个 warp；矩阵形状为 128×16 乘 16×128，结果 128×128。
module attributes {"triton_gpu.num-warps" = 4 : i32} {
  tt.func @matmul_loop_mixed(%lb: index, %ub: index, %step: index,
      %A: !tt.ptr<f8E5M2>, %B: !tt.ptr<f16>) -> tensor<128x128xf32, #C> {
    %a_ptr_init = tt.splat %A : !tt.ptr<f8E5M2> -> tensor<128x16x!tt.ptr<f8E5M2>, #AL>

    %b_ptr_init = tt.splat %B : !tt.ptr<f16> -> tensor<16x128x!tt.ptr<f16>, #BL>
    %a_mask = arith.constant dense<true> : tensor<128x16xi1, #AL>
    %a_other = arith.constant dense<0.00e+00> : tensor<128x16xf8E5M2, #AL>
    %b_mask = arith.constant dense<true> : tensor<16x128xi1, #BL>
    %b_other = arith.constant dense<0.00e+00> : tensor<16x128xf16, #BL>
    %c_init = arith.constant dense<0.00e+00> : tensor<128x128xf32, #C>
    %a_off = arith.constant dense<4> : tensor<128x16xi32, #AL>
    %b_off = arith.constant dense<4> : tensor<16x128xi32, #BL>
    %a_ = tt.load %a_ptr_init, %a_mask, %a_other : tensor<128x16x!tt.ptr<f8E5M2>, #AL>
    %a_init = triton_gpu.local_alloc %a_ : (tensor<128x16xf8E5M2, #AL>)
        -> !tt.memdesc<128x16xf8E5M2, #A, #triton_gpu.shared_memory>
    %b_ = tt.load %b_ptr_init, %b_mask, %b_other : tensor<16x128x!tt.ptr<f16>, #BL>
    %b_init = triton_gpu.local_alloc %b_ : (tensor<16x128xf16, #BL>)
        -> !tt.memdesc<16x128xf16, #B, #triton_gpu.shared_memory>
    %loop:5 = scf.for %iv = %lb to %ub step %step
        iter_args(%a_ptr = %a_ptr_init, %b_ptr = %b_ptr_init,
            %a = %a_init, %b = %b_init, %prev_c = %c_init)
        -> (tensor<128x16x!tt.ptr<f8E5M2>, #AL>, tensor<16x128x!tt.ptr<f16>, #BL>,
            !tt.memdesc<128x16xf8E5M2, #A, #triton_gpu.shared_memory>,
            !tt.memdesc<16x128xf16, #B, #triton_gpu.shared_memory>, tensor<128x128xf32, #C>) {
      %a_op_ = triton_gpu.local_load %a
          : !tt.memdesc<128x16xf8E5M2, #A, #triton_gpu.shared_memory>
          -> tensor<128x16xf8E5M2, #A_OP>
      %a_op = tt.fp_to_fp %a_op_ : tensor<128x16xf8E5M2, #A_OP> -> tensor<128x16xf16, #A_OP>
      %b_op = triton_gpu.local_load %b
          : !tt.memdesc<16x128xf16, #B, #triton_gpu.shared_memory>
          -> tensor<16x128xf16, #B_OP>
      %c = tt.dot %a_op, %b_op, %prev_c
          : tensor<128x16xf16, #A_OP> * tensor<16x128xf16, #B_OP> -> tensor<128x128xf32, #C>
      %next_a_ptr = tt.addptr %a_ptr, %a_off
          : tensor<128x16x!tt.ptr<f8E5M2>, #AL>, tensor<128x16xi32, #AL>
      %next_b_ptr = tt.addptr %b_ptr, %b_off
          : tensor<16x128x!tt.ptr<f16>, #BL>, tensor<16x128xi32, #BL>
      %next_a_ = tt.load %next_a_ptr, %a_mask, %a_other : tensor<128x16x!tt.ptr<f8E5M2>, #AL>
      %next_a = triton_gpu.local_alloc %next_a_ : (tensor<128x16xf8E5M2, #AL>)
          -> !tt.memdesc<128x16xf8E5M2, #A, #triton_gpu.shared_memory>
      %next_b_ = tt.load %next_b_ptr, %b_mask, %b_other : tensor<16x128x!tt.ptr<f16>, #BL>
      %next_b = triton_gpu.local_alloc %next_b_ : (tensor<16x128xf16, #BL>)
          -> !tt.memdesc<16x128xf16, #B, #triton_gpu.shared_memory>
      scf.yield %next_a_ptr, %next_b_ptr, %next_a, %next_b, %c
          : tensor<128x16x!tt.ptr<f8E5M2>, #AL>, tensor<16x128x!tt.ptr<f16>, #BL>,
            !tt.memdesc<128x16xf8E5M2, #A, #triton_gpu.shared_memory>,
            !tt.memdesc<16x128xf16, #B, #triton_gpu.shared_memory>, tensor<128x128xf32, #C>
    }
    tt.return %loop#4 : tensor<128x128xf32, #C>
  }
}
