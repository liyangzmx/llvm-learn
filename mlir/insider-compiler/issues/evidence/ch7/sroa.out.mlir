module {
  llvm.func @basic_array() -> i32 {
    %0 = llvm.mlir.constant(1 : i32) : i32
    %1 = llvm.alloca %0 x i32 : (i32) -> !llvm.ptr
    %2 = llvm.load %1 : !llvm.ptr -> i32
    llvm.return %2 : i32
  }
}

