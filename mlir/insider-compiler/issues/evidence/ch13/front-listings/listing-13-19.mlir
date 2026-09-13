#shared = #triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0],
    hasLeadingOffset = true}>
#mma = #triton_gpu.nvidia_mma<{versionMajor = 3, versionMinor = 0,
    warpsPerCTA = [4, 1], instrShape = [16, 128, 16]}>
%b = triton_gpu.local_alloc %a {allocation.offset = 0 : i32}
    : (tensor<128x128xf16, #mma>)
    -> !tt.memdesc<128x128xf16, #shared, #triton_gpu.shared_memory, mutable>
