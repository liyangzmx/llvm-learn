; ModuleID = 'LLVMDialectModule'
source_filename = "LLVMDialectModule"

define float @test_scalar(float %0, float %1) {
  %3 = fadd float %0, %1
  ret float %3
}

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
