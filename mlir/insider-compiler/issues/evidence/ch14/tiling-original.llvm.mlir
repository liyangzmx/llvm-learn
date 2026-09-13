module {
  llvm.func @free(!llvm.ptr)
  llvm.func @malloc(i64) -> !llvm.ptr
  llvm.func @negative_inner_distance(%arg0: !llvm.ptr, %arg1: !llvm.ptr, %arg2: i64, %arg3: i64, %arg4: i64, %arg5: i64, %arg6: i64) {
    %0 = llvm.mlir.undef : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %1 = llvm.insertvalue %arg0, %0[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %2 = llvm.insertvalue %arg1, %1[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %3 = llvm.insertvalue %arg2, %2[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %4 = llvm.insertvalue %arg3, %3[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %5 = llvm.insertvalue %arg5, %4[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %6 = llvm.insertvalue %arg4, %5[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %7 = llvm.insertvalue %arg6, %6[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %8 = llvm.mlir.constant(1 : i32) : i32
    %9 = llvm.mlir.constant(1 : index) : i64
    %10 = llvm.mlir.constant(5 : index) : i64
    %11 = llvm.mlir.constant(1 : index) : i64
    llvm.br ^bb1(%9 : i64)
  ^bb1(%12: i64):  // 2 preds: ^bb0, ^bb5
    %13 = llvm.icmp "slt" %12, %10 : i64
    llvm.cond_br %13, ^bb2, ^bb6
  ^bb2:  // pred: ^bb1
    %14 = llvm.mlir.constant(0 : index) : i64
    %15 = llvm.mlir.constant(4 : index) : i64
    %16 = llvm.mlir.constant(1 : index) : i64
    llvm.br ^bb3(%14 : i64)
  ^bb3(%17: i64):  // 2 preds: ^bb2, ^bb4
    %18 = llvm.icmp "slt" %17, %15 : i64
    llvm.cond_br %18, ^bb4, ^bb5
  ^bb4:  // pred: ^bb3
    %19 = llvm.mlir.constant(-1 : index) : i64
    %20 = llvm.add %12, %19  : i64
    %21 = llvm.mlir.constant(1 : index) : i64
    %22 = llvm.add %17, %21  : i64
    %23 = llvm.extractvalue %7[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %24 = llvm.mlir.constant(5 : index) : i64
    %25 = llvm.mul %20, %24  : i64
    %26 = llvm.add %25, %22  : i64
    %27 = llvm.getelementptr %23[%26] : (!llvm.ptr, i64) -> !llvm.ptr, i32
    %28 = llvm.load %27 : !llvm.ptr -> i32
    %29 = llvm.add %28, %8  : i32
    %30 = llvm.extractvalue %7[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %31 = llvm.mlir.constant(5 : index) : i64
    %32 = llvm.mul %12, %31  : i64
    %33 = llvm.add %32, %17  : i64
    %34 = llvm.getelementptr %30[%33] : (!llvm.ptr, i64) -> !llvm.ptr, i32
    llvm.store %29, %34 : i32, !llvm.ptr
    %35 = llvm.add %17, %16  : i64
    llvm.br ^bb3(%35 : i64)
  ^bb5:  // pred: ^bb3
    %36 = llvm.add %12, %11  : i64
    llvm.br ^bb1(%36 : i64)
  ^bb6:  // pred: ^bb1
    llvm.return
  }
  llvm.func @run() -> i32 {
    %0 = llvm.mlir.constant(5 : index) : i64
    %1 = llvm.mlir.constant(5 : index) : i64
    %2 = llvm.mlir.constant(1 : index) : i64
    %3 = llvm.mlir.constant(25 : index) : i64
    %4 = llvm.mlir.zero : !llvm.ptr
    %5 = llvm.getelementptr %4[25] : (!llvm.ptr) -> !llvm.ptr, i32
    %6 = llvm.ptrtoint %5 : !llvm.ptr to i64
    %7 = llvm.call @malloc(%6) : (i64) -> !llvm.ptr
    %8 = llvm.mlir.undef : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %9 = llvm.insertvalue %7, %8[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %10 = llvm.insertvalue %7, %9[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %11 = llvm.mlir.constant(0 : index) : i64
    %12 = llvm.insertvalue %11, %10[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %13 = llvm.insertvalue %0, %12[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %14 = llvm.insertvalue %1, %13[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %15 = llvm.insertvalue %1, %14[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %16 = llvm.insertvalue %2, %15[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %17 = llvm.mlir.constant(0 : i32) : i32
    %18 = llvm.mlir.constant(0 : index) : i64
    %19 = llvm.mlir.constant(5 : index) : i64
    %20 = llvm.mlir.constant(1 : index) : i64
    llvm.br ^bb1(%18 : i64)
  ^bb1(%21: i64):  // 2 preds: ^bb0, ^bb5
    %22 = llvm.icmp "slt" %21, %19 : i64
    llvm.cond_br %22, ^bb2, ^bb6
  ^bb2:  // pred: ^bb1
    %23 = llvm.mlir.constant(0 : index) : i64
    %24 = llvm.mlir.constant(5 : index) : i64
    %25 = llvm.mlir.constant(1 : index) : i64
    llvm.br ^bb3(%23 : i64)
  ^bb3(%26: i64):  // 2 preds: ^bb2, ^bb4
    %27 = llvm.icmp "slt" %26, %24 : i64
    llvm.cond_br %27, ^bb4, ^bb5
  ^bb4:  // pred: ^bb3
    %28 = llvm.mlir.constant(5 : index) : i64
    %29 = llvm.mul %21, %28  : i64
    %30 = llvm.add %29, %26  : i64
    %31 = llvm.getelementptr %7[%30] : (!llvm.ptr, i64) -> !llvm.ptr, i32
    llvm.store %17, %31 : i32, !llvm.ptr
    %32 = llvm.add %26, %25  : i64
    llvm.br ^bb3(%32 : i64)
  ^bb5:  // pred: ^bb3
    %33 = llvm.add %21, %20  : i64
    llvm.br ^bb1(%33 : i64)
  ^bb6:  // pred: ^bb1
    llvm.call @negative_inner_distance(%7, %7, %11, %0, %1, %1, %2) : (!llvm.ptr, !llvm.ptr, i64, i64, i64, i64, i64) -> ()
    %34 = llvm.mlir.constant(2 : index) : i64
    %35 = llvm.mlir.constant(1 : index) : i64
    %36 = llvm.mlir.constant(5 : index) : i64
    %37 = llvm.mul %34, %36  : i64
    %38 = llvm.add %37, %35  : i64
    %39 = llvm.getelementptr %7[%38] : (!llvm.ptr, i64) -> !llvm.ptr, i32
    %40 = llvm.load %39 : !llvm.ptr -> i32
    llvm.call @free(%7) : (!llvm.ptr) -> ()
    llvm.return %40 : i32
  }
}

