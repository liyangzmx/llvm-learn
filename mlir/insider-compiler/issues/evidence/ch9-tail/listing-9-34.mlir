func.func @vect() -> vector<4x16xf32> {
  %cst = arith.constant dense<0.000000e+00> : vector<16xf32>
  %cst_0 = arith.constant dense<0.000000e+00> : vector<4x16xf32>
  %0 = builtin.unrealized_conversion_cast %cst_0
      : vector<4x16xf32> to !llvm.array<4 x vector<16xf32>>
  %1 = llvm.insertvalue %cst, %0[0] : !llvm.array<4 x vector<16xf32>>
  %2 = llvm.insertvalue %cst, %1[1] : !llvm.array<4 x vector<16xf32>>
  %3 = llvm.insertvalue %cst, %2[2] : !llvm.array<4 x vector<16xf32>>
  %4 = llvm.insertvalue %cst, %3[3] : !llvm.array<4 x vector<16xf32>>
  %5 = builtin.unrealized_conversion_cast %4
      : !llvm.array<4 x vector<16xf32>> to vector<4x16xf32>
  return %5 : vector<4x16xf32>
}
