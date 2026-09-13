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
    %56 = llvm.mlir.constant(0.000000e+00 : f32) : f32
    %57 = llvm.mlir.constant(0 : index) : i64
    %58 = llvm.mlir.constant(10 : index) : i64
    %59 = llvm.mlir.constant(1 : index) : i64
    llvm.br ^bb1(%57 : i64)
  ^bb1(%60: i64):  // 2 preds: ^bb0, ^bb5
    %61 = llvm.icmp "slt" %60, %58 : i64
    llvm.cond_br %61, ^bb2, ^bb6
  ^bb2:  // pred: ^bb1
    %62 = llvm.mlir.constant(0 : index) : i64
    %63 = llvm.extractvalue %15[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %64 = llvm.mlir.constant(10 : index) : i64
    %65 = llvm.mul %62, %64  : i64
    %66 = llvm.add %65, %60  : i64
    %67 = llvm.getelementptr %63[%66] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %56, %67 : f32, !llvm.ptr
    %68 = llvm.mlir.constant(0 : index) : i64
    %69 = llvm.mlir.constant(16 : index) : i64
    %70 = llvm.mlir.constant(1 : index) : i64
    llvm.br ^bb3(%68 : i64)
  ^bb3(%71: i64):  // 2 preds: ^bb2, ^bb4
    %72 = llvm.icmp "slt" %71, %69 : i64
    llvm.cond_br %72, ^bb4, ^bb5
  ^bb4:  // pred: ^bb3
    %73 = llvm.mlir.constant(0 : index) : i64
    %74 = llvm.extractvalue %7[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %75 = llvm.mlir.constant(16 : index) : i64
    %76 = llvm.mul %73, %75  : i64
    %77 = llvm.add %76, %71  : i64
    %78 = llvm.getelementptr %74[%77] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %79 = llvm.load %78 : !llvm.ptr -> f32
    %80 = llvm.mlir.constant(10 : index) : i64
    %81 = llvm.mul %71, %80  : i64
    %82 = llvm.add %81, %60  : i64
    %83 = llvm.getelementptr %44[%82] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %84 = llvm.load %83 : !llvm.ptr -> f32
    %85 = llvm.mlir.constant(0 : index) : i64
    %86 = llvm.extractvalue %15[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %87 = llvm.mlir.constant(10 : index) : i64
    %88 = llvm.mul %85, %87  : i64
    %89 = llvm.add %88, %60  : i64
    %90 = llvm.getelementptr %86[%89] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %91 = llvm.load %90 : !llvm.ptr -> f32
    %92 = llvm.fmul %79, %84  : f32
    %93 = llvm.fadd %91, %92  : f32
    %94 = llvm.mlir.constant(0 : index) : i64
    %95 = llvm.extractvalue %15[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %96 = llvm.mlir.constant(10 : index) : i64
    %97 = llvm.mul %94, %96  : i64
    %98 = llvm.add %97, %60  : i64
    %99 = llvm.getelementptr %95[%98] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %93, %99 : f32, !llvm.ptr
    %100 = llvm.add %71, %70  : i64
    llvm.br ^bb3(%100 : i64)
  ^bb5:  // pred: ^bb3
    %101 = llvm.mlir.constant(0 : index) : i64
    %102 = llvm.extractvalue %15[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %103 = llvm.mlir.constant(10 : index) : i64
    %104 = llvm.mul %101, %103  : i64
    %105 = llvm.add %104, %60  : i64
    %106 = llvm.getelementptr %102[%105] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %107 = llvm.load %106 : !llvm.ptr -> f32
    %108 = llvm.mlir.constant(0 : index) : i64
    %109 = llvm.mlir.constant(10 : index) : i64
    %110 = llvm.mul %108, %109  : i64
    %111 = llvm.add %110, %60  : i64
    %112 = llvm.getelementptr %24[%111] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %113 = llvm.load %112 : !llvm.ptr -> f32
    %114 = llvm.fadd %107, %113  : f32
    %115 = llvm.mlir.constant(0 : index) : i64
    %116 = llvm.extractvalue %15[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %117 = llvm.mlir.constant(10 : index) : i64
    %118 = llvm.mul %115, %117  : i64
    %119 = llvm.add %118, %60  : i64
    %120 = llvm.getelementptr %116[%119] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %114, %120 : f32, !llvm.ptr
    %121 = llvm.add %60, %59  : i64
    llvm.br ^bb1(%121 : i64)
  ^bb6:  // pred: ^bb1
    llvm.return
  }
}

