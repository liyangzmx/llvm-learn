; ModuleID = 'LLVMDialectModule'
source_filename = "LLVMDialectModule"

@__constant_16x10xf32 = private constant [16 x [10 x float]] [[10 x float] [float -1.000000e+00, float -3.750000e-01, float 2.500000e-01, float 8.750000e-01, float -6.250000e-01, float 0.000000e+00, float 6.250000e-01, float -8.750000e-01, float -2.500000e-01, float 3.750000e-01], [10 x float] [float -6.250000e-01, float 0.000000e+00, float 6.250000e-01, float -8.750000e-01, float -2.500000e-01, float 3.750000e-01, float 1.000000e+00, float -5.000000e-01, float 1.250000e-01, float 7.500000e-01], [10 x float] [float -2.500000e-01, float 3.750000e-01, float 1.000000e+00, float -5.000000e-01, float 1.250000e-01, float 7.500000e-01, float -7.500000e-01, float -1.250000e-01, float 5.000000e-01, float -1.000000e+00], [10 x float] [float 1.250000e-01, float 7.500000e-01, float -7.500000e-01, float -1.250000e-01, float 5.000000e-01, float -1.000000e+00, float -3.750000e-01, float 2.500000e-01, float 8.750000e-01, float -6.250000e-01], [10 x float] [float 5.000000e-01, float -1.000000e+00, float -3.750000e-01, float 2.500000e-01, float 8.750000e-01, float -6.250000e-01, float 0.000000e+00, float 6.250000e-01, float -8.750000e-01, float -2.500000e-01], [10 x float] [float 8.750000e-01, float -6.250000e-01, float 0.000000e+00, float 6.250000e-01, float -8.750000e-01, float -2.500000e-01, float 3.750000e-01, float 1.000000e+00, float -5.000000e-01, float 1.250000e-01], [10 x float] [float -8.750000e-01, float -2.500000e-01, float 3.750000e-01, float 1.000000e+00, float -5.000000e-01, float 1.250000e-01, float 7.500000e-01, float -7.500000e-01, float -1.250000e-01, float 5.000000e-01], [10 x float] [float -5.000000e-01, float 1.250000e-01, float 7.500000e-01, float -7.500000e-01, float -1.250000e-01, float 5.000000e-01, float -1.000000e+00, float -3.750000e-01, float 2.500000e-01, float 8.750000e-01], [10 x float] [float -1.250000e-01, float 5.000000e-01, float -1.000000e+00, float -3.750000e-01, float 2.500000e-01, float 8.750000e-01, float -6.250000e-01, float 0.000000e+00, float 6.250000e-01, float -8.750000e-01], [10 x float] [float 2.500000e-01, float 8.750000e-01, float -6.250000e-01, float 0.000000e+00, float 6.250000e-01, float -8.750000e-01, float -2.500000e-01, float 3.750000e-01, float 1.000000e+00, float -5.000000e-01], [10 x float] [float 6.250000e-01, float -8.750000e-01, float -2.500000e-01, float 3.750000e-01, float 1.000000e+00, float -5.000000e-01, float 1.250000e-01, float 7.500000e-01, float -7.500000e-01, float -1.250000e-01], [10 x float] [float 1.000000e+00, float -5.000000e-01, float 1.250000e-01, float 7.500000e-01, float -7.500000e-01, float -1.250000e-01, float 5.000000e-01, float -1.000000e+00, float -3.750000e-01, float 2.500000e-01], [10 x float] [float -7.500000e-01, float -1.250000e-01, float 5.000000e-01, float -1.000000e+00, float -3.750000e-01, float 2.500000e-01, float 8.750000e-01, float -6.250000e-01, float 0.000000e+00, float 6.250000e-01], [10 x float] [float -3.750000e-01, float 2.500000e-01, float 8.750000e-01, float -6.250000e-01, float 0.000000e+00, float 6.250000e-01, float -8.750000e-01, float -2.500000e-01, float 3.750000e-01, float 1.000000e+00], [10 x float] [float 0.000000e+00, float 6.250000e-01, float -8.750000e-01, float -2.500000e-01, float 3.750000e-01, float 1.000000e+00, float -5.000000e-01, float 1.250000e-01, float 7.500000e-01, float -7.500000e-01], [10 x float] [float 3.750000e-01, float 1.000000e+00, float -5.000000e-01, float 1.250000e-01, float 7.500000e-01, float -7.500000e-01, float -1.250000e-01, float 5.000000e-01, float -1.000000e+00, float -3.750000e-01]]
@__constant_1x10xf32 = private constant [1 x [10 x float]] [[10 x float] [float -1.000000e+00, float -7.500000e-01, float -5.000000e-01, float -2.500000e-01, float 0.000000e+00, float 2.500000e-01, float 5.000000e-01, float 7.500000e-01, float 1.000000e+00, float 1.250000e+00]]

define void @forward(ptr %0, ptr %1, i64 %2, i64 %3, i64 %4, i64 %5, i64 %6, ptr %7, ptr %8, i64 %9, i64 %10, i64 %11, i64 %12, i64 %13) {
  %15 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } undef, ptr %0, 0
  %16 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %15, ptr %1, 1
  %17 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %16, i64 %2, 2
  %18 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %17, i64 %3, 3, 0
  %19 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %18, i64 %5, 4, 0
  %20 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %19, i64 %4, 3, 1
  %21 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %20, i64 %6, 4, 1
  %22 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } undef, ptr %7, 0
  %23 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %22, ptr %8, 1
  %24 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %23, i64 %9, 2
  %25 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %24, i64 %10, 3, 0
  %26 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %25, i64 %12, 4, 0
  %27 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %26, i64 %11, 3, 1
  %28 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %27, i64 %13, 4, 1
  %29 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %28, 1
  %30 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %28, 2
  %31 = getelementptr float, ptr %29, i64 %30
  call void @llvm.memcpy.p0.p0.i64(ptr %31, ptr @__constant_1x10xf32, i64 mul (i64 ptrtoint (ptr getelementptr (float, ptr null, i32 1) to i64), i64 10), i1 false)
  br label %32

32:                                               ; preds = %58, %14
  %33 = phi i64 [ %59, %58 ], [ 0, %14 ]
  %34 = icmp slt i64 %33, 10
  br i1 %34, label %35, label %60

35:                                               ; preds = %32
  br label %36

36:                                               ; preds = %39, %35
  %37 = phi i64 [ %57, %39 ], [ 0, %35 ]
  %38 = icmp slt i64 %37, 16
  br i1 %38, label %39, label %58

39:                                               ; preds = %36
  %40 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %21, 1
  %41 = add i64 0, %37
  %42 = getelementptr float, ptr %40, i64 %41
  %43 = load float, ptr %42, align 4
  %44 = mul i64 %37, 10
  %45 = add i64 %44, %33
  %46 = getelementptr float, ptr @__constant_16x10xf32, i64 %45
  %47 = load float, ptr %46, align 4
  %48 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %28, 1
  %49 = add i64 0, %33
  %50 = getelementptr float, ptr %48, i64 %49
  %51 = load float, ptr %50, align 4
  %52 = fmul float %43, %47
  %53 = fadd float %51, %52
  %54 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %28, 1
  %55 = add i64 0, %33
  %56 = getelementptr float, ptr %54, i64 %55
  store float %53, ptr %56, align 4
  %57 = add i64 %37, 1
  br label %36

58:                                               ; preds = %36
  %59 = add i64 %33, 1
  br label %32

60:                                               ; preds = %32
  ret void
}

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i64(ptr noalias nocapture writeonly, ptr noalias nocapture readonly, i64, i1 immarg) #0

attributes #0 = { nocallback nofree nounwind willreturn memory(argmem: readwrite) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
