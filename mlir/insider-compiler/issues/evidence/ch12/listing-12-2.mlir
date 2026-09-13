module {
  func.func @basic_cast_and_call() {
    // 与变换前相比，此处增加了 second 函数调用。
    call @second() : () -> ()
    "test.foo"() : () -> ()
    // 与变换前相比，此处增加了 third 函数调用。
    call @third() : () -> ()
    return
  }
  func.func @second() {
    "test.bar"() : () -> ()
    return
  }
  func.func private @third()
  module attributes {transform.with_named_sequence} {
    transform.named_sequence @__transform_main(%arg0: !transform.any_op) {
      %0 = transform.structured.match ops{["func.func"]} in %arg0
        : (!transform.any_op) -> !transform.any_op
      %1:3 = transform.split_handle %0
        : (!transform.any_op) ->
          (!transform.any_op, !transform.any_op, !transform.any_op)
      %2 = transform.structured.match ops{["test.foo"]} in %1#0
        : (!transform.any_op) -> !transform.any_op
      %3 = transform.func.cast_and_call @second before %2
        : (!transform.any_op) -> !transform.any_op
      %4 = transform.func.cast_and_call %1#2 after %2
        : (!transform.any_op, !transform.any_op) -> !transform.any_op
      transform.yield
    }
  }
}
