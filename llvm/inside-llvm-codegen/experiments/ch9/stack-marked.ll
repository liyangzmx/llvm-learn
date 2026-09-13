define dso_local void @foo(i32 noundef %var) local_unnamed_addr {
entry:
  %z = alloca [4096 x i8], align 1
  %x = alloca [4096 x i8], align 1
  %y = alloca [4096 x i8], align 1
  call void @llvm.lifetime.start.p0(i64 4096, ptr nonnull %z)
  call void @bar(ptr noundef nonnull %z, i32 noundef 0)
  call void @llvm.lifetime.end.p0(i64 4096, ptr nonnull %z)
  call void @llvm.lifetime.start.p0(i64 4096, ptr %x)
  call void @llvm.lifetime.start.p0(i64 4096, ptr %y)
  %tobool.not = icmp eq i32 %var, 0
  br i1 %tobool.not, label %if.else, label %B

if.else:                                          ; preds = %entry
  call void @bar(ptr noundef nonnull %y, i32 noundef 1)
  %add.ptr = getelementptr inbounds i8, ptr %y, i64 1024
  br label %B

B:                                                ; preds = %entry, %if.else
  %p.0 = phi ptr [ %add.ptr, %if.else ], [ %x, %entry ]
  call void @bar(ptr noundef nonnull %p.0, i32 noundef 2)
  call void @llvm.lifetime.end.p0(i64 4096, ptr %x)
  call void @llvm.lifetime.end.p0(i64 4096, ptr %y)
  ret void
}

declare void @bar(ptr, i32)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture)
