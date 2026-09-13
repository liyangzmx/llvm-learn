#blocked = #triton_gpu.blocked<{sizePerThread = [1], threadsPerWarp = [32],
    warpsPerCTA = [4], order = [0]}>
#shared = #triton_gpu.shared<{vec = 1, perPhase = 1, maxPhase = 1, order = [0],
    hasLeadingOffset = false}>
triton_gpu.local_store %arg0, %0 : tensor<1xf32, #blocked>
    -> !tt.memdesc<1xf32, #shared, #triton_gpu.shared_memory, mutable>
