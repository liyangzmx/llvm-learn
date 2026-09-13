# 第 8 章源码与实验核查记录

基准是 LLVM 18.1.8，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`，原书基于 15.0.1。本轮重写 8.1～8.12 及其原有子节，保留全部 14 个清单标识。历史 X86 DAG、RISC-V 压力表和 Hexagon 局部日志均被完整输入及本轮输出替换，示意图改为 Mermaid。

[完整 runner](../experiments/ch8/runner.py) 已使用统一新构建完成 19 项检查，细节见 [experiments-ch8.json](experiments-ch8.json)。每个 IR 输入通过 opt verifier，llc 运行启用 machine verifier；Hexagon 实际执行 FileCheck。报告记录工作区 tracked 修改，BPF 观察是本地树构建的结果。

| 清单 | 当前内容与判断 | 源码及实际实验依据 |
|---|---|---|
| 8-1 | 原缺输入的 X86 DAG 改为完整 BPF dependencies.ll；六种 DAG 调度器都运行成功 | `dag-linearize/fast/list-burr/source/list-hybrid/list-ilp`；[ScheduleDAGFast.cpp](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/ScheduleDAGFast.cpp:46) |
| 8-2 | CSRrr itinerary 节选置于可独立解析的教学 target 中；TimeInc 从阶段开始计算 | `tablegen-model`；[TargetItinerary.td](/opt/llvm-project/llvm/include/llvm/Target/TargetItinerary.td:56) |
| 8-3 | WriteRes/ReadAdvance/资源齐备，明确没有注册真实后端 | `sched-model-read-advance`；[TargetSchedModel::computeOperandLatency](/opt/llvm-project/llvm/lib/CodeGen/TargetSchedule.cpp:173) |
| 8-4 | ADD→MUL 伪汇编加对应 SchedRW；producer 写延迟 2 减 reader advance 1 | 同上，TableGen JSON 检查 DemoMUL 的 `[MULOut, EXIn, OrdinaryRead]`；不是 MUL latency4−1 |
| 8-5 | ALUrr itinerary 对照，与完整文件一致 | `schedule-model.td`、`tablegen-model` |
| 8-6 | 原计算式完整 C，前端与后端 CPU 都固定 E31，RV32IM/ilp32 | `clang-pressure`、`verify-pressure` |
| 8-7 | 改为 LLVM18 真实 pre-RA MIR，ADD/MUL 正确；小区域实际未追踪压力 | `rv32-opcodes-before/after`、`rv32-small-region-policy`；另加 `pressure-large.c` 观察启用追踪 |
| 8-8 | 完整 postra.c，说明 O2 代数合并及 C 有符号溢出边界 | `clang-postra`、`verify-postra` |
| 8-9 | 实际 TDList 后物理 MIR，另运行 postmisched 作对照 | `rv32-post-tdlist`、`rv32-post-misched`；[PostRASchedulerList](/opt/llvm-project/llvm/lib/CodeGen/PostRASchedulerList.cpp:54) |
| 8-10 | 完整串行 Python 示例，A_i/B_i 的语义明确 | `models.py` 中 65 种 N 对照 |
| 8-11 | 完整流水结构，含 N=0、prologue/kernel/epilogue | 同上；两个独立单元/issue≥2/无跨迭代依赖是假设，不是 LLVM 自动推断 |
| 8-12 | 完整 Hexagon 上游 IR，声明、属性、TBAA 均保留 | `verify-sms`；[swp-bad-sched.ll](/opt/llvm-project/llvm/test/CodeGen/Hexagon/swp-bad-sched.ll:1) |
| 8-13 | pipeliner 前的真实完整 MIR body | `hexagon-sms-before`，完整 YAML 保存在运行目录 |
| 8-14 | pipeliner 后真实 MIR；成功的小循环与失败的大循环分别说明 | `hexagon-pipeliner-changes-mir`、`hexagon-sms-regression`、`hexagon-filecheck` |

| 正文主题 | 修正与实际观察 | 源码依据 |
|---|---|---|
| DAG / MIR / post-RA 不同调度阶段 | `-pre-RA-sched` 不是 MachineScheduler 选项；Fast 调度不是 FastISel | [DAG 注册](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/ScheduleDAGFast.cpp:35)、[RRList 注册](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/ScheduleDAGRRList.cpp:68) |
| EntryToken | 修复旧校订引入的“没有 glue”；实际是 ch,glue 两结果 | [构造器](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/SelectionDAG.cpp:1319)，第7章实际日志 |
| Linearize | 统计 uses、glue 代表、从 DAG root 构造后逆序发射，不把 root 当源点 | [Schedule/EmitSchedule](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/ScheduleDAGFast.cpp:716) |
| Fast | SmallVector push/pop 是 LIFO；物理冲突的复制/克隆有条件 | [FastPriorityQueue](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/ScheduleDAGFast.cpp:46)、[ListScheduleBottomUp](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/ScheduleDAGFast.cpp:534) |
| BURR / Source / Hybrid / ILP | 不再由单一 Height/Latency 指标推断优先级；树 Sethi-Ullman 只作简化模型 | [BURRSort](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/ScheduleDAGRRList.cpp:2541)、[Source/Hybrid](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/ScheduleDAGRRList.cpp:2653) |
| 拓扑 vs 延迟 | L/M/A/S 的单发射开始周期 0/4/5/7；80 个小图拓扑序压力范围 3～4 | `models.py` 穷举和约束检查；不是 LLVM 调度器重新实现 |
| MIR 依赖 | BPF 实际有 Data、Memory、Out 边；分配前 TwoAddress 也会重复定义虚拟寄存器 | `bpf-mir-dependencies`；[ScheduleDAGInstrs](/opt/llvm-project/llvm/lib/CodeGen/ScheduleDAGInstrs.cpp) |
| 区域边界及策略 | 分界由 TII/目标决定；候选比较是有次序的规则链，cycle 不等于指令数 | [isSchedulingBoundary](/opt/llvm-project/llvm/lib/CodeGen/TargetInstrInfo.cpp:1315)、[tryCandidate](/opt/llvm-project/llvm/lib/CodeGen/MachineScheduler.cpp:3492) |
| 压力开关 | 原例 14 条区域指令 ShouldTrackPressure=0；四项点积 18 条为1 | [initPolicy](/opt/llvm-project/llvm/lib/CodeGen/MachineScheduler.cpp:3241)；`-misched-regpressure=true` 不强行绕过大小启发式 |
| 压力集 | BPF 的 i64 GPR 值可记入名叫 GPR32 的压力集；RV32 初始压力同时有 GPRC/GPRC_with_SR07/GPRTC/GPR | `bpf-mir-dependencies`、`rv32-large-region-pressure`；[RegisterPressure.h](/opt/llvm-project/llvm/include/llvm/CodeGen/RegisterPressure.h:140) |
| 初始与最终压力 | 记录的 Max Pressure 是调度前扫描；不把任意 Bottom Pressure 行当作最终压力表 | `rv32-pressure-large.stderr`；正文明确观察点 |
| 延迟来源 | BPF DAG load 边1、MIR load边4是各阶段模型；RISC-V 固定前后端同CPU，避免 IR target-cpu 覆盖误归因 | [ScheduleDAGSDNodes](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/ScheduleDAGSDNodes.cpp:649)、[TargetSchedule](/opt/llvm-project/llvm/lib/CodeGen/TargetSchedule.cpp:173) |
| Post-RA 实现 | 两组选项互斥；physical MIR 都通过 verifier，无性能优劣推断 | [PostRASchedulerList](/opt/llvm-project/llvm/lib/CodeGen/PostRASchedulerList.cpp:54)、[PostMachineScheduler](/opt/llvm-project/llvm/lib/CodeGen/MachineScheduler.cpp:277) |
| SMS 下界 | 数学 RecMII 与源码支持范围分开；LLVM18 getDistance 只返回0/1，calculateRecMII 当前用Distance=1 | [getDistance](/opt/llvm-project/llvm/include/llvm/CodeGen/MachinePipeliner.h:262)、[calculateRecMII](/opt/llvm-project/llvm/lib/CodeGen/MachinePipeliner.cpp:1548) |
| SMS 资源和安排 | DFA/资源模型两条路径；ASAP max、ALAP min，窗口交集，有限II搜索 | [ResourceManager](/opt/llvm-project/llvm/lib/CodeGen/MachinePipeliner.cpp:3635)、[computeNodeFunctions](/opt/llvm-project/llvm/lib/CodeGen/MachinePipeliner.cpp:1814)、[computeStart](/opt/llvm-project/llvm/lib/CodeGen/MachinePipeliner.cpp:2860) |
| SMS 实际结果 | b7 小循环 rec2/res3，II3 成功；b3 展开循环 MII10，至II20未找到安排 | `hexagon-sms.stderr` 和 FileCheck；不把搜索失败当作不可行证明 |

未覆盖：目标硬件执行、性能测量、所有物理寄存器冲突分支、所有目标调度模型和任意循环的语义验证。LLVM verifier/FileCheck 检查具体性质，数学模型按显式假设工作；这些限制已在正文对应位置写明，没有以历史输出替代实验。
