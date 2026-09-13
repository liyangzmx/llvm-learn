module {
  func.func @f() -> i1 {
    %a = arith.constant true
    return %a : i1
  }
}
