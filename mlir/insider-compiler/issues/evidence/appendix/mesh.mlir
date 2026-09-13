// Reduced from mlir/test/Dialect/Mesh/sharding-propagation.mlir.
mesh.cluster @mesh0(shape = 2x4)

func.func @annotated(%arg0: tensor<8x16xf32>) -> tensor<8x16xf32> {
  %v = tosa.sigmoid %arg0 : (tensor<8x16xf32>) -> tensor<8x16xf32>
  %result = mesh.shard %v to <@mesh0, [[0], [1]]> : tensor<8x16xf32>
  return %result : tensor<8x16xf32>
}

func.func @unannotated(%arg0: tensor<8x16xf32>) -> tensor<8x16xf32> {
  %v = tosa.sigmoid %arg0 : (tensor<8x16xf32>) -> tensor<8x16xf32>
  return %v : tensor<8x16xf32>
}
