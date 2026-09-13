# 第 9 章校核与实验记录

基线：原书 LLVM 15.0.1 → 本地 LLVM 18.1.8，HEAD `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。本轮全文重新审读，核心旧日志/图解按新输入及实际输出改写。原文保存在 origin。工具来自本轮统一构建（Debug、Assertions，7 个目标），本章不修改 LLVM 源码；BPF 用户差异及构建修复分别记录于 [source-baseline.json](source-baseline.json)、[build-source-fix.patch](build-source-fix.patch)。

运行入口：[runner.py](../experiments/ch9/runner.py)，接口 `python3 runner.py --out DIR`；输入自包含，产物和 `results.json` 写入 DIR，默认使用临时目录。[结果 JSON](experiments-ch9.json) 记录输入 SHA256、工具路径、源码提交及每条命令的退出状态。

## 覆盖清单

| 范围 | 源码位置/符号（llvm/ 下） | 本轮处理及证据 |
|---|---|---|
| 章首/9.1/清单 9-1～9-3 | lib/CodeGen/TargetPassConfig.cpp:1094；TailDuplicator.cpp:556 | 重写真实次序、目标钩子、复制合法性及 SSA 修复；清单 1/2 是 C++ 说明，清单 3 是完整 tail.ll。BPF v4 默认 7 块，tail-dup-size=10 后 6 块。说明最终函数只依赖 y。 |
| 9.2 | OptimizePHIs.cpp:96 | 单值/死 PHI 环和 COPY 追踪边界；phi.mir 实测同值 PHI 删除。 |
| 9.3/清单 9-4～9-8 | StackColoring.cpp:475,1210 | 原 C 在 AArch64 保留 3×4096 槽；完整手写 marked IR 合并 x→z，保留 2 槽，不能宣称理想 1 槽。另用 BPF sequential lifetime 输入验证 2×64→1×64。清单 5 仅存储复用示意、8 为伪码。 |
| 9.4 | LocalStackSlotAllocation.cpp:112 | 目标 requiresVirtualBaseRegisters 前提、needsFrameBaseReg、预布局与 PEI 责任；AArch64 LDP/STP 缩放范围核对。该专门虚拟基址触发未单独运行。 |
| 9.5 | DeadMachineInstructionElim.cpp:105 | 改死依赖传播方向与固定点迭代，dce.mir 的死 ADD/COPY 链实际删除。 |
| 9.6/清单 9-9～9-16 | EarlyIfConversion.cpp:199,1063；Target/X86/X86Subtarget.cpp:373 | 清单 9～11 是合法性受限的伪码，12 为完整 C++，13/16 是实际 MIR，14 为算法中间态，15 为实际选择片段。X86 默认开关关闭；显式 -x86-early-ifcvt 后 4→1 块、2 CMOV，无需 stress。 |
| 9.7/清单 9-17 | MachineLICM.cpp:1006 | 改循环不变性与安全推测的条件，不能仅凭唯一 SSA 定义判断；C 是说明，独立 licm.mir 实测 MUL_rr 外提。 |
| 9.8/清单 9-18 | MachineCSE.cpp:938 | RISCV64 全局 CSE 6→3 条算术，4 store 保留；BPF 同块重复 ADD 合并。补支配与压力权衡。 |
| 9.9 | MachineSink.cpp:1043 | sink.mir 实测 ADD 从入口移入唯一使用分支；补 PHI 入边、关键边、支配子节点、压力边界。 |
| 9.10～9.11 | PeepholeOptimizer.cpp:689 | 保留约 10 类模式的机制与目标钩子，修比较/选择/load 折叠的绝对断言；各目标专用模式静态覆盖，未逐一运行。 |

## 验证与限制

- runner 对 MIR 变换结果有断言并启用机器验证器；IR assembler/verifier 接受 tail/cse/lifetime，Clang 生成 X86/AArch64 输入。
- 这组实验验证指定输入的机器结构和 Pass 行为；未运行目标 CPU/BPF VM 性能测试，也不构成所有输入的等价证明。
- 所有 18 个清单编号保留。含省略的 MIR body 与算法伪码明确标识；可重跑文件统一位于 experiments/ch9。旧输出图改为文字或 Mermaid，避免把旧编号当当前结果。

## LLVM 18 源码依据

- [llvm/lib/CodeGen/TargetPassConfig.cpp:1094](/opt/llvm-project/llvm/lib/CodeGen/TargetPassConfig.cpp:1094)：`addMachinePasses / addMachineSSAOptimization`。
- [llvm/lib/CodeGen/TailDuplicator.cpp:556](/opt/llvm-project/llvm/lib/CodeGen/TailDuplicator.cpp:556)：`shouldTailDuplicate`。
- [llvm/lib/CodeGen/OptimizePHIs.cpp:96](/opt/llvm-project/llvm/lib/CodeGen/OptimizePHIs.cpp:96)：`IsSingleValuePHICycle / IsDeadPHICycle`。
- [llvm/lib/CodeGen/StackColoring.cpp:475](/opt/llvm-project/llvm/lib/CodeGen/StackColoring.cpp:475)：`applyFirstUse / remapInstructions / runOnMachineFunction`。
- [llvm/lib/CodeGen/LocalStackSlotAllocation.cpp:112](/opt/llvm-project/llvm/lib/CodeGen/LocalStackSlotAllocation.cpp:112)：`LocalStackSlotPass::runOnMachineFunction`。
- [llvm/lib/CodeGen/DeadMachineInstructionElim.cpp:105](/opt/llvm-project/llvm/lib/CodeGen/DeadMachineInstructionElim.cpp:105)：`runOnMachineFunction / eliminateDeadMI`。
- [llvm/lib/CodeGen/EarlyIfConversion.cpp:199](/opt/llvm-project/llvm/lib/CodeGen/EarlyIfConversion.cpp:199)：`SSAIfConv::canSpeculateInstrs / canConvertIf`。
- [llvm/lib/CodeGen/MachineLICM.cpp:1006](/opt/llvm-project/llvm/lib/CodeGen/MachineLICM.cpp:1006)：`IsLICMCandidate / IsProfitableToHoist`。
- [llvm/lib/CodeGen/MachineCSE.cpp:938](/opt/llvm-project/llvm/lib/CodeGen/MachineCSE.cpp:938)：`runOnMachineFunction / isProfitableToCSE`。
- [llvm/lib/CodeGen/MachineSink.cpp:1043](/opt/llvm-project/llvm/lib/CodeGen/MachineSink.cpp:1043)：`isProfitableToSinkTo / SinkInstruction`。
- [llvm/lib/CodeGen/PeepholeOptimizer.cpp:689](/opt/llvm-project/llvm/lib/CodeGen/PeepholeOptimizer.cpp:689)：`optimizeSelect / optimizeCondBranch`。


- [llvm/lib/Target/X86/X86Subtarget.cpp:373](/opt/llvm-project/llvm/lib/Target/X86/X86Subtarget.cpp:373)：X86 EarlyIfConversion 的目标开关。
