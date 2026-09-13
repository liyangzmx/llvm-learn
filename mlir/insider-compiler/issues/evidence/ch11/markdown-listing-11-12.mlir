module {
  func.func @nvgpu_matmul(%arg0: vector<4x2xf16>, %arg1: vector<2x2xf16>, %arg2: vector<2x2xf16>) -> vector<2x2xf16> {
    %0 = builtin.unrealized_conversion_cast %arg0 : vector<4x2xf16> to !llvm.array<4 x vector<2xf16>>
    %1 = builtin.unrealized_conversion_cast %arg1 : vector<2x2xf16> to !llvm.array<2 x vector<2xf16>>
    %2 = builtin.unrealized_conversion_cast %arg2 : vector<2x2xf16> to !llvm.array<2 x vector<2xf16>>
    %3 = llvm.extractvalue %0[0] : !llvm.array<4 x vector<2xf16>> 
    %4 = llvm.extractvalue %0[1] : !llvm.array<4 x vector<2xf16>> 
    %5 = llvm.extractvalue %0[2] : !llvm.array<4 x vector<2xf16>> 
    %6 = llvm.extractvalue %0[3] : !llvm.array<4 x vector<2xf16>> 
    %7 = llvm.extractvalue %1[0] : !llvm.array<2 x vector<2xf16>> 
    %8 = llvm.extractvalue %1[1] : !llvm.array<2 x vector<2xf16>> 
    %9 = llvm.extractvalue %2[0] : !llvm.array<2 x vector<2xf16>> 
    %10 = llvm.extractvalue %2[1] : !llvm.array<2 x vector<2xf16>> 
    %11 = nvvm.mma.sync A[%3, %4, %5, %6]  B[%7, %8]  C[%9, %10]  {layoutA = #nvvm.mma_layout<row>, layoutB = #nvvm.mma_layout<col>, shape = #nvvm.shape<m = 16, n = 8, k = 16>} : (vector<2xf16>, vector<2xf16>, vector<2xf16>) -> !llvm.struct<(vector<2xf16>, vector<2xf16>)>
    %12 = llvm.extractvalue %11[0] : !llvm.struct<(vector<2xf16>, vector<2xf16>)> 
    %13 = llvm.extractvalue %11[1] : !llvm.struct<(vector<2xf16>, vector<2xf16>)> 
    %14 = llvm.mlir.undef : !llvm.array<2 x vector<2xf16>>
    %15 = llvm.insertvalue %12, %14[0] : !llvm.array<2 x vector<2xf16>> 
    %16 = llvm.insertvalue %13, %15[1] : !llvm.array<2 x vector<2xf16>> 
    %17 = builtin.unrealized_conversion_cast %16 : !llvm.array<2 x vector<2xf16>> to vector<2x2xf16>
    return %17 : vector<2x2xf16>
  }
}
