#A = #triton_gpu.shared<{vec = 2, perPhase = 2, maxPhase = 4, order = [1, 0]}>
#C = #triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1]}>
#A_OP = #triton_gpu.dot_op<{opIdx = 0, parent = #C, kWidth = 2}>
%a_op_ = triton_gpu.local_load %a
    : !tt.memdesc<128x16xf8E5M2, #A, #triton_gpu.shared_memory>
    -> tensor<128x16xf8E5M2, #A_OP>
