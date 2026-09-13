// blocked 布局。
#AL = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8],
    warpsPerCTA = [4, 1], order = [1, 0]}>
// A 的共享内存布局。
#A_SHARED = #triton_gpu.shared<{vec = 2, perPhase = 2, maxPhase = 4, order = [1, 0]}>
%2 = triton_gpu.local_alloc %1 : (tensor<16x16xf16, #AL>)
    -> !tt.memdesc<16x16xf16, #A_SHARED, #triton_gpu.shared_memory>
