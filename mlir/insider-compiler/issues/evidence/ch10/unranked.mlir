func.func @unranked_rank(%a: memref<*xf32>) -> index {
  %r = memref.rank %a : memref<*xf32>
  return %r : index
}
