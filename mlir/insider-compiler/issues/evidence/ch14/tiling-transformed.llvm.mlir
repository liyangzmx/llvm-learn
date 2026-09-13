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
    %11 = llvm.mlir.constant(2 : index) : i64
    llvm.br ^bb1(%9 : i64)
  ^bb1(%12: i64):  // 2 preds: ^bb0, ^bb11
    %13 = llvm.icmp "slt" %12, %10 : i64
    llvm.cond_br %13, ^bb2, ^bb12
  ^bb2:  // pred: ^bb1
    %14 = llvm.mlir.constant(0 : index) : i64
    %15 = llvm.mlir.constant(4 : index) : i64
    %16 = llvm.mlir.constant(2 : index) : i64
    llvm.br ^bb3(%14 : i64)
  ^bb3(%17: i64):  // 2 preds: ^bb2, ^bb10
    %18 = llvm.icmp "slt" %17, %15 : i64
    llvm.cond_br %18, ^bb4, ^bb11
  ^bb4:  // pred: ^bb3
    %19 = llvm.mlir.constant(2 : index) : i64
    %20 = llvm.add %12, %19  : i64
    %21 = llvm.mlir.constant(1 : index) : i64
    llvm.br ^bb5(%12 : i64)
  ^bb5(%22: i64):  // 2 preds: ^bb4, ^bb9
    %23 = llvm.icmp "slt" %22, %20 : i64
    llvm.cond_br %23, ^bb6, ^bb10
  ^bb6:  // pred: ^bb5
    %24 = llvm.mlir.constant(2 : index) : i64
    %25 = llvm.add %17, %24  : i64
    %26 = llvm.mlir.constant(1 : index) : i64
    llvm.br ^bb7(%17 : i64)
  ^bb7(%27: i64):  // 2 preds: ^bb6, ^bb8
    %28 = llvm.icmp "slt" %27, %25 : i64
    llvm.cond_br %28, ^bb8, ^bb9
  ^bb8:  // pred: ^bb7
    %29 = llvm.mlir.constant(-1 : index) : i64
    %30 = llvm.add %22, %29  : i64
    %31 = llvm.mlir.constant(1 : index) : i64
    %32 = llvm.add %27, %31  : i64
    %33 = llvm.extractvalue %7[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %34 = llvm.mlir.constant(5 : index) : i64
    %35 = llvm.mul %30, %34  : i64
    %36 = llvm.add %35, %32  : i64
    %37 = llvm.getelementptr %33[%36] : (!llvm.ptr, i64) -> !llvm.ptr, i32
    %38 = llvm.load %37 : !llvm.ptr -> i32
    %39 = llvm.add %38, %8  : i32
    %40 = llvm.extractvalue %7[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %41 = llvm.mlir.constant(5 : index) : i64
    %42 = llvm.mul %22, %41  : i64
    %43 = llvm.add %42, %27  : i64
    %44 = llvm.getelementptr %40[%43] : (!llvm.ptr, i64) -> !llvm.ptr, i32
    llvm.store %39, %44 : i32, !llvm.ptr
    %45 = llvm.add %27, %26  : i64
    llvm.br ^bb7(%45 : i64)
  ^bb9:  // pred: ^bb7
    %46 = llvm.add %22, %21  : i64
    llvm.br ^bb5(%46 : i64)
  ^bb10:  // pred: ^bb5
    %47 = llvm.add %17, %16  : i64
    llvm.br ^bb3(%47 : i64)
  ^bb11:  // pred: ^bb3
    %48 = llvm.add %12, %11  : i64
    llvm.br ^bb1(%48 : i64)
  ^bb12:  // pred: ^bb1
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
    %20 = llvm.mlir.constant(2 : index) : i64
    llvm.br ^bb1(%18 : i64)
  ^bb1(%21: i64):  // 2 preds: ^bb0, ^bb11
    %22 = llvm.icmp "slt" %21, %19 : i64
    llvm.cond_br %22, ^bb2, ^bb12
  ^bb2:  // pred: ^bb1
    %23 = llvm.mlir.constant(0 : index) : i64
    %24 = llvm.mlir.constant(5 : index) : i64
    %25 = llvm.mlir.constant(2 : index) : i64
    llvm.br ^bb3(%23 : i64)
  ^bb3(%26: i64):  // 2 preds: ^bb2, ^bb10
    %27 = llvm.icmp "slt" %26, %24 : i64
    llvm.cond_br %27, ^bb4, ^bb11
  ^bb4:  // pred: ^bb3
    %28 = llvm.mlir.constant(2 : index) : i64
    %29 = llvm.add %21, %28  : i64
    %30 = llvm.mlir.constant(5 : index) : i64
    %31 = llvm.icmp "slt" %29, %30 : i64
    %32 = llvm.select %31, %29, %30 : i1, i64
    %33 = llvm.mlir.constant(1 : index) : i64
    llvm.br ^bb5(%21 : i64)
  ^bb5(%34: i64):  // 2 preds: ^bb4, ^bb9
    %35 = llvm.icmp "slt" %34, %32 : i64
    llvm.cond_br %35, ^bb6, ^bb10
  ^bb6:  // pred: ^bb5
    %36 = llvm.mlir.constant(2 : index) : i64
    %37 = llvm.add %26, %36  : i64
    %38 = llvm.mlir.constant(5 : index) : i64
    %39 = llvm.icmp "slt" %37, %38 : i64
    %40 = llvm.select %39, %37, %38 : i1, i64
    %41 = llvm.mlir.constant(1 : index) : i64
    llvm.br ^bb7(%26 : i64)
  ^bb7(%42: i64):  // 2 preds: ^bb6, ^bb8
    %43 = llvm.icmp "slt" %42, %40 : i64
    llvm.cond_br %43, ^bb8, ^bb9
  ^bb8:  // pred: ^bb7
    %44 = llvm.mlir.constant(5 : index) : i64
    %45 = llvm.mul %34, %44  : i64
    %46 = llvm.add %45, %42  : i64
    %47 = llvm.getelementptr %7[%46] : (!llvm.ptr, i64) -> !llvm.ptr, i32
    llvm.store %17, %47 : i32, !llvm.ptr
    %48 = llvm.add %42, %41  : i64
    llvm.br ^bb7(%48 : i64)
  ^bb9:  // pred: ^bb7
    %49 = llvm.add %34, %33  : i64
    llvm.br ^bb5(%49 : i64)
  ^bb10:  // pred: ^bb5
    %50 = llvm.add %26, %25  : i64
    llvm.br ^bb3(%50 : i64)
  ^bb11:  // pred: ^bb3
    %51 = llvm.add %21, %20  : i64
    llvm.br ^bb1(%51 : i64)
  ^bb12:  // pred: ^bb1
    llvm.call @negative_inner_distance(%7, %7, %11, %0, %1, %1, %2) : (!llvm.ptr, !llvm.ptr, i64, i64, i64, i64, i64) -> ()
    %52 = llvm.mlir.constant(2 : index) : i64
    %53 = llvm.mlir.constant(1 : index) : i64
    %54 = llvm.mlir.constant(5 : index) : i64
    %55 = llvm.mul %52, %54  : i64
    %56 = llvm.add %55, %53  : i64
    %57 = llvm.getelementptr %7[%56] : (!llvm.ptr, i64) -> !llvm.ptr, i32
    %58 = llvm.load %57 : !llvm.ptr -> i32
    llvm.call @free(%7) : (!llvm.ptr) -> ()
    llvm.return %58 : i32
  }
}

