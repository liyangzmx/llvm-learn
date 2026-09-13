module {
  func.func @arm_sme_load_tile(%arg0: memref<?x?xf16>, %arg1: vector<[8]xi1>,
                              %arg2: index) attributes {arm_sme.tiles_in_use = 43690 : i32} {
    %c0 = arith.constant 0 : index
    %0 = builtin.unrealized_conversion_cast %arg0 : memref<?x?xf16>
        to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %1 = builtin.unrealized_conversion_cast %c0 : index to i64
    %2 = arm_sme.materialize_ssa_tile : vector<[8]x[8]xf16>
    %3 = llvm.extractvalue %0[1]
        : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %4 = llvm.extractvalue %0[4, 0]
        : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %5 = llvm.mul %1, %4 : i64
    %6 = llvm.getelementptr %3[%5] : (!llvm.ptr, i64) -> !llvm.ptr, f16
    %7 = arith.index_castui %arg2 : index to i32
    "arm_sme.intr.ld1h.horiz"(%arg1, %6, %7) <{tile_id = 0 : i32}>
        : (vector<[8]xi1>, !llvm.ptr, i32) -> ()
    "test.some_use"(%2) : (vector<[8]x[8]xf16>) -> ()
    return
  }
}
