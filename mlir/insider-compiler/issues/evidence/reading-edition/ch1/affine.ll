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
  br label %29

29:                                               ; preds = %58, %14
  %30 = phi i64 [ %70, %58 ], [ 0, %14 ]
  %31 = icmp slt i64 %30, 10
  br i1 %31, label %32, label %71

32:                                               ; preds = %29
  %33 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %28, 1
  %34 = add i64 0, %30
  %35 = getelementptr float, ptr %33, i64 %34
  store float 0.000000e+00, ptr %35, align 4
  br label %36

36:                                               ; preds = %39, %32
  %37 = phi i64 [ %57, %39 ], [ 0, %32 ]
  %38 = icmp slt i64 %37, 16
  br i1 %38, label %39, label %58

39:                                               ; preds = %36
  %40 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %21, 1
  %41 = add i64 0, %37
  %42 = getelementptr float, ptr %40, i64 %41
  %43 = load float, ptr %42, align 4
  %44 = mul i64 %37, 10
  %45 = add i64 %44, %30
  %46 = getelementptr float, ptr @__constant_16x10xf32, i64 %45
  %47 = load float, ptr %46, align 4
  %48 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %28, 1
  %49 = add i64 0, %30
  %50 = getelementptr float, ptr %48, i64 %49
  %51 = load float, ptr %50, align 4
  %52 = fmul float %43, %47
  %53 = fadd float %51, %52
  %54 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %28, 1
  %55 = add i64 0, %30
  %56 = getelementptr float, ptr %54, i64 %55
  store float %53, ptr %56, align 4
  %57 = add i64 %37, 1
  br label %36

58:                                               ; preds = %36
  %59 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %28, 1
  %60 = add i64 0, %30
  %61 = getelementptr float, ptr %59, i64 %60
  %62 = load float, ptr %61, align 4
  %63 = add i64 0, %30
  %64 = getelementptr float, ptr @__constant_1x10xf32, i64 %63
  %65 = load float, ptr %64, align 4
  %66 = fadd float %62, %65
  %67 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %28, 1
  %68 = add i64 0, %30
  %69 = getelementptr float, ptr %67, i64 %68
  store float %66, ptr %69, align 4
  %70 = add i64 %30, 1
  br label %29

71:                                               ; preds = %29
  ret void
}

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
