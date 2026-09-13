module {
  func.func @expand_shape(%arg0: memref<?xf32>) -> memref<?x5xf32> {
    %c0 = arith.constant 0 : index
    %dim = memref.dim %arg0, %c0 : memref<?xf32>
    %c5 = arith.constant 5 : index
    %0 = arith.remsi %dim, %c5 : index
    %c0_0 = arith.constant 0 : index
    %1 = arith.cmpi eq, %0, %c0_0 : index
    cf.assert %1, "ERROR: Runtime op verification failed\0A%6 = \22memref.expand_shape\22(%arg0) <{reassociation = [[0, 1]]}> : (memref<?xf32>) -> memref<?x5xf32>\0A^ static result dims in reassoc group do not divide src dim evenly\0ALocation: loc(\22mlir/insider-compiler/issues/evidence/ch7/runtime-verification.mlir\22:2:8)"
    %expand_shape = memref.expand_shape %arg0 [[0, 1]] : memref<?xf32> into memref<?x5xf32>
    return %expand_shape : memref<?x5xf32>
  }
}

