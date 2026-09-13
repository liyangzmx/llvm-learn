func.func @simple_loop() {
  affine.for %i = 1 to 42 {
    func.call @body(%i) : (index) -> ()
  }
  return
}
func.func private @body(index) -> ()
