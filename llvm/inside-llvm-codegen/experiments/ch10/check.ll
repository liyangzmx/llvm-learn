; Return 0 when the sum and external-call bubbleSort examples are correct.
@data = global [8 x i32] [i32 7, i32 -2, i32 7, i32 0, i32 -9, i32 1, i32 3, i32 1], align 4
@expected = constant [8 x i32] [i32 -9, i32 -2, i32 0, i32 1, i32 1, i32 3, i32 7, i32 7], align 4

define void @swap(ptr %lhs, ptr %rhs) {
  %a = load i32, ptr %lhs, align 4
  %b = load i32, ptr %rhs, align 4
  store i32 %b, ptr %lhs, align 4
  store i32 %a, ptr %rhs, align 4
  ret void
}

define i32 @main() {
entry:
  %s = call i32 @sum()
  %sum.ok = icmp eq i32 %s, 45
  br i1 %sum.ok, label %sort, label %fail
sort:
  call void @bubbleSort(ptr @data, i32 8)
  call void @bubbleSort(ptr @data, i32 0)
  call void @bubbleSort(ptr @data, i32 1)
  br label %loop
loop:
  %i = phi i64 [0, %sort], [%next, %step]
  %p = getelementptr [8 x i32], ptr @data, i64 0, i64 %i
  %q = getelementptr [8 x i32], ptr @expected, i64 0, i64 %i
  %v = load i32, ptr %p, align 4
  %w = load i32, ptr %q, align 4
  %equal = icmp eq i32 %v, %w
  br i1 %equal, label %step, label %fail
step:
  %next = add i64 %i, 1
  %done = icmp eq i64 %next, 8
  br i1 %done, label %ok, label %loop
ok:
  ret i32 0
fail:
  ret i32 1
}
