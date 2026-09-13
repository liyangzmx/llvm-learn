%9 = triton_gpu.convert_layout %8
    : tensor<1024x!tt.ptr<f32>, #triton_gpu.blocked<{sizePerThread = [1],
        threadsPerWarp = [32], warpsPerCTA = [4], order = [0]}>>
    -> tensor<1024x!tt.ptr<f32>, #triton_gpu.blocked<{sizePerThread = [8],
        threadsPerWarp = [32], warpsPerCTA = [4], order = [0]}>>
%10 = triton_gpu.convert_layout %6
    : tensor<1024xi1, #triton_gpu.blocked<{sizePerThread = [1],
        threadsPerWarp = [32], warpsPerCTA = [4], order = [0]}>>
    -> tensor<1024xi1, #triton_gpu.blocked<{sizePerThread = [8],
        threadsPerWarp = [32], warpsPerCTA = [4], order = [0]}>>
%11 = tt.load %9, %10
    : tensor<1024x!tt.ptr<f32>, #triton_gpu.blocked<{sizePerThread = [8],
        threadsPerWarp = [32], warpsPerCTA = [4], order = [0]}>>
