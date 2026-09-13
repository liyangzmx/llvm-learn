module {
  func.func @binary_ops(%arg0: index, %arg1: index) {
    %0 = arith.addi %arg0, %arg1 : index
    %1 = arith.muli %arg0, %arg1 : index
    return
  }
}
