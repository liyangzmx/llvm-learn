#AL = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8],
    warpsPerCTA = [4, 1], order = [1, 0]}>
#C = #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1]}>
#A_DOT = #triton_gpu.dot_op<{opIdx = 0, parent = #C, kWidth = 2}>
%a = triton_gpu.convert_layout %a_ : tensor<128x32xf16, #AL>
    -> tensor<128x32xf16, #A_DOT>
