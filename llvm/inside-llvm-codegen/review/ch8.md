# 第 8 章静态核查记录

本章逐页阅读并覆盖所有编号清单。原书 LLVM 15.0.1；基准为本地 LLVM 18.1.8，HEAD `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。只读源码与文档，未编译 LLVM，未执行示例、TableGen、lit 或 FileCheck。

| 清单 | 涉及实现 | LLVM 18 源码证据 | 结论 / 修订 |
|---|---|---|---|
| 8-1 | X86 DAG复杂片段 | [`llvm/lib/CodeGen/SelectionDAG/ScheduleDAGFast.cpp:46`](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/ScheduleDAGFast.cpp:46)（`struct FastPriorityQueue`） | 逐节点检查转储形态；修正EntryToken无glue、全角标点、序列反转，解释重复t46为clone。缺原始输入不能重现该dump。 |
| 8-2 | InstrItinData / InstrStage | [`llvm/include/llvm/Target/TargetItinerary.td:56`](/opt/llvm-project/llvm/include/llvm/Target/TargetItinerary.td:56)（`class InstrStage`） | 修复闭合括号/模板语法，TimeInc从stage开始计时。引用类仍需目标定义。 |
| 8-3 | WriteRes / SchedReadAdvance | [`llvm/lib/CodeGen/TargetSchedule.cpp:173`](/opt/llvm-project/llvm/lib/CodeGen/TargetSchedule.cpp:173)（`unsigned TargetSchedModel::computeOperandLatency(`） | 片段语法与模型机制一致；必须给指令关联SchedRW和EXIn才能产生边时延。 |
| 8-4 | ADD→MUL汇编示意 | [`llvm/lib/CodeGen/TargetSchedule.cpp:173`](/opt/llvm-project/llvm/lib/CodeGen/TargetSchedule.cpp:173)（`unsigned TargetSchedModel::computeOperandLatency(`） | r3数据依赖成立；作为目标无关假设示例，不当某后端可汇编文件。 |
| 8-5 | ALUrr行程定义 | [`llvm/include/llvm/Target/TargetItinerary.td:56`](/opt/llvm-project/llvm/include/llvm/Target/TargetItinerary.td:56)（`class InstrStage`） | 补完整def : InstrItinData形式；操作数周期与bypass影响依赖时延。 |
| 8-6 | 寄存器压力C++源码 | [`llvm/include/llvm/CodeGen/RegisterPressure.h:140`](/opt/llvm-project/llvm/include/llvm/CodeGen/RegisterPressure.h:140)（`class PressureDiff`） | 完整保留；命令补RV32IM、ABI及IR输出用途。 |
| 8-7 | RV32寄存器压力MIR | [`llvm/lib/Target/RISCV/RISCVInstrInfoM.td:49`](/opt/llvm-project/llvm/lib/Target/RISCV/RISCVInstrInfoM.td:49)（`let Predicates = [HasStdExtMOrZmmul, IsRV64]`） | 修正RV64专属ADDW/MULW为RV32 ADD/MUL；SU标注、缺MIR头使之仍为片段。 |
| 8-8 | g_val / MUL C++源码 | [`llvm/lib/Target/RISCV/RISCVInstrInfoM.td:49`](/opt/llvm-project/llvm/lib/Target/RISCV/RISCVInstrInfoM.td:49)（`let Predicates = [HasStdExtMOrZmmul, IsRV64]`） | 保留代数表达，明确需显式选择post-RA调度器。 |
| 8-9 | post-RA MIR | [`llvm/lib/Target/RISCV/RISCVInstrInfoM.td:49`](/opt/llvm-project/llvm/lib/Target/RISCV/RISCVInstrInfoM.td:49)（`let Predicates = [HasStdExtMOrZmmul, IsRV64]`） | 统一RV32 ADD/MUL，补riscv-hi/lo与implicit返回；结果重排及CPU时延仍待运行。 |
| 8-10 | 流水化前伪代码 | [`llvm/lib/CodeGen/MachinePipeliner.cpp:1814`](/opt/llvm-project/llvm/lib/CodeGen/MachinePipeliner.cpp:1814)（`void SwingSchedulerDAG::computeNodeFunctions`） | 改为显式N次迭代及按迭代索引命名的值，明确跨迭代无依赖假设。 |
| 8-11 | 流水化后伪代码 | [`llvm/lib/CodeGen/MachinePipeliner.cpp:1814`](/opt/llvm-project/llvm/lib/CodeGen/MachinePipeliner.cpp:1814)（`void SwingSchedulerDAG::computeNodeFunctions`） | 加N>0保护、准确迭代边界与epilogue，避免原伪代码可能多执行一次。 |
| 8-12 | Hexagon f0完整IR | [`llvm/test/CodeGen/Hexagon/swp-bad-sched.ll:17`](/opt/llvm-project/llvm/test/CodeGen/Hexagon/swp-bad-sched.ll:17)（`define void @f0`） | 定位上游完整测试并逐条对照；使用本地相同函数/声明/属性/TBAA正文，补RUN中的experimental-cg选项。未执行测试。 |
| 8-13 | SMS前局部MIR | [`llvm/lib/CodeGen/MachinePipeliner.cpp:1814`](/opt/llvm-project/llvm/lib/CodeGen/MachinePipeliner.cpp:1814)（`void SwingSchedulerDAG::computeNodeFunctions`） | PHI、load/store、abs/or、硬件loop形态与IR对照；所引其他块未展示，标记局部历史输出。 |
| 8-14 | SMS后局部MIR | [`llvm/lib/CodeGen/MachinePipeliner.cpp:1814`](/opt/llvm-project/llvm/lib/CodeGen/MachinePipeliner.cpp:1814)（`void SwingSchedulerDAG::computeNodeFunctions`） | 修正标题MIR；保留prologue/kernel/epilogue及PHI，明确具体编号/II未重现。 |

## 调度器、公式及模型核查

| 范围 | LLVM 18 源码证据 | 修订结论 |
|---|---|---|
| Linearize | [ScheduleDAGFast.cpp:670](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/ScheduleDAGFast.cpp:670)、[EmitSchedule:771](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/ScheduleDAGFast.cpp:771) | 从 DAG 实际根开始，收集 Sequence 后逆序发射。源码警告物理寄存器依赖可能不适用。 |
| Fast | [FastPriorityQueue:47](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/ScheduleDAGFast.cpp:47)、[ListScheduleBottomUp:534](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/ScheduleDAGFast.cpp:534) | 队列实为 LIFO；当前字段是 LiveRegDefs / LiveRegCycles。克隆/COPY 用于修复活跃物理寄存器冲突，先查跨类复制能力，不总是优先克隆。 |
| BURR | [BURRSort:2541](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/ScheduleDAGRRList.cpp:2541) | 修正动态前驱/后继计数名称及含义；高度/深度使用边时延，后备比较倾向小 Height / 大 Depth；特殊节点、调用与就绪状态优先。 |
| Source / Hybrid | [src_ls_rr_sort:2653](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/ScheduleDAGRRList.cpp:2653)、[hybrid_ls_rr_sort:2687](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/ScheduleDAGRRList.cpp:2687) | 原算法框架一致；Hybrid 并非仅比较节点 Latency 大小。 |
| Pre-RA MIR 调度 | [initPolicy:3241](/opt/llvm-project/llvm/lib/CodeGen/MachineScheduler.cpp:3241)、[tryCandidate:3492](/opt/llvm-project/llvm/lib/CodeGen/MachineScheduler.cpp:3492)、[releaseNode:2512](/opt/llvm-project/llvm/lib/CodeGen/MachineScheduler.cpp:2512) | 半寄存器文件的阈值是默认启发式，可被目标/选项覆盖；ReadyCycle / CurrCycle 受发射与资源影响，不等于指令条数。 |
| 调度区间 | [MachineScheduler.cpp:497](/opt/llvm-project/llvm/lib/CodeGen/MachineScheduler.cpp:497)、[TargetInstrInfo.cpp:1315](/opt/llvm-project/llvm/lib/CodeGen/TargetInstrInfo.cpp:1315) | 调用、terminator、position、INLINEASM_BR、栈指针定义等可构成边界；原书三类不是穷尽清单。 |
| 寄存器压力 | [RegisterPressure.h:140](/opt/llvm-project/llvm/include/llvm/CodeGen/RegisterPressure.h:140)、[MachineScheduler.cpp:1275](/opt/llvm-project/llvm/lib/CodeGen/MachineScheduler.cpp:1275)、[1322](/opt/llvm-project/llvm/lib/CodeGen/MachineScheduler.cpp:1322) | pressure set 不等同寄存器类，PressureDiff 是稀疏摘要，RegionCriticalPSets 为稀疏集合；修正固定11列数组/通用32位权重假设。保留历史表格并标明范围。 |
| Post-RA TDList / MISched | [PostRASchedulerList.cpp:54](/opt/llvm-project/llvm/lib/CodeGen/PostRASchedulerList.cpp:54)、[MachineScheduler.cpp:3860](/opt/llvm-project/llvm/lib/CodeGen/MachineScheduler.cpp:3860)、[资源增量:2931](/opt/llvm-project/llvm/lib/CodeGen/MachineScheduler.cpp:2931) | 补显式启用选项；Critical/Demanded是策略资源索引的占用，不是区间内/跨区间的区别；8.11将pre/post压力侧重点写反，已修正。 |
| SMS 循环筛选 | [canPipelineLoop:353](/opt/llvm-project/llvm/lib/CodeGen/MachinePipeliner.cpp:353) | 单块、pragma、分支分析、循环专用分析和preheader检查一致；目标/资源条件仍决定是否成功。 |
| SMS ResMII | [calculateResMII:3635](/opt/llvm-project/llvm/lib/CodeGen/MachinePipeliner.cpp:3635) | LLVM18支持DFA及调度资源模型计数路径；ResMII还包括微操作与IssueWidth下界。 |
| SMS ASAP / ALAP | [computeNodeFunctions:1814](/opt/llvm-project/llvm/lib/CodeGen/MachinePipeliner.cpp:1814) | 修正ALAP为对后继取min，以maxASAP初始化；ASAP/ALAP使用边时延及跨迭代距离，后者不是周期时延。 |
| SMS 选点 / 展开 | [MachinePipeliner.cpp:2412](/opt/llvm-project/llvm/lib/CodeGen/MachinePipeliner.cpp:2412)、[SMSchedule::computeStart:2860](/opt/llvm-project/llvm/lib/CodeGen/MachinePipeliner.cpp:2860) | 前后驱均已调度时取窗口交集；II搜索有界；stage按相对FirstCycle计算；prologue/epilogue可能有多个块。 |

## 未验证范围

未编译 LLVM，未运行 llc/Clang、IR/MIR parser、lit、FileCheck，也没有新生成或测量任何时延/压力/性能结果。具体 SUnit 编号、依赖图节点顺序、默认 CPU 模型、II=3、各周期结果、最终指令输出和论文图的性能数据只保留为原书示例，需后续固定环境复现。
