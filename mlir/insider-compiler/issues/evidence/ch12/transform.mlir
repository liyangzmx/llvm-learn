func.func @basic_cast_and_call() {
  "test.foo"() : () -> ()
  func.return
}
func.func @second() {
  "test.bar"() : () -> ()
  func.return
}
func.func private @third()
module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%arg0: !transform.any_op) {
    %funcs = transform.structured.match ops{["func.func"]} in %arg0 : (!transform.any_op) -> !transform.any_op
    %f:3 = transform.split_handle %funcs : (!transform.any_op) -> (!transform.any_op, !transform.any_op, !transform.any_op)
    %foo = transform.structured.match ops{["test.foo"]} in %f#0 : (!transform.any_op) -> !transform.any_op
    transform.func.cast_and_call @second before %foo : (!transform.any_op) -> !transform.any_op
    transform.func.cast_and_call %f#2 after %foo : (!transform.any_op, !transform.any_op) -> !transform.any_op
    transform.yield
  }
}
