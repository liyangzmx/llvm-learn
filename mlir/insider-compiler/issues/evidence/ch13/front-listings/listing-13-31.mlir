#blocked = #triton_gpu.blocked<{sizePerThread = [1, 2], threadsPerWarp = [1, 32],
    warpsPerCTA = [4, 1], order = [1, 0]}>
#blocked1 = #triton_gpu.blocked<{sizePerThread = [1], threadsPerWarp = [32],
    warpsPerCTA = [4], order = [0]}>
#blocked2 = #triton_gpu.blocked<{sizePerThread = [1, 1, 2], threadsPerWarp = [1, 32, 1],
    warpsPerCTA = [4, 1, 1], order = [2, 1, 0]}>
module attributes {"triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32,
    triton_gpu.target = "cuda:80", "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func public @mul_reduce(
      %arg0: !tt.ptr<f32> {tt.divisibility = 16 : i32},
      %arg1: !tt.ptr<f32> {tt.divisibility = 16 : i32},
      %arg2: i32 {tt.divisibility = 16 : i32, tt.max_divisibility = 8 : i32},
      %arg3: tensor<32x128x!tt.ptr<f32>, #blocked> {tt.divisibility = 16 : i32},
      %arg4: i32 {tt.divisibility = 16 : i32},
      %arg5: tensor<32x!tt.ptr<f32>, #blocked1> {tt.divisibility = 16 : i32})
      attributes {noinline = false} {
    %cst = arith.constant dense<1.000000e+00>
        : tensor<32x32xf32, #triton_gpu.slice<{dim = 2, parent = #blocked2}>>
    %c128_i32 = arith.constant 128 : i32
    %0 = tt.get_program_id y : i32
    %1 = tt.get_num_programs y : i32
    %2 = tt.make_range {end = 128 : i32, start = 0 : i32}
        : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
    %3 = scf.for %arg6 = %0 to %arg4 step %1 iter_args(%arg7 = %cst)
        -> (tensor<32x32xf32, #triton_gpu.slice<{dim = 2, parent = #blocked2}>>) : i32 {
      %6 = arith.muli %arg6, %c128_i32 : i32
      %7 = tt.splat %6 : i32
          -> tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %8 = arith.addi %7, %2
          : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %9 = tt.expand_dims %8 {axis = 0 : i32}
          : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
          -> tensor<1x128xi32, #blocked>
      %10 = tt.broadcast %9 : tensor<1x128xi32, #blocked> -> tensor<32x128xi32, #blocked>
      %11 = tt.addptr %arg3, %10
          : tensor<32x128x!tt.ptr<f32>, #blocked>, tensor<32x128xi32, #blocked>
      %12 = tt.load %11 : tensor<32x128x!tt.ptr<f32>, #blocked>
      %13 = tt.reshape %12 {allow_reorder = true, efficient_layout}
          : tensor<32x128xf32, #blocked> -> tensor<32x32x4xf32, #blocked2>
      %14 = "tt.reduce"(%13) <{axis = 2 : i32}> ({
      ^bb0(%arg8: f32, %arg9: f32):
        %16 = arith.mulf %arg8, %arg9 : f32
        tt.reduce.return %16 : f32

      }) : (tensor<32x32x4xf32, #blocked2>)
          -> tensor<32x32xf32, #triton_gpu.slice<{dim = 2, parent = #blocked2}>>
      %15 = arith.mulf %arg7, %14
          : tensor<32x32xf32, #triton_gpu.slice<{dim = 2, parent = #blocked2}>>
      scf.yield %15 : tensor<32x32xf32, #triton_gpu.slice<{dim = 2, parent = #blocked2}>>
    }
    %4 = "tt.reduce"(%3) <{axis = 1 : i32}> ({
    ^bb0(%arg6: f32, %arg7: f32):
      %6 = arith.mulf %arg6, %arg7 : f32
      tt.reduce.return %6 : f32
    }) : (tensor<32x32xf32, #triton_gpu.slice<{dim = 2, parent = #blocked2}>>)
        -> tensor<32xf32, #triton_gpu.slice<{dim = 1,
            parent = #triton_gpu.slice<{dim = 2, parent = #blocked2}>}>>
    %5 = triton_gpu.convert_layout %4
        : tensor<32xf32, #triton_gpu.slice<{dim = 1,
            parent = #triton_gpu.slice<{dim = 2, parent = #blocked2}>}>>
        -> tensor<32xf32, #blocked1>
    tt.store %arg5, %5 : tensor<32x!tt.ptr<f32>, #blocked1>
    tt.return
  }
}
