module {
  func.func @simple_loop() {
    %c1 = arith.constant 1 : index
    %c42 = arith.constant 42 : index
    %c1_0 = arith.constant 1 : index
    scf.for %arg0 = %c1 to %c42 step %c1_0 {
      func.call @body(%arg0) : (index) -> ()
    }
    return
  }
  func.func private @body(index)
}

