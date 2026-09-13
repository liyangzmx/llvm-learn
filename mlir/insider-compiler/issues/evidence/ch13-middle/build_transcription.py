#!/usr/bin/env python3
"""Expand only repeated type/layout spellings in the manually proofread listings.
This is a transcription aid, not a Triton compiler or pass-output generator.
"""
from pathlib import Path
import re
R=Path(__file__).resolve().parent
AL='#triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>'
BL='#triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>'
C='#triton_gpu.nvidia_mma<{versionMajor = 2, versionMinor = 0, warpsPerCTA = [4, 1], instrShape = []}>'
SA='#triton_gpu.shared<{vec = 8, perPhase = 2, maxPhase = 4, order = [1, 0], hasLeadingOffset = false}>'
SB='#triton_gpu.shared<{vec = 8, perPhase = 1, maxPhase = 8, order = [1, 0], hasLeadingOffset = false}>'
D={'AL':AL,'BL':BL,'C':C,'SA':SA,'SB':SB}
D['AS']='#triton_gpu.slice<{dim = 0, parent = '+AL+'}>'
D['BS']='#triton_gpu.slice<{dim = 0, parent = '+BL+'}>'
D['A']='#triton_gpu.dot_op<{opIdx = 0, parent = '+C+', kWidth = 2}>'
D['B']='#triton_gpu.dot_op<{opIdx = 1, parent = '+C+', kWidth = 2}>'
for key,shape,layout in [('AP','128x32x!tt.ptr<f16>',AL),('BP','32x128x!tt.ptr<f16>',BL),('AI','128x32xi32',AL),('BI','32x128xi32',BL),('AM','128x32xi1',AL),('BM','32x128xi1',BL),('AF','128x32xf16',AL),('BF','32x128xf16',BL),('AD','128x32xf16',D['A']),('BD','32x128xf16',D['B']),('CF','128x128xf32',C),('AR','32xi32',D['AS']),('BR','128xi32',D['BS']),('AE','1x32xi32',AL),('BE','1x128xi32',BL)]:
 D[key]='tensor<'+shape+', '+layout+'>'
for k,shape,layout in [('MA','128x32xf16',SA),('MB','32x128xf16',SB),('MA2','2x128x32xf16',SA),('MB2','2x32x128xf16',SB)]:
 D[k]='!tt.memdesc<'+shape+', '+layout+', #triton_gpu.shared_memory, mutable>'
D['TA']='<128x32xf16, '+SA+', #triton_gpu.shared_memory, mutable>'
D['TB']='<32x128xf16, '+SB+', #triton_gpu.shared_memory, mutable>'
D['TK']='!triton_gpu.async.token'
def expand(s):
 return re.sub(r'\{\{(\w+)\}\}',lambda m:D[m.group(1)],s)
listings={}
listings[37]='''// Pipeline 前；伪代码，0 <= I < N，步长为 1。
for I in [0, N) {
  S0(I)
  S1(I)
  S2(I)
}
'''
listings[38]='''// 前言；这里假定 N >= 2。
S0(0); S0(1); S1(0);
// Pipelined Kernel。
for I in [0, N - 2) {
  S0(I + 2); S1(I + 1); S2(I);
}
// 后序。
S1(N - 1); S2(N - 2); S2(N - 1);
'''
# The original example differs from the reference repository test: it has no
# b_scale/mulf and no externally returned matrix. Keep the printed example.
listings[39]='''#AL = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [4, 8], warpsPerCTA = [4, 1], order = [1, 0]}>
#BL = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0]}>
#ALs0 = #triton_gpu.slice<{parent = #AL, dim = 0}>
#BLs0 = #triton_gpu.slice<{parent = #BL, dim = 0}>
#C = #triton_gpu.nvidia_mma<{versionMajor = 2, warpsPerCTA = [4, 1]}>
#A = #triton_gpu.dot_op<{opIdx = 0, parent = #C, kWidth = 2}>
#B = #triton_gpu.dot_op<{opIdx = 1, parent = #C, kWidth = 2}>
module attributes {"triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32} {
  tt.func @matmul_loop(%lb: index, %ub: index, %step: index,
      %A: !tt.ptr<f16> {tt.divisibility = 16 : i32},
      %B: !tt.ptr<f16> {tt.divisibility = 16 : i32}) {
    %a_ptr_splat = tt.splat %A : !tt.ptr<f16> -> tensor<128x32x!tt.ptr<f16>, #AL>
    %a_tmp0 = tt.make_range {end = 32 : i32, start = 0 : i32} : tensor<32xi32, #ALs0>
    %a_tmp1 = tt.expand_dims %a_tmp0 {axis = 0 : i32} : tensor<32xi32, #ALs0> -> tensor<1x32xi32, #AL>
    %a_offs = tt.broadcast %a_tmp1 : tensor<1x32xi32, #AL> -> tensor<128x32xi32, #AL>
    %a_ptr_init = tt.addptr %a_ptr_splat, %a_offs : tensor<128x32x!tt.ptr<f16>, #AL>, tensor<128x32xi32, #AL>
    %b_ptr_splat = tt.splat %B : !tt.ptr<f16> -> tensor<32x128x!tt.ptr<f16>, #BL>
    %b_tmp0 = tt.make_range {end = 128 : i32, start = 0 : i32} : tensor<128xi32, #BLs0>
    %b_tmp1 = tt.expand_dims %b_tmp0 {axis = 0 : i32} : tensor<128xi32, #BLs0> -> tensor<1x128xi32, #BL>
    %b_offs = tt.broadcast %b_tmp1 : tensor<1x128xi32, #BL> -> tensor<32x128xi32, #BL>
    %b_ptr_init = tt.addptr %b_ptr_splat, %b_offs : tensor<32x128x!tt.ptr<f16>, #BL>, tensor<32x128xi32, #BL>

    %a_mask = arith.constant dense<true> : tensor<128x32xi1, #AL>
    %a_other = arith.constant dense<0.00e+00> : tensor<128x32xf16, #AL>
    %b_mask = arith.constant dense<true> : tensor<32x128xi1, #BL>
    %b_other = arith.constant dense<0.00e+00> : tensor<32x128xf16, #BL>
    %c_init = arith.constant dense<0.00e+00> : tensor<128x128xf32, #C>
    %a_off = arith.constant dense<4> : tensor<128x32xi32, #AL>
    %b_off = arith.constant dense<4> : tensor<32x128xi32, #BL>

    scf.for %iv = %lb to %ub step %step iter_args(
        %a_ptr = %a_ptr_init, %b_ptr = %b_ptr_init, %prev_c = %c_init)
        -> (tensor<128x32x!tt.ptr<f16>, #AL>, tensor<32x128x!tt.ptr<f16>, #BL>, tensor<128x128xf32, #C>) {
      // 原书加粗的候选加载。
      %a_ = tt.load %a_ptr : tensor<128x32x!tt.ptr<f16>, #AL>
      %a = triton_gpu.convert_layout %a_ : tensor<128x32xf16, #AL> -> tensor<128x32xf16, #A>
      %b_ = tt.load %b_ptr, %b_mask, %b_other : tensor<32x128x!tt.ptr<f16>, #BL>
      %b = triton_gpu.convert_layout %b_ : tensor<32x128xf16, #BL> -> tensor<32x128xf16, #B>
      // 原书加粗的点积根操作。
      %c = tt.dot %a, %b, %prev_c : tensor<128x32xf16, #A> * tensor<32x128xf16, #B> -> tensor<128x128xf32, #C>
      %next_a_ptr = tt.addptr %a_ptr, %a_off : tensor<128x32x!tt.ptr<f16>, #AL>, tensor<128x32xi32, #AL>
      %next_b_ptr = tt.addptr %b_ptr, %b_off : tensor<32x128x!tt.ptr<f16>, #BL>, tensor<32x128xi32, #BL>
      scf.yield %next_a_ptr, %next_b_ptr, %c : tensor<128x32x!tt.ptr<f16>, #AL>, tensor<32x128x!tt.ptr<f16>, #BL>, tensor<128x128xf32, #C>
    }
    tt.return
  }
}
'''
listings[40]='''---- Ops in stage 0 // stage 0 的操作
cluster: 1:
%13 = tt.load %arg7, %cst_1, %cst_2 : {{BP}}
cluster: 1:
%11 = tt.load %arg6 : {{AP}}
---- Ops in stage 1
---- Ops in stage 2
cluster: 0:
%15 = tt.dot %12, %14, %arg8 : {{AD}} * {{BD}} -> {{CF}}
'''
prelude='''module attributes {"triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32} {
  tt.func @matmul_loop(%arg0: index, %arg1: index, %arg2: index,
      %arg3: !tt.ptr<f16> {tt.divisibility = 16 : i32},
      %arg4: !tt.ptr<f16> {tt.divisibility = 16 : i32}) {
    %0 = tt.splat %arg3 : !tt.ptr<f16> -> {{AP}}
    %1 = tt.make_range {end = 32 : i32, start = 0 : i32} : {{AR}}
    %2 = tt.expand_dims %1 {axis = 0 : i32} : {{AR}} -> {{AE}}
    %3 = tt.broadcast %2 : {{AE}} -> {{AI}}
    %4 = tt.addptr %0, %3 : {{AP}}, {{AI}}
    %5 = tt.splat %arg4 : !tt.ptr<f16> -> {{BP}}
    %6 = tt.make_range {end = 128 : i32, start = 0 : i32} : {{BR}}
    %7 = tt.expand_dims %6 {axis = 0 : i32} : {{BR}} -> {{BE}}
    %8 = tt.broadcast %7 : {{BE}} -> {{BI}}
    %9 = tt.addptr %5, %8 : {{BP}}, {{BI}}
    %cst = arith.constant dense<true> : {{AM}}
    %cst_0 = arith.constant dense<0.000000e+00> : {{AF}}
    %cst_1 = arith.constant dense<true> : {{BM}}
    %cst_2 = arith.constant dense<0.000000e+00> : {{BF}}
    %cst_3 = arith.constant dense<0.000000e+00> : {{CF}}
    %cst_4 = arith.constant dense<4> : {{AI}}
    %cst_5 = arith.constant dense<4> : {{BI}}
    %10 = triton_gpu.local_alloc : () -> {{MA2}}
    %11 = triton_gpu.local_alloc : () -> {{MB2}}
'''
end='''    tt.return
  }
}
'''
listings[41]=prelude+'''    %12:3 = scf.for %arg5 = %arg0 to %arg1 step %arg2 iter_args(
        %arg6 = %4, %arg7 = %9, %arg8 = %cst_3) -> ({{AP}}, {{BP}}, {{CF}}) {
      %13 = tt.load %arg6 : {{AP}}
      %14 = triton_gpu.convert_layout %13 : {{AF}} -> {{AD}}
      %15 = tt.load %arg7, %cst_1, %cst_2 : {{BP}}
      %16 = triton_gpu.convert_layout %15 : {{BF}} -> {{BD}}
      %17 = tt.dot %14, %16, %arg8 : {{AD}} * {{BD}} -> {{CF}}
      %18 = tt.addptr %arg6, %cst_4 : {{AP}}, {{AI}}
      %19 = tt.addptr %arg7, %cst_5 : {{BP}}, {{BI}}
      scf.yield %18, %19, %17 : {{AP}}, {{BP}}, {{CF}}
    }
'''+end
ring='''    %c-1_i32 = arith.constant -1 : i32
    %c0_i32 = arith.constant 0 : i32
    %c1_i32 = arith.constant 1 : i32
    %c2_i32 = arith.constant 2 : i32
    %c0_i32_6 = arith.constant 0 : i32
    %c0_i32_7 = arith.constant 0 : i32
'''
body42='''    %12:5 = scf.for %arg5 = %arg0 to %arg1 step %arg2 iter_args(
        %arg6 = %4, %arg7 = %9, %arg8 = %cst_3, %arg9 = %c-1_i32,
        %arg10 = %c-1_i32) -> ({{AP}}, {{BP}}, {{CF}}, i32, i32) {
      %13 = arith.addi %arg9, %c1_i32 : i32
      %14 = arith.cmpi slt, %13, %c2_i32 : i32
      %15 = arith.select %14, %13, %c0_i32 : i32
      %16 = arith.addi %arg10, %c1_i32 : i32
      %17 = arith.cmpi slt, %16, %c2_i32 : i32
      %18 = arith.select %17, %16, %c0_i32 : i32
      %19 = triton_gpu.memdesc_subview %10[%15, %c0_i32_6, %c0_i32_6] : {{MA2}} -> {{MA}}
      %20 = triton_gpu.async_copy_global_to_local %arg6, %19 : {{AP}} -> {{TA}}
      %21 = triton_gpu.async_commit_group %20
      %22 = triton_gpu.async_wait %21 {num = 0 : i32}
      %23 = triton_gpu.memdesc_subview %10[%18, %c0_i32_6, %c0_i32_6] : {{MA2}} -> {{MA}}
      %24 = triton_gpu.local_load %23 token %22 : {{MA}} -> {{AF}}
      %25 = triton_gpu.convert_layout %24 : {{AF}} -> {{AD}}
      %26 = triton_gpu.memdesc_subview %11[%15, %c0_i32_7, %c0_i32_7] : {{MB2}} -> {{MB}}
      %27 = triton_gpu.async_copy_global_to_local %arg7, %26 mask %cst_1 other %cst_2 : {{BP}} -> {{TB}}
      %28 = triton_gpu.async_commit_group %27
      %29 = triton_gpu.async_wait %28 {num = 0 : i32}
      %30 = triton_gpu.memdesc_subview %11[%18, %c0_i32_7, %c0_i32_7] : {{MB2}} -> {{MB}}
      %31 = triton_gpu.local_load %30 token %29 : {{MB}} -> {{BF}}
      %32 = triton_gpu.convert_layout %31 : {{BF}} -> {{BD}}
      %33 = tt.dot %25, %32, %arg8 : {{AD}} * {{BD}} -> {{CF}}
      %34 = tt.addptr %arg6, %cst_4 : {{AP}}, {{AI}}
      %35 = tt.addptr %arg7, %cst_5 : {{BP}}, {{BI}}
      scf.yield %34, %35, %33, %15, %18 : {{AP}}, {{BP}}, {{CF}}, i32, i32
    }
'''
listings[42]=prelude+ring+body42+end
ops={int(m.group(1)):m.group(0).strip() for m in re.finditer(r'^\s*%(\d+) = .*$',body42,re.M)}
def stage(number,cluster,ids):
 return f'---- Ops in stage {number}\n'+''.join(f'cluster: {cluster}:\n{ops[n]}\n' for n in ids)
listings[43]=stage(0,1,[21,28,20,27])+stage(1,2,[22,30,29,23])+stage(2,0,[33])
listings[44]=stage(0,2,[21,15,13,28,14,20,19,27,26])+stage(1,3,[18,16,22,17,30,29,23])+stage(2,1,[32,33,25,24,31])
listings[45]=prelude+ring+body42+'''    %13 = triton_gpu.async_wait {num = 0 : i32}
    triton_gpu.local_dealloc %10 : {{MA2}}
    triton_gpu.local_dealloc %11 : {{MB2}}
'''+end
# Printing the extra outer wait reserves %13; the old loop body becomes %14..36.
def shift_body(s,offset,loop_result):
 def repl(m):
  n=int(m.group(1));return '%'+str(loop_result if n==12 else n+offset if n>=13 else n)
 return re.sub(r'%(\d+)\b',repl,s)
listings[45]=prelude+ring+shift_body(body42,1,12)+'''    %13 = triton_gpu.async_wait {num = 0 : i32}
    triton_gpu.local_dealloc %10 : {{MA2}}
    triton_gpu.local_dealloc %11 : {{MB2}}
'''+end
prologue46='''    // 原书加粗部分：流水线前言中的复制与谓词保护。
    %c0 = arith.constant 0 : index
    %12 = arith.muli %arg2, %c0 : index
    %13 = arith.addi %arg0, %12 : index
    %14 = arith.cmpi slt, %13, %arg1 : index
    %c0_8 = arith.constant 0 : index
    %15 = arith.muli %arg2, %c0_8 : index
    %16 = arith.addi %arg0, %15 : index
    %17 = arith.addi %c-1_i32, %c1_i32 : i32
    %18 = arith.cmpi slt, %17, %c2_i32 : i32
    %19 = arith.select %18, %17, %c0_i32 : i32
    %20 = triton_gpu.memdesc_subview %10[%19, %c0_i32_6, %c0_i32_6] : {{MA2}} -> {{MA}}
    %21 = tt.splat %14 : i1 -> {{AM}}
    %22 = triton_gpu.async_copy_global_to_local %4, %20 mask %21 : {{AP}} -> {{TA}}
    %23 = triton_gpu.async_commit_group %22
    %24 = triton_gpu.memdesc_subview %11[%19, %c0_i32_7, %c0_i32_7] : {{MB2}} -> {{MB}}
    %25 = tt.splat %14 : i1 -> {{BM}}
    %26 = arith.andi %25, %cst_1 : {{BM}}
    %27 = triton_gpu.async_copy_global_to_local %9, %24 mask %26 other %cst_2 : {{BP}} -> {{TB}}
    %28 = triton_gpu.async_commit_group %27
    %c1 = arith.constant 1 : index
    %29 = arith.muli %arg2, %c1 : index
    %30 = arith.addi %arg0, %29 : index
    %31 = arith.cmpi slt, %30, %arg1 : index
    %c1_9 = arith.constant 1 : index
    %32 = arith.muli %arg2, %c1_9 : index
    %33 = arith.addi %arg0, %32 : index
    %34 = tt.addptr %4, %cst_4 : {{AP}}, {{AI}}
    %35 = tt.addptr %9, %cst_5 : {{BP}}, {{BI}}
    %36 = arith.addi %19, %c1_i32 : i32
    %37 = arith.cmpi slt, %36, %c2_i32 : i32
    %38 = arith.select %37, %36, %c0_i32 : i32
    %39 = triton_gpu.memdesc_subview %10[%38, %c0_i32_6, %c0_i32_6] : {{MA2}} -> {{MA}}
    %40 = tt.splat %31 : i1 -> {{AM}}
    %41 = triton_gpu.async_copy_global_to_local %34, %39 mask %40 : {{AP}} -> {{TA}}
    %42 = triton_gpu.async_commit_group %41
    %43 = triton_gpu.memdesc_subview %11[%38, %c0_i32_7, %c0_i32_7] : {{MB2}} -> {{MB}}
    %44 = tt.splat %31 : i1 -> {{BM}}
    %45 = arith.andi %44, %cst_1 : {{BM}}
    %46 = triton_gpu.async_copy_global_to_local %35, %43 mask %45 other %cst_2 : {{BP}} -> {{TB}}
    %47 = triton_gpu.async_commit_group %46
    %48 = arith.addi %c-1_i32, %c1_i32 : i32
    %49 = arith.cmpi slt, %48, %c2_i32 : i32
    %50 = arith.select %49, %48, %c0_i32 : i32
    %51 = triton_gpu.async_wait %23 {num = 0 : i32}
    %52 = triton_gpu.memdesc_subview %10[%50, %c0_i32_6, %c0_i32_6] : {{MA2}} -> {{MA}}
    %53 = triton_gpu.async_wait %28 {num = 0 : i32}
    %54 = triton_gpu.memdesc_subview %11[%50, %c0_i32_7, %c0_i32_7] : {{MB2}} -> {{MB}}
    // 原循环尚未完成重写；此处是编译器内部的中间快照。
'''
listings[46]=prelude+ring+prologue46+shift_body(body42,44,55)+'''    %56 = triton_gpu.async_wait {num = 0 : i32}
    triton_gpu.local_dealloc %10 : {{MA2}}
    triton_gpu.local_dealloc %11 : {{MB2}}
'''+end
head47=prelude[:prelude.index('    %0 =')]+'''    %c2 = arith.constant 2 : index
    %c2_i32 = arith.constant 2 : i32
    %c1_i32 = arith.constant 1 : i32
    %c0_i32 = arith.constant 0 : i32
    %cst = arith.constant dense<4> : {{BI}}
    %cst_0 = arith.constant dense<4> : {{AI}}
    %cst_1 = arith.constant dense<0.000000e+00> : {{CF}}
    %cst_2 = arith.constant dense<0.000000e+00> : {{BF}}
'''+prelude[prelude.index('    %0 ='):prelude.index('    %cst =')]+prelude[prelude.index('    %10 ='):]
listings[47]=head47+'''    %12 = arith.cmpi slt, %arg0, %arg1 : index
    %13 = triton_gpu.memdesc_subview %10[%c0_i32, %c0_i32, %c0_i32] : {{MA2}} -> {{MA}}
    %14 = tt.splat %12 : i1 -> {{AM}}
    %15 = triton_gpu.async_copy_global_to_local %4, %13 mask %14 : {{AP}} -> {{TA}}
    %16 = triton_gpu.async_commit_group %15
    %17 = triton_gpu.memdesc_subview %11[%c0_i32, %c0_i32, %c0_i32] : {{MB2}} -> {{MB}}
    %18 = tt.splat %12 : i1 -> {{BM}}
    %19 = triton_gpu.async_copy_global_to_local %9, %17 mask %18 other %cst_2 : {{BP}} -> {{TB}}
    %20 = triton_gpu.async_commit_group %19
    %21 = arith.addi %arg0, %arg2 : index
    %22 = arith.cmpi slt, %21, %arg1 : index
    %23 = tt.addptr %4, %cst_0 : {{AP}}, {{AI}}
    %24 = tt.addptr %9, %cst : {{BP}}, {{BI}}
    %25 = triton_gpu.memdesc_subview %10[%c1_i32, %c0_i32, %c0_i32] : {{MA2}} -> {{MA}}
    %26 = tt.splat %22 : i1 -> {{AM}}
    %27 = triton_gpu.async_copy_global_to_local %23, %25 mask %26 : {{AP}} -> {{TA}}
    %28 = triton_gpu.async_commit_group %27
    %29 = triton_gpu.memdesc_subview %11[%c1_i32, %c0_i32, %c0_i32] : {{MB2}} -> {{MB}}
    %30 = tt.splat %22 : i1 -> {{BM}}
    %31 = triton_gpu.async_copy_global_to_local %24, %29 mask %30 other %cst_2 : {{BP}} -> {{TB}}
    %32 = triton_gpu.async_commit_group %31
    %33 = triton_gpu.memdesc_subview %10[%c0_i32, %c0_i32, %c0_i32] : {{MA2}} -> {{MA}}
    %34 = triton_gpu.async_wait %20 {num = 2 : i32}
    %35 = triton_gpu.memdesc_subview %11[%c0_i32, %c0_i32, %c0_i32] : {{MB2}} -> {{MB}}
    %36:11 = scf.for %arg5 = %arg0 to %arg1 step %arg2 iter_args(
        %arg6 = %23, %arg7 = %24, %arg8 = %cst_1, %arg9 = %c1_i32,
        %arg10 = %c0_i32, %arg11 = %33, %arg12 = %34, %arg13 = %35,
        %arg14 = %34, %arg15 = %28, %arg16 = %32)
        -> ({{AP}}, {{BP}}, {{CF}}, i32, i32, {{MA}}, {{TK}}, {{MB}}, {{TK}}, {{TK}}, {{TK}}) {
      %38 = arith.muli %arg2, %c2 : index
      %39 = arith.subi %arg1, %38 : index
      %40 = arith.cmpi slt, %arg5, %39 : index
      %41 = triton_gpu.local_load %arg11 token %arg12 : {{MA}} -> {{AF}}
      %42 = triton_gpu.convert_layout %41 : {{AF}} -> {{AD}}
      %43 = triton_gpu.local_load %arg13 token %arg14 : {{MB}} -> {{BF}}
      %44 = triton_gpu.convert_layout %43 : {{BF}} -> {{BD}}
      %45 = tt.dot %42, %44, %arg8 : {{AD}} * {{BD}} -> {{CF}}
      %46 = tt.addptr %arg6, %cst_0 : {{AP}}, {{AI}}
      %47 = tt.addptr %arg7, %cst : {{BP}}, {{BI}}
      %48 = arith.addi %arg9, %c1_i32 : i32
      %49 = arith.cmpi slt, %48, %c2_i32 : i32
      %50 = arith.select %49, %48, %c0_i32 : i32
      %51 = triton_gpu.memdesc_subview %10[%50, %c0_i32, %c0_i32] : {{MA2}} -> {{MA}}
      %52 = tt.splat %40 : i1 -> {{AM}}
      %53 = triton_gpu.async_copy_global_to_local %46, %51 mask %52 : {{AP}} -> {{TA}}
      %54 = triton_gpu.async_commit_group %53
      %55 = triton_gpu.memdesc_subview %11[%50, %c0_i32, %c0_i32] : {{MB2}} -> {{MB}}
      %56 = tt.splat %40 : i1 -> {{BM}}
      %57 = triton_gpu.async_copy_global_to_local %47, %55 mask %56 other %cst_2 : {{BP}} -> {{TB}}
      %58 = triton_gpu.async_commit_group %57
      %59 = arith.addi %arg10, %c1_i32 : i32
      %60 = arith.cmpi slt, %59, %c2_i32 : i32
      %61 = arith.select %60, %59, %c0_i32 : i32
      %62 = triton_gpu.memdesc_subview %10[%61, %c0_i32, %c0_i32] : {{MA2}} -> {{MA}}
      %63 = triton_gpu.async_wait %arg16 {num = 2 : i32}
      %64 = triton_gpu.memdesc_subview %11[%61, %c0_i32, %c0_i32] : {{MB2}} -> {{MB}}
      scf.yield %46, %47, %45, %50, %61, %62, %63, %64, %63, %54, %58 : {{AP}}, {{BP}}, {{CF}}, i32, i32, {{MA}}, {{TK}}, {{MB}}, {{TK}}, {{TK}}, {{TK}}
    }
    %37 = triton_gpu.async_wait {num = 0 : i32}
    triton_gpu.local_dealloc %10 : {{MA2}}
    triton_gpu.local_dealloc %11 : {{MB2}}
'''+end
for number,code in listings.items():
 suffix='txt' if number in (37,38,40,43,44) else 'mlir'
 (R/f'listing-13-{number}.{suffix}').write_text(expand(code))
