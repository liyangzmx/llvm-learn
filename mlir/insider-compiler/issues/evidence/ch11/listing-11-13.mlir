func.func @tma_load(%tmaDescriptor: !llvm.ptr, %dest: !llvm.ptr<3>, %barrier: !llvm.ptr<3>, %crd0: i32, %crd1: i32, %crd2: i32, %crd3: i32, %off0: i16, %off1: i16, %ctamask: i16, %cacheHint: i64, %p: i1) {
  nvvm.cp.async.bulk.tensor.shared.cluster.global %dest, %tmaDescriptor, %barrier, box[%crd0, %crd1, %crd2] im2col[%off0] multicast_mask = %ctamask l2_cache_hint = %cacheHint : !llvm.ptr<3>, !llvm.ptr
  nvvm.cp.async.bulk.tensor.shared.cluster.global %dest, %tmaDescriptor, %barrier, box[%crd0, %crd1, %crd2] im2col[%off0] multicast_mask = %ctamask l2_cache_hint = %cacheHint predicate = %p : !llvm.ptr<3>, !llvm.ptr
  return
}
