module {
  llvm.mlir.global private constant @__constant_16x10xf32(dense<"0x000080BF0000C0BE0000803E0000603F000020BF000000000000203F000060BF000080BE0000C03E000020BF000000000000203F000060BF000080BE0000C03E0000803F000000BF0000003E0000403F000080BE0000C03E0000803F000000BF0000003E0000403F000040BF000000BE0000003F000080BF0000003E0000403F000040BF000000BE0000003F000080BF0000C0BE0000803E0000603F000020BF0000003F000080BF0000C0BE0000803E0000603F000020BF000000000000203F000060BF000080BE0000603F000020BF000000000000203F000060BF000080BE0000C03E0000803F000000BF0000003E000060BF000080BE0000C03E0000803F000000BF0000003E0000403F000040BF000000BE0000003F000000BF0000003E0000403F000040BF000000BE0000003F000080BF0000C0BE0000803E0000603F000000BE0000003F000080BF0000C0BE0000803E0000603F000020BF000000000000203F000060BF0000803E0000603F000020BF000000000000203F000060BF000080BE0000C03E0000803F000000BF0000203F000060BF000080BE0000C03E0000803F000000BF0000003E0000403F000040BF000000BE0000803F000000BF0000003E0000403F000040BF000000BE0000003F000080BF0000C0BE0000803E000040BF000000BE0000003F000080BF0000C0BE0000803E0000603F000020BF000000000000203F0000C0BE0000803E0000603F000020BF000000000000203F000060BF000080BE0000C03E0000803F000000000000203F000060BF000080BE0000C03E0000803F000000BF0000003E0000403F000040BF0000C03E0000803F000000BF0000003E0000403F000040BF000000BE0000003F000080BF0000C0BE"> : tensor<16x10xf32>) {addr_space = 0 : i32} : !llvm.array<16 x array<10 x f32>>
  llvm.mlir.global private constant @__constant_1x10xf32(dense<[[-1.000000e+00, -7.500000e-01, -5.000000e-01, -2.500000e-01, 0.000000e+00, 2.500000e-01, 5.000000e-01, 7.500000e-01, 1.000000e+00, 1.250000e+00]]> : tensor<1x10xf32>) {addr_space = 0 : i32} : !llvm.array<1 x array<10 x f32>>
  llvm.func @forward(%arg0: !llvm.ptr, %arg1: !llvm.ptr, %arg2: i64, %arg3: i64, %arg4: i64, %arg5: i64, %arg6: i64, %arg7: !llvm.ptr, %arg8: !llvm.ptr, %arg9: i64, %arg10: i64, %arg11: i64, %arg12: i64, %arg13: i64) {
    %0 = llvm.mlir.undef : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %1 = llvm.insertvalue %arg0, %0[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %2 = llvm.insertvalue %arg1, %1[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %3 = llvm.insertvalue %arg2, %2[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %4 = llvm.insertvalue %arg3, %3[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %5 = llvm.insertvalue %arg5, %4[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %6 = llvm.insertvalue %arg4, %5[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %7 = llvm.insertvalue %arg6, %6[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %8 = llvm.mlir.undef : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %9 = llvm.insertvalue %arg7, %8[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %10 = llvm.insertvalue %arg8, %9[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %11 = llvm.insertvalue %arg9, %10[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %12 = llvm.insertvalue %arg10, %11[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %13 = llvm.insertvalue %arg12, %12[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %14 = llvm.insertvalue %arg11, %13[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %15 = llvm.insertvalue %arg13, %14[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %16 = llvm.mlir.constant(1 : index) : i64
    %17 = llvm.mlir.constant(10 : index) : i64
    %18 = llvm.mlir.constant(1 : index) : i64
    %19 = llvm.mlir.constant(10 : index) : i64
    %20 = llvm.mlir.zero : !llvm.ptr
    %21 = llvm.getelementptr %20[10] : (!llvm.ptr) -> !llvm.ptr, f32
    %22 = llvm.ptrtoint %21 : !llvm.ptr to i64
    %23 = llvm.mlir.addressof @__constant_1x10xf32 : !llvm.ptr
    %24 = llvm.getelementptr %23[0, 0, 0] : (!llvm.ptr) -> !llvm.ptr, !llvm.array<1 x array<10 x f32>>
    %25 = llvm.mlir.constant(3735928559 : index) : i64
    %26 = llvm.inttoptr %25 : i64 to !llvm.ptr
    %27 = llvm.mlir.undef : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %28 = llvm.insertvalue %26, %27[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %29 = llvm.insertvalue %24, %28[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %30 = llvm.mlir.constant(0 : index) : i64
    %31 = llvm.insertvalue %30, %29[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %32 = llvm.insertvalue %16, %31[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %33 = llvm.insertvalue %17, %32[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %34 = llvm.insertvalue %17, %33[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %35 = llvm.insertvalue %18, %34[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %36 = llvm.mlir.constant(16 : index) : i64
    %37 = llvm.mlir.constant(10 : index) : i64
    %38 = llvm.mlir.constant(1 : index) : i64
    %39 = llvm.mlir.constant(160 : index) : i64
    %40 = llvm.mlir.zero : !llvm.ptr
    %41 = llvm.getelementptr %40[160] : (!llvm.ptr) -> !llvm.ptr, f32
    %42 = llvm.ptrtoint %41 : !llvm.ptr to i64
    %43 = llvm.mlir.addressof @__constant_16x10xf32 : !llvm.ptr
    %44 = llvm.getelementptr %43[0, 0, 0] : (!llvm.ptr) -> !llvm.ptr, !llvm.array<16 x array<10 x f32>>
    %45 = llvm.mlir.constant(3735928559 : index) : i64
    %46 = llvm.inttoptr %45 : i64 to !llvm.ptr
    %47 = llvm.mlir.undef : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %48 = llvm.insertvalue %46, %47[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %49 = llvm.insertvalue %44, %48[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %50 = llvm.mlir.constant(0 : index) : i64
    %51 = llvm.insertvalue %50, %49[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %52 = llvm.insertvalue %36, %51[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %53 = llvm.insertvalue %37, %52[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %54 = llvm.insertvalue %37, %53[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %55 = llvm.insertvalue %38, %54[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %56 = llvm.mlir.constant(1 : index) : i64
    %57 = llvm.mul %16, %56  : i64
    %58 = llvm.mul %57, %17  : i64
    %59 = llvm.mlir.zero : !llvm.ptr
    %60 = llvm.getelementptr %59[1] : (!llvm.ptr) -> !llvm.ptr, f32
    %61 = llvm.ptrtoint %60 : !llvm.ptr to i64
    %62 = llvm.mul %58, %61  : i64
    %63 = llvm.getelementptr %24[%30] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %64 = llvm.extractvalue %15[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %65 = llvm.extractvalue %15[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %66 = llvm.getelementptr %64[%65] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "llvm.intr.memcpy"(%66, %63, %62) <{isVolatile = false}> : (!llvm.ptr, !llvm.ptr, i64) -> ()
    %67 = llvm.mlir.constant(0 : index) : i64
    %68 = llvm.mlir.constant(10 : index) : i64
    %69 = llvm.mlir.constant(1 : index) : i64
    llvm.br ^bb1(%67 : i64)
  ^bb1(%70: i64):  // 2 preds: ^bb0, ^bb5
    %71 = llvm.icmp "slt" %70, %68 : i64
    llvm.cond_br %71, ^bb2, ^bb6
  ^bb2:  // pred: ^bb1
    %72 = llvm.mlir.constant(0 : index) : i64
    %73 = llvm.mlir.constant(16 : index) : i64
    %74 = llvm.mlir.constant(1 : index) : i64
    llvm.br ^bb3(%72 : i64)
  ^bb3(%75: i64):  // 2 preds: ^bb2, ^bb4
    %76 = llvm.icmp "slt" %75, %73 : i64
    llvm.cond_br %76, ^bb4, ^bb5
  ^bb4:  // pred: ^bb3
    %77 = llvm.mlir.constant(0 : index) : i64
    %78 = llvm.extractvalue %7[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %79 = llvm.mlir.constant(16 : index) : i64
    %80 = llvm.mul %77, %79  : i64
    %81 = llvm.add %80, %75  : i64
    %82 = llvm.getelementptr %78[%81] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %83 = llvm.load %82 : !llvm.ptr -> f32
    %84 = llvm.mlir.constant(10 : index) : i64
    %85 = llvm.mul %75, %84  : i64
    %86 = llvm.add %85, %70  : i64
    %87 = llvm.getelementptr %44[%86] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %88 = llvm.load %87 : !llvm.ptr -> f32
    %89 = llvm.mlir.constant(0 : index) : i64
    %90 = llvm.extractvalue %15[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %91 = llvm.mlir.constant(10 : index) : i64
    %92 = llvm.mul %89, %91  : i64
    %93 = llvm.add %92, %70  : i64
    %94 = llvm.getelementptr %90[%93] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %95 = llvm.load %94 : !llvm.ptr -> f32
    %96 = llvm.fmul %83, %88  : f32
    %97 = llvm.fadd %95, %96  : f32
    %98 = llvm.mlir.constant(0 : index) : i64
    %99 = llvm.extractvalue %15[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %100 = llvm.mlir.constant(10 : index) : i64
    %101 = llvm.mul %98, %100  : i64
    %102 = llvm.add %101, %70  : i64
    %103 = llvm.getelementptr %99[%102] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %97, %103 : f32, !llvm.ptr
    %104 = llvm.add %75, %74  : i64
    llvm.br ^bb3(%104 : i64)
  ^bb5:  // pred: ^bb3
    %105 = llvm.add %70, %69  : i64
    llvm.br ^bb1(%105 : i64)
  ^bb6:  // pred: ^bb1
    llvm.return
  }
}

