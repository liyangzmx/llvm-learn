define dso_local void @bubbleSort(ptr %arr, i32 %n) {
entry:
  br label %outer.cond
outer.cond:
  %i = phi i32 [ 0, %entry ], [ %i.next, %outer.inc ]
  %outer.limit = sub nsw i32 %n, 1
  %outer.test = icmp slt i32 %i, %outer.limit
  br i1 %outer.test, label %outer.body, label %exit
outer.body:
  br label %inner.cond
inner.cond:
  %j = phi i32 [ 0, %outer.body ], [ %j.next, %inner.inc ]
  %remaining = sub nsw i32 %n, %i
  %inner.limit = sub nsw i32 %remaining, 1
  %inner.test = icmp slt i32 %j, %inner.limit
  br i1 %inner.test, label %compare, label %inner.end
compare:
  %index = sext i32 %j to i64
  %lhs = getelementptr inbounds i32, ptr %arr, i64 %index
  %lhs.value = load i32, ptr %lhs, align 4
  %next = add nsw i32 %j, 1
  %next.index = sext i32 %next to i64
  %rhs = getelementptr inbounds i32, ptr %arr, i64 %next.index
  %rhs.value = load i32, ptr %rhs, align 4
  %out.of.order = icmp sgt i32 %lhs.value, %rhs.value
  br i1 %out.of.order, label %do.swap, label %after.swap
do.swap:
  %swap.index = sext i32 %j to i64
  %swap.lhs = getelementptr inbounds i32, ptr %arr, i64 %swap.index
  %swap.next = add nsw i32 %j, 1
  %swap.next.index = sext i32 %swap.next to i64
  %swap.rhs = getelementptr inbounds i32, ptr %arr, i64 %swap.next.index
  call void @swap(ptr %swap.lhs, ptr %swap.rhs)
  br label %after.swap
after.swap:
  br label %inner.inc
inner.inc:
  %j.next = add nsw i32 %j, 1
  br label %inner.cond
inner.end:
  br label %outer.inc
outer.inc:
  %i.next = add nsw i32 %i, 1
  br label %outer.cond
exit:
  ret void
}

declare dso_local void @swap(ptr, ptr)
