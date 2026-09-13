module {
  func.func @log1p(%arg0: f32) -> f32 {
    %0 = llvm.mlir.constant(1.000000e+00 : f32) : f32
    %1 = llvm.fadd %0, %arg0 : f32
    // LLVM 方言提供 log 内建操作，可继续交由目标后端处理。
    // 对没有直接内建表示的功能，则需要组合其他操作或采用库调用。
    %2 = llvm.intr.log(%1) : (f32) -> f32
    return %2 : f32
  }
}
