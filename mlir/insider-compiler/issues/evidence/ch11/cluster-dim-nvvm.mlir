module {
  gpu.module @device {
    llvm.func @read_cluster_dim() -> i64 {
      %0 = nvvm.read.ptx.sreg.nclusterid.x : i32
      %1 = llvm.sext %0 : i32 to i64
      llvm.return %1 : i64
    }
  }
}

