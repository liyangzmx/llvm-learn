#map = affine_map<(d0)[s0] -> (10, -d0 + s0)>
#map1 = affine_map<(d0)[s0] -> (20, -d0 + s0)>
#map2 = affine_map<(d0) -> (d0 - 1)>
#map3 = affine_map<()[s0] -> (s0 - 1)>
module {
  func.func @simple_matmul(%arg0: tensor<?x?xf32>, %arg1: tensor<?x?xf32>, %arg2: tensor<?x?xf32>) -> tensor<?x?xf32> {
    %c0 = arith.constant 0 : index
    %dim = tensor.dim %arg0, %c0 : tensor<?x?xf32>
    %c1 = arith.constant 1 : index
    %dim_0 = tensor.dim %arg0, %c1 : tensor<?x?xf32>
    %c0_1 = arith.constant 0 : index
    %dim_2 = tensor.dim %arg1, %c0_1 : tensor<?x?xf32>
    %c1_3 = arith.constant 1 : index
    %dim_4 = tensor.dim %arg1, %c1_3 : tensor<?x?xf32>
    %c0_5 = arith.constant 0 : index
    %dim_6 = tensor.dim %arg2, %c0_5 : tensor<?x?xf32>
    %c1_7 = arith.constant 1 : index
    %dim_8 = tensor.dim %arg2, %c1_7 : tensor<?x?xf32>
    %0 = scf.forall (%arg3, %arg4) = (0, 0) to (%dim, %dim_4) step (10, 20) shared_outs(%arg5 = %arg2) -> (tensor<?x?xf32>) {
      %1 = affine.min #map(%arg3)[%dim]
      %2 = affine.min #map1(%arg4)[%dim_4]
      %3 = affine.apply #map2(%1)
      %4 = affine.apply #map2(%2)
      %5 = affine.apply #map3()[%dim_0]
      %6 = affine.apply #map2(%1)
      %7 = affine.apply #map3()[%dim_0]
      %8 = affine.apply #map3()[%dim_0]
      %9 = affine.apply #map2(%2)
      %10 = affine.apply #map2(%1)
      %11 = affine.apply #map2(%2)
      %extracted_slice = tensor.extract_slice %arg0[%arg3, 0] [%1, %dim_0] [1, 1] : tensor<?x?xf32> to tensor<?x?xf32>
      %extracted_slice_9 = tensor.extract_slice %arg1[0, %arg4] [%dim_0, %2] [1, 1] : tensor<?x?xf32> to tensor<?x?xf32>
      %extracted_slice_10 = tensor.extract_slice %arg5[%arg3, %arg4] [%1, %2] [1, 1] : tensor<?x?xf32> to tensor<?x?xf32>
      %12 = linalg.matmul ins(%extracted_slice, %extracted_slice_9 : tensor<?x?xf32>, tensor<?x?xf32>) outs(%extracted_slice_10 : tensor<?x?xf32>) -> tensor<?x?xf32>
      %13 = affine.apply #map2(%1)
      %14 = affine.apply #map2(%2)
      %15 = affine.apply #map3()[%dim_0]
      %16 = affine.apply #map2(%1)
      %17 = affine.apply #map2(%2)
      scf.forall.in_parallel {
        tensor.parallel_insert_slice %12 into %arg5[%arg3, %arg4] [%1, %2] [1, 1] : tensor<?x?xf32> into tensor<?x?xf32>
      }
    } {mapping = [#gpu.block<y>, #gpu.block<x>]}
    return %0 : tensor<?x?xf32>
  }
  module attributes {transform.with_named_sequence} {
    transform.named_sequence @__transform_main(%arg0: !transform.any_op {transform.readonly}) {
      %0 = transform.structured.match ops{["linalg.matmul"]} in %arg0 : (!transform.any_op) -> !transform.any_op
      %tiled_op, %loops = transform.test.tile_using_forall %0 [10, 20] mapping [#gpu.block<y>, #gpu.block<x>] : (!transform.any_op) -> (!transform.any_op, !transform.any_op)
      transform.yield 
    }
  }
}
