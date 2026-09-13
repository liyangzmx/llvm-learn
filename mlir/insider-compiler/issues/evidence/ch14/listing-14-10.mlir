func.func @should_fuse_with_slice_union() {
  %a = memref.alloc() : memref<100xf32>
  %c0 = arith.constant 0 : index
  %cf0 = arith.constant 0.0 : f32
  // 示意阶段保留原循环，尚未执行最终删除和缓冲区缩减。
  affine.for %i0 = 0 to 100 {
    affine.store %cf0, %a[%i0] : memref<100xf32>
  }
  affine.for %i1 = 10 to 20 {
    // 覆盖两个读取共同需求的新生产区间。
    affine.for %i3 = 10 to 25 {
      affine.store %cf0, %a[%i3] : memref<100xf32>
    }
    %v0 = affine.load %a[%i1] : memref<100xf32>
    affine.for %i2 = 15 to 25 {
      %v1 = affine.load %a[%i2] : memref<100xf32>
    }
  }
  return
}
