module {
  gpu.module @matmul_kernel {
    llvm.func @matmul(%arg0: !llvm.ptr, %arg1: !llvm.ptr, %arg2: i64, %arg3: i64, %arg4: i64, %arg5: i64, %arg6: i64, %arg7: !llvm.ptr, %arg8: !llvm.ptr, %arg9: i64, %arg10: i64, %arg11: i64, %arg12: i64, %arg13: i64, %arg14: !llvm.ptr, %arg15: !llvm.ptr, %arg16: i64, %arg17: i64, %arg18: i64, %arg19: i64, %arg20: i64) attributes {gpu.kernel, nvvm.kernel} {
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
      %16 = llvm.mlir.undef : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %17 = llvm.insertvalue %arg14, %16[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %18 = llvm.insertvalue %arg15, %17[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %19 = llvm.insertvalue %arg16, %18[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %20 = llvm.insertvalue %arg17, %19[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %21 = llvm.insertvalue %arg19, %20[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %22 = llvm.insertvalue %arg18, %21[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %23 = llvm.insertvalue %arg20, %22[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %24 = llvm.mlir.constant(0.000000e+00 : f32) : f32
      %25 = llvm.mlir.constant(0 : index) : i64
      %26 = builtin.unrealized_conversion_cast %25 : i64 to index
      %27 = llvm.mlir.constant(1 : index) : i64
      %28 = builtin.unrealized_conversion_cast %27 : i64 to index
      %29 = llvm.mlir.constant(128 : index) : i64
      %30 = llvm.mlir.constant(256 : index) : i64
      %31 = builtin.unrealized_conversion_cast %30 : i64 to index
      %32 = llvm.mlir.constant(512 : index) : i64
      %33 = nvvm.read.ptx.sreg.tid.x : i32
      %34 = llvm.sext %33 : i32 to i64
      %35 = nvvm.read.ptx.sreg.tid.y : i32
      %36 = llvm.sext %35 : i32 to i64
      %37 = nvvm.read.ptx.sreg.ctaid.x : i32
      %38 = llvm.sext %37 : i32 to i64
      %39 = nvvm.read.ptx.sreg.ctaid.y : i32
      %40 = llvm.sext %39 : i32 to i64
      %41 = nvvm.read.ptx.sreg.ntid.x : i32
      %42 = llvm.sext %41 : i32 to i64
      %43 = nvvm.read.ptx.sreg.ntid.y : i32
      %44 = llvm.sext %43 : i32 to i64
      %45 = llvm.mul %38, %42  : i64
      %46 = llvm.add %45, %34  : i64
      %47 = llvm.mul %40, %44  : i64
      %48 = llvm.add %47, %36  : i64
      %49 = llvm.icmp "slt" %46, %29 : i64
      %50 = llvm.icmp "slt" %48, %32 : i64
      %51 = llvm.and %49, %50  : i1
      scf.if %51 {
        %52 = scf.for %arg21 = %26 to %31 step %28 iter_args(%arg22 = %24) -> (f32) {
          %58 = builtin.unrealized_conversion_cast %arg21 : index to i64
          %59 = llvm.extractvalue %7[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
          %60 = llvm.mlir.constant(256 : index) : i64
          %61 = llvm.mul %46, %60  : i64
          %62 = llvm.add %61, %58  : i64
          %63 = llvm.getelementptr %59[%62] : (!llvm.ptr, i64) -> !llvm.ptr, f32
          %64 = llvm.load %63 : !llvm.ptr -> f32
          %65 = llvm.extractvalue %15[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
          %66 = llvm.mlir.constant(512 : index) : i64
          %67 = llvm.mul %58, %66  : i64
          %68 = llvm.add %67, %48  : i64
          %69 = llvm.getelementptr %65[%68] : (!llvm.ptr, i64) -> !llvm.ptr, f32
          %70 = llvm.load %69 : !llvm.ptr -> f32
          %71 = llvm.fmul %64, %70  : f32
          %72 = llvm.fadd %arg22, %71  : f32
          scf.yield %72 : f32
        }
        %53 = llvm.extractvalue %23[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
        %54 = llvm.mlir.constant(512 : index) : i64
        %55 = llvm.mul %46, %54  : i64
        %56 = llvm.add %55, %48  : i64
        %57 = llvm.getelementptr %53[%56] : (!llvm.ptr, i64) -> !llvm.ptr, f32
        llvm.store %52, %57 : f32, !llvm.ptr
      }
      llvm.return
    }
  }
}

