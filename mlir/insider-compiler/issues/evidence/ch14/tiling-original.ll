; ModuleID = 'LLVMDialectModule'
source_filename = "LLVMDialectModule"

declare void @free(ptr)

declare ptr @malloc(i64)

define void @negative_inner_distance(ptr %0, ptr %1, i64 %2, i64 %3, i64 %4, i64 %5, i64 %6) {
  %8 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } undef, ptr %0, 0
  %9 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %8, ptr %1, 1
  %10 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %9, i64 %2, 2
  %11 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %10, i64 %3, 3, 0
  %12 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %11, i64 %5, 4, 0
  %13 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %12, i64 %4, 3, 1
  %14 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %13, i64 %6, 4, 1
  br label %15

15:                                               ; preds = %36, %7
  %16 = phi i64 [ %37, %36 ], [ 1, %7 ]
  %17 = icmp slt i64 %16, 5
  br i1 %17, label %18, label %38

18:                                               ; preds = %15
  br label %19

19:                                               ; preds = %22, %18
  %20 = phi i64 [ %35, %22 ], [ 0, %18 ]
  %21 = icmp slt i64 %20, 4
  br i1 %21, label %22, label %36

22:                                               ; preds = %19
  %23 = add i64 %16, -1
  %24 = add i64 %20, 1
  %25 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %14, 1
  %26 = mul i64 %23, 5
  %27 = add i64 %26, %24
  %28 = getelementptr i32, ptr %25, i64 %27
  %29 = load i32, ptr %28, align 4
  %30 = add i32 %29, 1
  %31 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %14, 1
  %32 = mul i64 %16, 5
  %33 = add i64 %32, %20
  %34 = getelementptr i32, ptr %31, i64 %33
  store i32 %30, ptr %34, align 4
  %35 = add i64 %20, 1
  br label %19

36:                                               ; preds = %19
  %37 = add i64 %16, 1
  br label %15

38:                                               ; preds = %15
  ret void
}

define i32 @run() {
  %1 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (i32, ptr null, i32 25) to i64))
  %2 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } undef, ptr %1, 0
  %3 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %2, ptr %1, 1
  %4 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %3, i64 0, 2
  %5 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %4, i64 5, 3, 0
  %6 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %5, i64 5, 3, 1
  %7 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %6, i64 5, 4, 0
  %8 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %7, i64 1, 4, 1
  br label %9

9:                                                ; preds = %21, %0
  %10 = phi i64 [ %22, %21 ], [ 0, %0 ]
  %11 = icmp slt i64 %10, 5
  br i1 %11, label %12, label %23

12:                                               ; preds = %9
  br label %13

13:                                               ; preds = %16, %12
  %14 = phi i64 [ %20, %16 ], [ 0, %12 ]
  %15 = icmp slt i64 %14, 5
  br i1 %15, label %16, label %21

16:                                               ; preds = %13
  %17 = mul i64 %10, 5
  %18 = add i64 %17, %14
  %19 = getelementptr i32, ptr %1, i64 %18
  store i32 0, ptr %19, align 4
  %20 = add i64 %14, 1
  br label %13

21:                                               ; preds = %13
  %22 = add i64 %10, 1
  br label %9

23:                                               ; preds = %9
  call void @negative_inner_distance(ptr %1, ptr %1, i64 0, i64 5, i64 5, i64 5, i64 1)
  %24 = getelementptr i32, ptr %1, i64 11
  %25 = load i32, ptr %24, align 4
  call void @free(ptr %1)
  ret i32 %25
}

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
