func.func @constraints(%a: tensor<1xindex>, %b: tensor<1xindex>, %condition: i1) -> (!shape.witness, !shape.witness) {
  %w = shape.cstr_eq %a, %b : tensor<1xindex>, tensor<1xindex>
  %r = shape.cstr_require %condition, "required condition"
  return %w, %r : !shape.witness, !shape.witness
}
