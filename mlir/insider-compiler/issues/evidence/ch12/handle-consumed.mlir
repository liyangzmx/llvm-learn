func.func @f() { return }
module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%arg0: !transform.any_op) {
    %func = transform.structured.match ops{["func.func"]} in %arg0 : (!transform.any_op) -> !transform.any_op
    %alias = transform.cast %func : !transform.any_op to !transform.any_op
    transform.print %func : !transform.any_op
    %new = transform.apply_registered_pass "canonicalize" to %func : (!transform.any_op) -> !transform.any_op
    transform.print %alias : !transform.any_op
    transform.yield
  }
}
