func.func @binary_ops(%lhs: index, %rhs: index) {
  %sum = shape.add %lhs, %rhs : index, index -> index
  %product = shape.mul %lhs, %rhs : index, index -> index
  return
}
