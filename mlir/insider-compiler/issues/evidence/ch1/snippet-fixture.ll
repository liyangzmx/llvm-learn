; ModuleID = 'LLVMDialectModule'
source_filename = "LLVMDialectModule"

define void @snippet_fixture(ptr %0, <2 x i1> %1, <2 x float> %2, <2 x float> %3, <2 x float> %4) {
  br label %6

6:                                                ; preds = %17, %5
  %7 = phi i64 [ %18, %17 ], [ 0, %5 ]
  %8 = icmp slt i64 %7, 10
  br i1 %8, label %9, label %19

9:                                                ; preds = %12, %6
  %10 = phi i64 [ %16, %12 ], [ 0, %6 ]
  %11 = icmp slt i64 %10, 16
  br i1 %11, label %12, label %17

12:                                               ; preds = %9
  %13 = call <2 x float> @llvm.masked.load.v2f32.p0(ptr %0, i32 4, <2 x i1> %1, <2 x float> %2)
  %14 = fmul <2 x float> %3, %4
  %15 = fadd <2 x float> %13, %14
  call void @llvm.masked.store.v2f32.p0(<2 x float> %15, ptr %0, i32 4, <2 x i1> %1)
  %16 = add i64 %10, 1
  br label %9

17:                                               ; preds = %9
  %18 = add i64 %7, 1
  br label %6

19:                                               ; preds = %6
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: read)
declare <2 x float> @llvm.masked.load.v2f32.p0(ptr nocapture, i32 immarg, <2 x i1>, <2 x float>) #0

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: write)
declare void @llvm.masked.store.v2f32.p0(<2 x float>, ptr nocapture, i32 immarg, <2 x i1>) #1

attributes #0 = { nocallback nofree nosync nounwind willreturn memory(argmem: read) }
attributes #1 = { nocallback nofree nosync nounwind willreturn memory(argmem: write) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
