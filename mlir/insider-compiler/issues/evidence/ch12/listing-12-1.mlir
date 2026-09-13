// 负载 IR，共计 3 个函数。
func.func @basic_cast_and_call() {
  "test.foo"() : () -> ()
  func.return
}

func.func @second() {
  "test.bar"() : () -> ()
  func.return
}

func.func private @third()

// 变换 IR，入口为 __transform_main。
module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%arg0: !transform.any_op) {
    // 在 %arg0 中查找所有 func.func，得到 3 个函数定义或声明。
    %funcs = transform.structured.match ops{["func.func"]} in %arg0
      : (!transform.any_op) -> !transform.any_op
    // 将查找结果拆分为 3 个具体函数，对应 %f#0、%f#1、%f#2。
    %f:3 = transform.split_handle %funcs
      : (!transform.any_op) ->
        (!transform.any_op, !transform.any_op, !transform.any_op)
    // 在 %f#0 中查找 test.foo 操作。
    %foo = transform.structured.match ops{["test.foo"]} in %f#0
      : (!transform.any_op) -> !transform.any_op
    // 在查找位置之前插入 second 函数调用；该变换返回调用的句柄。
    transform.func.cast_and_call @second before %foo
      : (!transform.any_op) -> !transform.any_op
    // 在查找位置之后插入 %f#2（即 third）的调用。
    transform.func.cast_and_call %f#2 after %foo
      : (!transform.any_op, !transform.any_op) -> !transform.any_op
    // 完成变换序列。
    transform.yield
  }
}
