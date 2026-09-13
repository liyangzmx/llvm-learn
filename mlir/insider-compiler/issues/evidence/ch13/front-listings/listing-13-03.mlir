module {
  tt.func public @matmul_kernel(
      %arg0: !tt.ptr<f16> {tt.divisibility = 16 : i32},

      %arg1: !tt.ptr<f16> {tt.divisibility = 16 : i32},
      %arg2: !tt.ptr<f16> {tt.divisibility = 16 : i32},
      %arg3: i32 {tt.divisibility = 16 : i32},
      %arg4: i32 {tt.divisibility = 16 : i32},
      %arg5: i32 {tt.divisibility = 16 : i32},
      %arg6: i32 {tt.divisibility = 16 : i32},
      %arg7: i32 {tt.divisibility = 16 : i32},
      %arg8: i32 {tt.divisibility = 16 : i32}) attributes {noinline = false} {
    // 此例 arg5=K，arg6=stride_am，arg7=stride_bk，arg8=stride_cm；
    // arg3、arg4 未使用，stride_ak/stride_bn/stride_cn 已特化为 1。
    %0 = tt.make_range {end = 128 : i32, start = 0 : i32} : tensor<128xi32>
    %1 = tt.make_range {end = 256 : i32, start = 0 : i32} : tensor<256xi32>
    %2 = tt.make_range {end = 64 : i32, start = 0 : i32} : tensor<64xi32>
    %3 = tt.expand_dims %0 {axis = 1 : i32} : tensor<128xi32> -> tensor<128x1xi32>
    %4 = tt.splat %arg6 : i32 -> tensor<128x1xi32>
    %5 = arith.muli %3, %4 : tensor<128x1xi32>
    %6 = tt.splat %arg0 : !tt.ptr<f16> -> tensor<128x1x!tt.ptr<f16>>
    %7 = tt.addptr %6, %5 : tensor<128x1x!tt.ptr<f16>>, tensor<128x1xi32>
    %8 = tt.expand_dims %2 {axis = 0 : i32} : tensor<64xi32> -> tensor<1x64xi32>
    %c1_i32 = arith.constant 1 : i32
    %cst = arith.constant dense<1> : tensor<1x64xi32>
    %9 = arith.muli %8, %cst : tensor<1x64xi32>
    %10 = tt.broadcast %7 : tensor<128x1x!tt.ptr<f16>> -> tensor<128x64x!tt.ptr<f16>>
    %11 = tt.broadcast %9 : tensor<1x64xi32> -> tensor<128x64xi32>
    %12 = tt.addptr %10, %11 : tensor<128x64x!tt.ptr<f16>>, tensor<128x64xi32>
    %13 = tt.expand_dims %2 {axis = 1 : i32} : tensor<64xi32> -> tensor<64x1xi32>
    %14 = tt.splat %arg7 : i32 -> tensor<64x1xi32>
    %15 = arith.muli %13, %14 : tensor<64x1xi32>
    %16 = tt.splat %arg1 : !tt.ptr<f16> -> tensor<64x1x!tt.ptr<f16>>
    %17 = tt.addptr %16, %15 : tensor<64x1x!tt.ptr<f16>>, tensor<64x1xi32>
    %18 = tt.expand_dims %1 {axis = 0 : i32} : tensor<256xi32> -> tensor<1x256xi32>
    %c1_i32_0 = arith.constant 1 : i32
    %cst_1 = arith.constant dense<1> : tensor<1x256xi32>
    %19 = arith.muli %18, %cst_1 : tensor<1x256xi32>
    %20 = tt.broadcast %17 : tensor<64x1x!tt.ptr<f16>> -> tensor<64x256x!tt.ptr<f16>>
    %21 = tt.broadcast %19 : tensor<1x256xi32> -> tensor<64x256xi32>
    %22 = tt.addptr %20, %21 : tensor<64x256x!tt.ptr<f16>>, tensor<64x256xi32>
    %23 = tt.call @"zeros__0cconstexpr_(constexpr_128_,_constexpr_256_)__1cconstexpr_fp32_"()
        : () -> tensor<128x256xf32>
    %c0_i32 = arith.constant 0 : i32
    %c64_i32 = arith.constant 64 : i32
    %24 = arith.bitcast %c0_i32 : i32 to i32
    %25 = arith.bitcast %arg5 : i32 to i32
    %26 = arith.bitcast %c64_i32 : i32 to i32

    %27 = llvm.mlir.undef : i32
    %28:3 = scf.for %arg9 = %24 to %25 step %26
        iter_args(%arg10 = %23, %arg11 = %12, %arg12 = %22)
        -> (tensor<128x256xf32>, tensor<128x64x!tt.ptr<f16>>,
            tensor<64x256x!tt.ptr<f16>>) : i32 {
      %40 = tt.load %arg11 : tensor<128x64x!tt.ptr<f16>>
      %41 = tt.load %arg12 : tensor<64x256x!tt.ptr<f16>>
      %cst_4 = arith.constant 0.000000e+00 : f32
      %cst_5 = arith.constant dense<0.000000e+00> : tensor<128x256xf32>
      %42 = tt.dot %40, %41, %cst_5, inputPrecision = tf32
          : tensor<128x64xf16> * tensor<64x256xf16> -> tensor<128x256xf32>
      %43 = arith.addf %arg10, %42 : tensor<128x256xf32>
      %c64_i32_6 = arith.constant 64 : i32
      %cst_7 = arith.constant dense<64> : tensor<128x64xi32>
      %44 = tt.addptr %arg11, %cst_7 : tensor<128x64x!tt.ptr<f16>>, tensor<128x64xi32>
      %c64_i32_8 = arith.constant 64 : i32
      %45 = arith.muli %arg7, %c64_i32_8 : i32
      %46 = tt.splat %45 : i32 -> tensor<64x256xi32>
      %47 = tt.addptr %arg12, %46 : tensor<64x256x!tt.ptr<f16>>, tensor<64x256xi32>
      scf.yield %43, %44, %47 : tensor<128x256xf32>,
          tensor<128x64x!tt.ptr<f16>>, tensor<64x256x!tt.ptr<f16>>
    }
    %29 = tt.expand_dims %0 {axis = 1 : i32} : tensor<128xi32> -> tensor<128x1xi32>
    %30 = tt.splat %arg8 : i32 -> tensor<128x1xi32>
    %31 = arith.muli %29, %30 : tensor<128x1xi32>
    %32 = tt.splat %arg2 : !tt.ptr<f16> -> tensor<128x1x!tt.ptr<f16>>
    %33 = tt.addptr %32, %31 : tensor<128x1x!tt.ptr<f16>>, tensor<128x1xi32>
    %34 = tt.expand_dims %1 {axis = 0 : i32} : tensor<256xi32> -> tensor<1x256xi32>
    %c1_i32_2 = arith.constant 1 : i32
    %cst_3 = arith.constant dense<1> : tensor<1x256xi32>
    %35 = arith.muli %34, %cst_3 : tensor<1x256xi32>
    %36 = tt.broadcast %33 : tensor<128x1x!tt.ptr<f16>> -> tensor<128x256x!tt.ptr<f16>>
    %37 = tt.broadcast %35 : tensor<1x256xi32> -> tensor<128x256xi32>
    %38 = tt.addptr %36, %37 : tensor<128x256x!tt.ptr<f16>>, tensor<128x256xi32>
    %39 = arith.truncf %28#0 : tensor<128x256xf32> to tensor<128x256xf16>
    tt.store %38, %39 : tensor<128x256x!tt.ptr<f16>>
    tt.return
  }
  // 校订补充：原书省略了被调用函数的定义。
  tt.func private @"zeros__0cconstexpr_(constexpr_128_,_constexpr_256_)__1cconstexpr_fp32_"()
      -> tensor<128x256xf32> {
    %zero = arith.constant dense<0.0> : tensor<128x256xf32>
    tt.return %zero : tensor<128x256xf32>
  }
}
