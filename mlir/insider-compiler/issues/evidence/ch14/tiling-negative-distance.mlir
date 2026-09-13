// A true dependence from (i,j) to (i+1,j-1), distance (1,-1).
func.func @negative_inner_distance(%a: memref<5x5xi32>) {
  %one = arith.constant 1 : i32
  affine.for %i = 1 to 5 {
    affine.for %j = 0 to 4 {
      %old = affine.load %a[%i - 1, %j + 1] : memref<5x5xi32>
      %new = arith.addi %old, %one : i32
      affine.store %new, %a[%i, %j] : memref<5x5xi32>
    }
  }
  return
}
