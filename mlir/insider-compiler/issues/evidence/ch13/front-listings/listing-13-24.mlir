%12 = triton_gpu.convert_layout %11
    : tensor<1024xf32, #triton_gpu.blocked<{sizePerThread = [8],
        threadsPerWarp = [32], warpsPerCTA = [4], order = [0]}>>
    -> tensor<1024xf32, #triton_gpu.blocked<{sizePerThread = [1],
        threadsPerWarp = [32], warpsPerCTA = [4], order = [0]}>>
