module {
  llvm.func @vect() -> !llvm.array<4 x vector<16xf32>> {
    %0 = llvm.mlir.constant(dense<0.000000e+00> : vector<16xf32>) : vector<16xf32>
    %1 = llvm.mlir.constant(dense<0.000000e+00> : vector<4x16xf32>) : !llvm.array<4 x vector<16xf32>>
    %2 = llvm.insertvalue %0, %1[0] : !llvm.array<4 x vector<16xf32>> 
    %3 = llvm.insertvalue %0, %2[1] : !llvm.array<4 x vector<16xf32>> 
    %4 = llvm.insertvalue %0, %3[2] : !llvm.array<4 x vector<16xf32>> 
    %5 = llvm.insertvalue %0, %4[3] : !llvm.array<4 x vector<16xf32>> 
    llvm.return %5 : !llvm.array<4 x vector<16xf32>>
  }
}

