module {
  func.func @conditional() -> i32 {
    %c99_i32 = arith.constant 99 : i32
    %c42_i32 = arith.constant 42 : i32
    %true = arith.constant true
    cf.cond_br %true, ^bb1, ^bb2
  ^bb1:  // pred: ^bb0
    cf.br ^bb3(%c42_i32 : i32)
  ^bb2:  // pred: ^bb0
    cf.br ^bb3(%c99_i32 : i32)
  ^bb3(%0: i32):  // 2 preds: ^bb1, ^bb2
    return %c42_i32 : i32
  }
}

