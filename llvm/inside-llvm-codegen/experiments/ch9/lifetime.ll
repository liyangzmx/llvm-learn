declare void @consume(ptr nocapture)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture)
define void @sequential() {
  %a = alloca [64 x i8], align 8
  %b = alloca [64 x i8], align 8
  call void @llvm.lifetime.start.p0(i64 64, ptr %a)
  call void @consume(ptr %a)
  call void @llvm.lifetime.end.p0(i64 64, ptr %a)
  call void @llvm.lifetime.start.p0(i64 64, ptr %b)
  call void @consume(ptr %b)
  call void @llvm.lifetime.end.p0(i64 64, ptr %b)
  ret void
}
