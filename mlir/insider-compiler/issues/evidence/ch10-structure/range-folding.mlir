// The original writes indices 2, 4, 6. A correct multiplication folding must
// change all three loop bounds: lower 1 -> 2, upper 4 -> 8, step 1 -> 2.
func.func @nonzero_lower_bound(%out: memref<10xindex>) {
  %c1 = arith.constant 1 : index
  %c2 = arith.constant 2 : index
  %c4 = arith.constant 4 : index
  scf.for %i = %c1 to %c4 step %c1 {
    %j = arith.muli %i, %c2 : index
    memref.store %j, %out[%j] : memref<10xindex>
  }
  return
}
