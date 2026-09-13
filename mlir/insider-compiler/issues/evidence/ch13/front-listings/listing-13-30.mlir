#blocked = #triton_gpu.blocked<{sizePerThread = [1, 2], threadsPerWarp = [1, 32],
    warpsPerCTA = [4, 1], order = [1, 0]}>
#blocked1 = #triton_gpu.blocked<{sizePerThread = [1], threadsPerWarp = [32],
    warpsPerCTA = [4], order = [0]}>
module attributes {triton_gpu.target = "cuda:80", "triton_gpu.num-ctas" = 1 : i32,
    "triton_gpu.num-warps" = 4 : i32, "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func public @mul_reduce(
      %arg0: !tt.ptr<f32> {tt.divisibility = 16 : i32},
      %arg1: !tt.ptr<f32> {tt.divisibility = 16 : i32},
      %arg2: i32 {tt.divisibility = 16 : i32, tt.max_divisibility = 8 : i32},

      %18: tensor<32x128x!tt.ptr<f32>, #blocked> {tt.divisibility = 16 : i32},
      %11: i32 {tt.divisibility = 16 : i32},
      %25: tensor<32x!tt.ptr<f32>, #blocked1> {tt.divisibility = 16 : i32})
      attributes {noinline = false} {
    %cst = arith.constant dense<1.000000e+00>
        : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    %c128_i32 = arith.constant 128 : i32
    %1 = tt.get_program_id y : i32
    %2 = tt.get_num_programs y : i32
    %12 = tt.make_range {end = 128 : i32, start = 0 : i32}
        : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
    %19 = scf.for %arg3 = %1 to %11 step %2 iter_args(%arg4 = %cst)
        -> (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>) : i32 {
      %27 = arith.muli %arg3, %c128_i32 : i32
      %28 = tt.splat %27 : i32
          -> tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %29 = arith.addi %28, %12
          : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %30 = tt.expand_dims %29 {axis = 0 : i32}
          : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
          -> tensor<1x128xi32, #blocked>
      %31 = tt.broadcast %30 : tensor<1x128xi32, #blocked> -> tensor<32x128xi32, #blocked>
      %32 = tt.addptr %18, %31
          : tensor<32x128x!tt.ptr<f32>, #blocked>, tensor<32x128xi32, #blocked>
      %33 = tt.load %32 : tensor<32x128x!tt.ptr<f32>, #blocked>
      %34 = "tt.reduce"(%33) <{axis = 1 : i32}> ({
      ^bb0(%arg5: f32, %arg6: f32):
        %36 = arith.mulf %arg5, %arg6 : f32
        tt.reduce.return %36 : f32
      }) : (tensor<32x128xf32, #blocked>)
          -> tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      %35 = arith.mulf %arg4, %34
          : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      scf.yield %35 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    }
    %26 = triton_gpu.convert_layout %19
        : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
        -> tensor<32xf32, #blocked1>
    tt.store %25, %26 : tensor<32x!tt.ptr<f32>, #blocked1>
    tt.return
  }
}
