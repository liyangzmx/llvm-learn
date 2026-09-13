module {
  func.func @simple_std_for_loop(%arg0: index, %arg1: index, %arg2: index) {
    cf.br ^bb1(%arg0 : index)
  ^bb1(%0: index):  // 2 preds: ^bb0, ^bb2
    %1 = arith.cmpi slt, %0, %arg1 : index
    cf.cond_br %1, ^bb2, ^bb3
  ^bb2:  // pred: ^bb1
    %c1 = arith.constant 1 : index
    %2 = arith.addi %0, %arg2 : index
    cf.br ^bb1(%2 : index)
  ^bb3:  // pred: ^bb1
    return
  }
}
