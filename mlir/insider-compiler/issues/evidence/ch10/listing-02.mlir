module {
  // func 方言中的 func 操作降级为 llvm 方言中的 func 操作。
  llvm.func @my() {
    llvm.return
  }
}
