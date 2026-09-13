#blocked = #triton_gpu.blocked<{sizePerThread = [1], threadsPerWarp = [32],
    warpsPerCTA = [4], order = [0]}>
#blocked1 = #triton_gpu.blocked<{sizePerThread = [8], threadsPerWarp = [32],
    warpsPerCTA = [4], order = [0]}>
module attributes {"triton_gpu.num-ctas" = 1 : i32,
    "triton_gpu.num-warps" = 4 : i32, "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func public @load_tensors_two_types(
      %arg0: !tt.ptr<f32> {tt.divisibility = 16 : i32},
      %arg1: !tt.ptr<f16> {tt.divisibility = 16 : i32},
      %arg2: !tt.ptr<f16> {tt.divisibility = 16 : i32}, %arg3: i32)
      attributes {noinline = false} {
    %c1024_i32 = arith.constant 1024 : i32
    %0 = tt.get_program_id x : i32
    %1 = arith.muli %0, %c1024_i32 : i32
    %2 = tt.make_range {end = 1024 : i32, start = 0 : i32} : tensor<1024xi32, #blocked>
    %3 = tt.splat %1 : i32 -> tensor<1024xi32, #blocked>
    %4 = arith.addi %3, %2 : tensor<1024xi32, #blocked>
    %5 = tt.splat %arg3 : i32 -> tensor<1024xi32, #blocked>
    %6 = arith.cmpi slt, %4, %5 : tensor<1024xi32, #blocked>
    %7 = tt.splat %arg0 : !tt.ptr<f32> -> tensor<1024x!tt.ptr<f32>, #blocked>
    %8 = tt.addptr %7, %4 : tensor<1024x!tt.ptr<f32>, #blocked>, tensor<1024xi32, #blocked>
    %9 = triton_gpu.convert_layout %8 : tensor<1024x!tt.ptr<f32>, #blocked>
        -> tensor<1024x!tt.ptr<f32>, #blocked1>
    %10 = triton_gpu.convert_layout %6 : tensor<1024xi1, #blocked> -> tensor<1024xi1, #blocked1>
    %11 = tt.load %9, %10 : tensor<1024x!tt.ptr<f32>, #blocked1>
    %12 = triton_gpu.convert_layout %11 : tensor<1024xf32, #blocked1> -> tensor<1024xf32, #blocked>
    %13 = tt.splat %arg1 : !tt.ptr<f16> -> tensor<1024x!tt.ptr<f16>, #blocked>
    %14 = tt.addptr %13, %4 : tensor<1024x!tt.ptr<f16>, #blocked>, tensor<1024xi32, #blocked>
    %15 = triton_gpu.convert_layout %14 : tensor<1024x!tt.ptr<f16>, #blocked>
        -> tensor<1024x!tt.ptr<f16>, #blocked1>
    %16 = triton_gpu.convert_layout %6 : tensor<1024xi1, #blocked> -> tensor<1024xi1, #blocked1>

    %17 = tt.load %15, %16 : tensor<1024x!tt.ptr<f16>, #blocked1>
    %18 = triton_gpu.convert_layout %17 : tensor<1024xf16, #blocked1> -> tensor<1024xf16, #blocked>
    %19 = arith.extf %18 : tensor<1024xf16, #blocked> to tensor<1024xf32, #blocked>
    %20 = arith.addf %12, %19 : tensor<1024xf32, #blocked>
    %21 = tt.splat %arg2 : !tt.ptr<f16> -> tensor<1024x!tt.ptr<f16>, #blocked>
    %22 = tt.addptr %21, %4 : tensor<1024x!tt.ptr<f16>, #blocked>, tensor<1024xi32, #blocked>
    %23 = arith.truncf %20 : tensor<1024xf32, #blocked> to tensor<1024xf16, #blocked>
    %24 = triton_gpu.convert_layout %22 : tensor<1024x!tt.ptr<f16>, #blocked>
        -> tensor<1024x!tt.ptr<f16>, #blocked1>
    %25 = triton_gpu.convert_layout %23 : tensor<1024xf16, #blocked> -> tensor<1024xf16, #blocked1>
    %26 = triton_gpu.convert_layout %6 : tensor<1024xi1, #blocked> -> tensor<1024xi1, #blocked1>
    tt.store %24, %25, %26 : tensor<1024x!tt.ptr<f16>, #blocked1>
    tt.return
  }
}
