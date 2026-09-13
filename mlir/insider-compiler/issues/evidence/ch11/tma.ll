; ModuleID = 'LLVMDialectModule'
source_filename = "LLVMDialectModule"

define void @tma_load(ptr %0, ptr addrspace(3) %1, ptr addrspace(3) %2, i32 %3, i32 %4, i32 %5, i32 %6, i16 %7, i16 %8, i16 %9, i64 %10, i1 %11) {
  call void asm sideeffect "cp.async.bulk.tensor.3d.shared::cluster.global.mbarrier::complete_tx::bytes.im2col.multicast::cluster.L2::cache_hint [$0], [$1, {$2,$3,$4} ], [$5],{$6}, $7, $8;", "r,l,r,r,r,r,h,h,l"(ptr addrspace(3) %1, ptr %0, i32 %3, i32 %4, i32 %5, ptr addrspace(3) %2, i16 %7, i16 %9, i64 %10)
  call void asm sideeffect "@$9 cp.async.bulk.tensor.3d.shared::cluster.global.mbarrier::complete_tx::bytes.im2col.multicast::cluster.L2::cache_hint [$0], [$1, {$2,$3,$4} ], [$5],{$6}, $7, $8;", "r,l,r,r,r,r,h,h,l,b"(ptr addrspace(3) %1, ptr %0, i32 %3, i32 %4, i32 %5, ptr addrspace(3) %2, i16 %7, i16 %9, i64 %10, i1 %11)
  ret void
}

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
