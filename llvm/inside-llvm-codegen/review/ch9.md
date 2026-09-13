# 第 9 章静态校核记录

基线：原书 LLVM 15.0.1 → 本地 LLVM 18.1.8，HEAD `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。完整阅读原章及相应实现；未编译或执行任何示例。原图保留为历史对照，正文覆盖修正。

| 范围 | 核查位置/符号 | 结论与处理 |
|---|---|---|
| 章首与9.1–9.11 | TargetPassConfig::addMachineSSAOptimization | 确认通用次序，补非O0条件和目标ILP钩子；IPL修为ILP。 |
| 9.1，清单9-1～9-3，图9-2～9-6 | TailDuplicator::shouldTailDuplicate | 默认阈值2/20仍成立；补收敛语义与目标限制；9-3是输入而非Pass输出，阈值统计机器指令而非IR行数。 |
| 9.2 | OptimizePHIs.cpp | 确认单一外部值PHI环与死PHI环；修概述过窄定义。 |
| 9.3，清单9-4～9-8 | StackColoring::calculateLiveIntervals/remapInstructions | 修数组在汇聚点仍通过p使用、IR intrinsic与MIR伪指令区别、allloca不会全部删除、默认first-use活跃性；历史布局不声称LLVM18输出。 |
| 9.4 | LocalStackSlotPass::runOnMachineFunction | 仅要求virtual base registers的目标工作；PEI最终消FI；32位LDP/STP编码单位与字节范围区别。 |
| 9.5 | DeadMachineInstructionElim.cpp:105 | 修用途计数方向；实际重复清理至不动点。 |
| 9.6，清单9-9～9-16 | SSAIfConv::canConvertIf/canSpeculateInstrs | 修goto漏跳过else、Label拼写、物理寄存器$edi、JCC隐式使用eflags、最终单块无successors；MIR标为说明性片段。 |
| 9.7，清单9-17 | MachineLICMBase::IsLICMCandidate | 经典支配条件不是所有实现必需；补推测安全、别名和收益限制。 |
| 9.8，清单9-18/图9-10～9-11 | MachineCSE / 原页239人工读取 | 补全图版缺失页代码；i32*/i64*改ptr；修%7来源和32算术值，说明CSE可能增压。 |
| 9.9 | MachineSinking::SinkInstruction | 核查寄存器用途、convergent、NULL Check、收益与关键边处理；候选还包括非CFG直接后继的支配树子节点，并非只限直接后继。 |
| 9.10～9.11 | PeepholeOptimizer.cpp | 逐项对照各钩子；修select/比较/load转换的目标和内存依赖边界。 |

## 证据定位

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

## 限制

- 算法讲解、手写伪代码和原书截图已与实现边界区分；本次不声称编译通过或获得示例输出。
- LLVM IR 已修复可静态确认的语法/版本问题，完整解析、MIR verifier、Pass触发、汇编字节和性能留待后续。
- 源码中的目标钩子、功能属性和选项会改变具体流水线，通用 Pass 次序不能当作所有目标的无条件次序。
