gpu.module @matmul_kernel {
  gpu.func @matmul(%A: memref<128x256xf32>,
                   %B: memref<256x512xf32>,
                   %C: memref<128x512xf32>) kernel {
    // 定义 index 常量。
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c128 = arith.constant 128 : index
    %c256 = arith.constant 256 : index
    %c512 = arith.constant 512 : index
    // 获取线程、块编号及实际块维度。
    %tid_x = gpu.thread_id x
    %tid_y = gpu.thread_id y
    %block_x = gpu.block_id x
    %block_y = gpu.block_id y
    %block_dim_x = gpu.block_dim x
    %block_dim_y = gpu.block_dim y
    // 计算输出矩阵坐标。
    %row_base = arith.muli %block_x, %block_dim_x : index
    %row = arith.addi %row_base, %tid_x : index
    %col_base = arith.muli %block_y, %block_dim_y : index
    %col = arith.addi %col_base, %tid_y : index
    %row_lt = arith.cmpi slt, %row, %c128 : index
    %col_lt = arith.cmpi slt, %col, %c512 : index
    %in_bounds = arith.andi %row_lt, %col_lt : i1
    scf.if %in_bounds {
      // 初始化累加器，沿归约维计算内积。
      %sum_init = arith.constant 0.0 : f32
      %final_sum = scf.for %k = %c0 to %c256 step %c1
          iter_args(%sum_iter = %sum_init) -> (f32) {
        %a_val = memref.load %A[%row, %k] : memref<128x256xf32>
        %b_val = memref.load %B[%k, %col] : memref<256x512xf32>
        %product = arith.mulf %a_val, %b_val : f32
        %new_sum = arith.addf %sum_iter, %product : f32
        scf.yield %new_sum : f32
      }
      memref.store %final_sum, %C[%row, %col] : memref<128x512xf32>
    }
    gpu.return
  }
}
