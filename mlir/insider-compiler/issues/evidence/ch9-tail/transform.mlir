module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%arg0: !transform.any_op {transform.readonly}) {
    %0 = transform.structured.match ops{["linalg.matmul"]} in %arg0 : (!transform.any_op) -> !transform.any_op
    %tiled_linalg_op, %loops:3 = transform.structured.tile_using_for %0 [8, [16], 1] : (!transform.any_op) -> (!transform.any_op, !transform.op<"scf.for">, !transform.op<"scf.for">, !transform.op<"scf.for">)
    %1 = transform.structured.match ops{["linalg.matmul"]} in %tiled_linalg_op : (!transform.any_op) -> !transform.any_op
    transform.structured.vectorize %1 vector_sizes [8, [16], 1] : !transform.any_op
    transform.yield
  }
}
