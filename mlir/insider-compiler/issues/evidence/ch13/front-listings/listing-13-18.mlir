#blocked = #triton_gpu.blocked<{sizePerThread = [1, 1], threadsPerWarp = [32, 1],
    warpsPerCTA = [1, 4], order = [0, 1]}>
#mma = #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [2, 2]}>
%13 = triton_gpu.convert_layout %12 : tensor<32x32xf32, #mma>
    -> tensor<32x32xf32, #blocked>
