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

15:                                               ; preds = %50, %7
  %16 = phi i64 [ %51, %50 ], [ 1, %7 ]
  %17 = icmp slt i64 %16, 5
  br i1 %17, label %18, label %52

18:                                               ; preds = %15
  br label %19

19:                                               ; preds = %48, %18
  %20 = phi i64 [ %49, %48 ], [ 0, %18 ]
  %21 = icmp slt i64 %20, 4
  br i1 %21, label %22, label %50

22:                                               ; preds = %19
  %23 = add i64 %16, 2
  br label %24

24:                                               ; preds = %46, %22
  %25 = phi i64 [ %47, %46 ], [ %16, %22 ]
  %26 = icmp slt i64 %25, %23
  br i1 %26, label %27, label %48

27:                                               ; preds = %24
  %28 = add i64 %20, 2
  br label %29

29:                                               ; preds = %32, %27
  %30 = phi i64 [ %45, %32 ], [ %20, %27 ]
  %31 = icmp slt i64 %30, %28
  br i1 %31, label %32, label %46

32:                                               ; preds = %29
  %33 = add i64 %25, -1
  %34 = add i64 %30, 1
  %35 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %14, 1
  %36 = mul i64 %33, 5
  %37 = add i64 %36, %34
  %38 = getelementptr i32, ptr %35, i64 %37
  %39 = load i32, ptr %38, align 4
  %40 = add i32 %39, 1
  %41 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %14, 1
  %42 = mul i64 %25, 5
  %43 = add i64 %42, %30
  %44 = getelementptr i32, ptr %41, i64 %43
  store i32 %40, ptr %44, align 4
  %45 = add i64 %30, 1
  br label %29

46:                                               ; preds = %29
  %47 = add i64 %25, 1
  br label %24

48:                                               ; preds = %24
  %49 = add i64 %20, 2
  br label %19

50:                                               ; preds = %19
  %51 = add i64 %16, 2
  br label %15

52:                                               ; preds = %15
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

9:                                                ; preds = %39, %0
  %10 = phi i64 [ %40, %39 ], [ 0, %0 ]
  %11 = icmp slt i64 %10, 5
  br i1 %11, label %12, label %41

12:                                               ; preds = %9
  br label %13

13:                                               ; preds = %37, %12
  %14 = phi i64 [ %38, %37 ], [ 0, %12 ]
  %15 = icmp slt i64 %14, 5
  br i1 %15, label %16, label %39

16:                                               ; preds = %13
  %17 = add i64 %10, 2
  %18 = icmp slt i64 %17, 5
  %19 = select i1 %18, i64 %17, i64 5
  br label %20

20:                                               ; preds = %35, %16
  %21 = phi i64 [ %36, %35 ], [ %10, %16 ]
  %22 = icmp slt i64 %21, %19
  br i1 %22, label %23, label %37

23:                                               ; preds = %20
  %24 = add i64 %14, 2
  %25 = icmp slt i64 %24, 5
  %26 = select i1 %25, i64 %24, i64 5
  br label %27

27:                                               ; preds = %30, %23
  %28 = phi i64 [ %34, %30 ], [ %14, %23 ]
  %29 = icmp slt i64 %28, %26
  br i1 %29, label %30, label %35

30:                                               ; preds = %27
  %31 = mul i64 %21, 5
  %32 = add i64 %31, %28
  %33 = getelementptr i32, ptr %1, i64 %32
  store i32 0, ptr %33, align 4
  %34 = add i64 %28, 1
  br label %27

35:                                               ; preds = %27
  %36 = add i64 %21, 1
  br label %20

37:                                               ; preds = %20
  %38 = add i64 %14, 2
  br label %13

39:                                               ; preds = %13
  %40 = add i64 %10, 2
  br label %9

41:                                               ; preds = %9
  call void @negative_inner_distance(ptr %1, ptr %1, i64 0, i64 5, i64 5, i64 5, i64 1)
  %42 = getelementptr i32, ptr %1, i64 11
  %43 = load i32, ptr %42, align 4
  call void @free(ptr %1)
  ret i32 %43
}

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
