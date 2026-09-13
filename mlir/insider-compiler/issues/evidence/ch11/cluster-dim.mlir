gpu.module @device {
  gpu.func @read_cluster_dim() -> index {
    %dim = gpu.cluster_dim x
    gpu.return %dim : index
  }
}
