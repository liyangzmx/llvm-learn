#Cv2 = #triton_gpu.nvidia_mma<{versionMajor = 2, warpsPerCTA = [4, 1]}>
#Av2k1 = #triton_gpu.dot_op<{opIdx = 0, parent = #Cv2, kWidth=1}>
#Bv2k1 = #triton_gpu.dot_op<{opIdx = 1, parent = #Cv2, kWidth=1}>
#Av2k2 = #triton_gpu.dot_op<{opIdx = 0, parent = #Cv2, kWidth=2}>
#Bv2k2 = #triton_gpu.dot_op<{opIdx = 1, parent = #Cv2, kWidth=2}>
#Av2k4 = #triton_gpu.dot_op<{opIdx = 0, parent = #Cv2, kWidth=4}>
#Bv2k4 = #triton_gpu.dot_op<{opIdx = 1, parent = #Cv2, kWidth=4}>
#Cv1 = #triton_gpu.nvidia_mma<{versionMajor = 1, warpsPerCTA = [4, 1]}>
#Av1 = #triton_gpu.dot_op<{opIdx = 0, parent = #Cv1}>
#Bv1 = #triton_gpu.dot_op<{opIdx = 1, parent = #Cv1}>
#ALR = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>
#ALC = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [0, 1]}>
#BLR = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>
#BLC = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [0, 1]}>

module attributes {"triton_gpu.num-warps" = 4 : i32, "triton_gpu.target" = "cuda:80"} {

tt.func @push_elementwise(
                   %pa: tensor<16x16x!tt.ptr<i8>, #ALR> {tt.divisibility=16: i32, tt.contiguity=2 : i32},
                   %pb: tensor<16x16x!tt.ptr<f16>, #BLC> {tt.divisibility=16: i32, tt.contiguity=2 : i32},
                   %c: tensor<16x16xf32, #Cv2>) -> tensor<16x16xf32, #Cv2>{
  %ai8 = tt.load %pa : tensor<16x16x!tt.ptr<i8>, #ALR>
  %b = tt.load %pb : tensor<16x16x!tt.ptr<f16>, #BLC>
  %af8 = tt.bitcast %ai8: tensor<16x16xi8, #ALR> -> tensor<16x16xf8E5M2, #ALR>
  %a = tt.fp_to_fp %af8: tensor<16x16xf8E5M2, #ALR> -> tensor<16x16xf16, #ALR>
  %dota = triton_gpu.convert_layout %a : tensor<16x16xf16, #ALR> -> tensor<16x16xf16, #Av2k4>
  %dotb = triton_gpu.convert_layout %b : tensor<16x16xf16, #BLC> -> tensor<16x16xf16, #Bv2k4>
  %newc = tt.dot %dota, %dotb, %c : tensor<16x16xf16, #Av2k4> * tensor<16x16xf16, #Bv2k4> -> tensor<16x16xf32, #Cv2>
  tt.return %newc : tensor<16x16xf32, #Cv2>
}
}
