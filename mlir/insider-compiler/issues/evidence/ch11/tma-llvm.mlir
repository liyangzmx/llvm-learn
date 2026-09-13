module {
  llvm.func @tma_load(%arg0: !llvm.ptr, %arg1: !llvm.ptr<3>, %arg2: !llvm.ptr<3>, %arg3: i32, %arg4: i32, %arg5: i32, %arg6: i32, %arg7: i16, %arg8: i16, %arg9: i16, %arg10: i64, %arg11: i1) {
    llvm.inline_asm has_side_effects asm_dialect = att "cp.async.bulk.tensor.3d.shared::cluster.global.mbarrier::complete_tx::bytes.im2col.multicast::cluster.L2::cache_hint [$0], [$1, {$2,$3,$4} ], [$5],{$6}, $7, $8;", "r,l,r,r,r,r,h,h,l" %arg1, %arg0, %arg3, %arg4, %arg5, %arg2, %arg7, %arg9, %arg10 : (!llvm.ptr<3>, !llvm.ptr, i32, i32, i32, !llvm.ptr<3>, i16, i16, i64) -> ()
    llvm.inline_asm has_side_effects asm_dialect = att "@$9 cp.async.bulk.tensor.3d.shared::cluster.global.mbarrier::complete_tx::bytes.im2col.multicast::cluster.L2::cache_hint [$0], [$1, {$2,$3,$4} ], [$5],{$6}, $7, $8;", "r,l,r,r,r,r,h,h,l,b" %arg1, %arg0, %arg3, %arg4, %arg5, %arg2, %arg7, %arg9, %arg10, %arg11 : (!llvm.ptr<3>, !llvm.ptr, i32, i32, i32, !llvm.ptr<3>, i16, i16, i64, i1) -> ()
    llvm.return
  }
}

