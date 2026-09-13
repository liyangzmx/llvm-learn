# 第 7 章静态核查记录

本章逐页阅读并覆盖所有编号清单。原书 LLVM 15.0.1；基准为本地 LLVM 18.1.8，HEAD `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。只读源码与文档，未编译 LLVM，未执行示例、TableGen、lit 或 FileCheck。

BPF 工作区有用户改动：BPF.td、BPFCallingConv.td、BPFInstrFormats.td、BPFInstrInfo.td、BPFMIChecking.cpp、BPFRegisterInfo.td、GISel/BPFRegisterBanks.td。本章凡涉及这些定义均通过 `git show HEAD:路径` 检查上游基线；没有覆盖或修改工作区文件。相关本地文件链接可能展示用户版本，应按该提交追溯。

| 清单 | 涉及实现 | LLVM 18 源码证据 | 结论 / 修订 |
|---|---|---|---|
| 7-1 | C：callee / caller | [`llvm/lib/Target/BPF/BPFISelLowering.cpp:404`](/opt/llvm-project/llvm/lib/Target/BPF/BPFISelLowering.cpp:404)（`SDValue BPFTargetLowering::LowerCall(`） | 保留源码；函数中 long 以指定 BPF target 为 64 位，补明确 triple / CPU 的 IR 命令。 |
| 7-2 | LLVM IR 与 nsw / 调用约定 | [`llvm/lib/CodeGen/SelectionDAG/LegalizeIntegerTypes.cpp:854`](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/LegalizeIntegerTypes.cpp:854)（`SDValue DAGTypeLegalizer::PromoteIntRes_LOAD`） | 完整保留 IR；修正 nsw=poison 语义、首参 r1、caller IR 仍返回 i32、i32 访存宽度不随 Promote 扩大。 |
| 7-3 | PHI IR 片段 | [`llvm/lib/CodeGen/SelectionDAG/FunctionLoweringInfo.cpp:272`](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/FunctionLoweringInfo.cpp:272)（`for (const PHINode &PN : BB.phis())`） | 补 [66, %if.then] 中遗漏的逗号，明确只是片段。 |
| 7-4 | 机器 PHI | [`llvm/lib/CodeGen/SelectionDAG/FunctionLoweringInfo.cpp:272`](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/FunctionLoweringInfo.cpp:272)（`for (const PHINode &PN : BB.phis())`） | 模式一致；修正为预创建 PHI、逐块补齐操作数。 |
| 7-5 | int16_t 加法 / sign_extend_inreg | [`llvm/lib/CodeGen/SelectionDAG/LegalizeIntegerTypes.cpp:854`](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/LegalizeIntegerTypes.cpp:854)（`SDValue DAGTypeLegalizer::PromoteIntRes_LOAD`） | 补 stdint.h；左移48再算术右移48的解释正确，是否出现符号扩展取决于ABI。 |
| 7-6 | double 除法 / libcall | [`llvm/include/llvm/IR/RuntimeLibcalls.def:106`](/opt/llvm-project/llvm/include/llvm/IR/RuntimeLibcalls.def:106)（`HANDLE_LIBCALL(DIV_F64`） | 修正 __divdf3；说明函数体片段及常量折叠可能。BPF builtin ExternalSymbol 被 LowerCall 拒绝，不能声称软浮点已成功生成。 |
| 7-7 | MatcherTable 历史字节码 | [`llvm/lib/CodeGen/SelectionDAG/SelectionDAGISel.cpp:3051`](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/SelectionDAGISel.cpp:3051)（`void SelectionDAGISel::SelectCodeCommon`） | 逐段核对opcode、scope、check、emit语义；纠正case数量、子表长度、子节点索引、成功提交条件、状态机定位；旧偏移未重生成。 |
| 7-8 | ADD DAG 输入 | [`llvm/lib/CodeGen/SelectionDAG/SelectionDAGISel.cpp:3051`](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/SelectionDAGISel.cpp:3051)（`void SelectionDAGISel::SelectCodeCommon`） | 保留 t35/t36/t37；改为两输入一结果，不能把结果算第0输入。 |
| 7-9 | 匹配日志 | [`llvm/lib/CodeGen/SelectionDAG/SelectionDAGISel.cpp:3051`](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/SelectionDAGISel.cpp:3051)（`void SelectionDAGISel::SelectCodeCommon`） | 保存LLVM15历史路径；说明与当前生成表偏移无稳定对应。 |
| 7-10 | callee 已选择 DAG | [`llvm/lib/CodeGen/SelectionDAG/InstrEmitter.cpp:971`](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/InstrEmitter.cpp:971)（`EmitMachineNode(SDNode *Node`） | 一致的STD/LDD/ADD_rr示意，修复标题func/callee；明确TokenFactor不发射为真实机器指令。 |
| 7-11 | callee MIR 调试转储 | [`llvm/lib/CodeGen/SelectionDAG/InstrEmitter.cpp:971`](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/InstrEmitter.cpp:971)（`EmitMachineNode(SDNode *Node`） | 保留完整机器指令，明确 tied-def 标注不是可独立解析的MIR YAML。 |
| 7-12 | ADDXrr TD片段 | [`llvm/lib/Target/AArch64/AArch64InstrInfo.td:2008`](/opt/llvm-project/llvm/lib/Target/AArch64/AArch64InstrInfo.td:2008)（`defm ADD : AddSub<`） | 类与defm仍存在；省略号保持为节选标记，不称完整可编译TD。 |
| 7-13 | ADDXrr 展开记录 | [`llvm/lib/Target/AArch64/AArch64InstrInfo.td:2008`](/opt/llvm-project/llvm/lib/Target/AArch64/AArch64InstrInfo.td:2008)（`defm ADD : AddSub<`） | 修正 Namespace=AArch64；是记录节选。 |
| 7-14 | 生成的fastEmit匹配形态 | [`llvm/utils/TableGen/FastISelEmitter.cpp:711`](/opt/llvm-project/llvm/utils/TableGen/FastISelEmitter.cpp:711)（`OS << "unsigned fastEmit_"`） | 修正命名空间，解释上层输入分派，未重新生成inc。 |
| 7-15 | FastISel::fastEmitInst_rr | [`llvm/lib/CodeGen/SelectionDAG/FastISel.cpp:2026`](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/FastISel.cpp:2026)（`Register FastISel::fastEmitInst_rr(`） | 替换为本地LLVM18完整函数体，澄清公共实现而不是AArch64单独实现。 |
| 7-16 | test加法C函数 | [`llvm/lib/CodeGen/GlobalISel/IRTranslator.cpp:3634`](/opt/llvm-project/llvm/lib/CodeGen/GlobalISel/IRTranslator.cpp:3634)（`bool IRTranslator::runOnMachineFunction`） | 保留；补 emit-llvm 命令与独立GMIR观察入口。 |
| 7-17 | test LLVM IR | [`llvm/lib/CodeGen/GlobalISel/IRTranslator.cpp:3634`](/opt/llvm-project/llvm/lib/CodeGen/GlobalISel/IRTranslator.cpp:3634)（`bool IRTranslator::runOnMachineFunction`） | 修正不可解析的 @test(int,int)(...) 为 @test(...)。 |
| 7-18 | 空EntryBB | [`llvm/lib/CodeGen/GlobalISel/IRTranslator.cpp:3634`](/opt/llvm-project/llvm/lib/CodeGen/GlobalISel/IRTranslator.cpp:3634)（`bool IRTranslator::runOnMachineFunction`） | 静态调用链存在；中间状态示意。 |
| 7-19 | EntryBB及函数块 | [`llvm/lib/CodeGen/GlobalISel/IRTranslator.cpp:3634`](/opt/llvm-project/llvm/lib/CodeGen/GlobalISel/IRTranslator.cpp:3634)（`bool IRTranslator::runOnMachineFunction`） | 保留控制流构建示意；编号不稳定。 |
| 7-20 | 形参COPY | [`llvm/lib/CodeGen/GlobalISel/IRTranslator.cpp:3634`](/opt/llvm-project/llvm/lib/CodeGen/GlobalISel/IRTranslator.cpp:3634)（`bool IRTranslator::runOnMachineFunction`） | 符合AArch64形参w0/w1 lowering形态；不声明实际dump一致。 |
| 7-21 | G_ADD | [`llvm/lib/CodeGen/GlobalISel/IRTranslator.cpp:3634`](/opt/llvm-project/llvm/lib/CodeGen/GlobalISel/IRTranslator.cpp:3634)（`bool IRTranslator::runOnMachineFunction`） | 符合GMIR形成方式，nsw语义与IR一致。 |
| 7-22 | 返回COPY / RET_ReallyLR | [`llvm/lib/CodeGen/GlobalISel/IRTranslator.cpp:3634`](/opt/llvm-project/llvm/lib/CodeGen/GlobalISel/IRTranslator.cpp:3634)（`bool IRTranslator::runOnMachineFunction`） | 按调用约定发射；中间状态不独立解析。 |
| 7-23 | 入口块合并 | [`llvm/lib/CodeGen/GlobalISel/IRTranslator.cpp:3634`](/opt/llvm-project/llvm/lib/CodeGen/GlobalISel/IRTranslator.cpp:3634)（`bool IRTranslator::runOnMachineFunction`） | 对应NewEntryBB.splice，临时入口最终被删除。 |
| 7-24 | s16 G_ADD合法化输入 | [`llvm/lib/Target/AArch64/GISel/AArch64LegalizerInfo.cpp:125`](/opt/llvm-project/llvm/lib/Target/AArch64/GISel/AArch64LegalizerInfo.cpp:125)（`getActionDefinitionsBuilder({G_ADD, G_SUB`） | AArch64整数G_ADD legalFor s32/s64，s16 widen成立；ABI扩展形态需后续固定target验证。 |
| 7-25 | WidenScalar 过程 | [`llvm/lib/Target/AArch64/GISel/AArch64LegalizerInfo.cpp:125`](/opt/llvm-project/llvm/lib/Target/AArch64/GISel/AArch64LegalizerInfo.cpp:125)（`getActionDefinitionsBuilder({G_ADD, G_SUB`） | 保留扩展、加法、截断序列；新生成指令也进工作表。 |
| 7-26 | TRUNC / ANYEXT | [`llvm/lib/CodeGen/GlobalISel/Legalizer.cpp:99`](/opt/llvm-project/llvm/lib/CodeGen/GlobalISel/Legalizer.cpp:99)（`static bool isArtifact(`） | 可折叠是因ANYEXT高位无约束；改为ZEXT/SEXT一般不可同样删除。 |
| 7-27 | artifact消除结果 | [`llvm/lib/CodeGen/GlobalISel/Legalizer.cpp:99`](/opt/llvm-project/llvm/lib/CodeGen/GlobalISel/Legalizer.cpp:99)（`static bool isArtifact(`） | 保留低16位语义的示意结果，澄清artifact不能一概无条件删除。 |
| 7-28 | 按位或C函数 | [`llvm/lib/Target/AArch64/GISel/AArch64RegisterBankInfo.cpp:300`](/opt/llvm-project/llvm/lib/Target/AArch64/GISel/AArch64RegisterBankInfo.cpp:300)（`case TargetOpcode::G_OR:`） | 保留，G_OR两个bank候选实现仍存在。 |
| 7-29 | RegBankSelect前GMIR | [`llvm/lib/Target/AArch64/GISel/AArch64RegisterBankInfo.cpp:300`](/opt/llvm-project/llvm/lib/Target/AArch64/GISel/AArch64RegisterBankInfo.cpp:300)（`case TargetOpcode::G_OR:`） | 保留LLT s32与未分配bank形态。 |
| 7-30 | AArch64 RegisterBank TD | [`llvm/lib/Target/AArch64/AArch64RegisterBanks.td:13`](/opt/llvm-project/llvm/lib/Target/AArch64/AArch64RegisterBanks.td:13)（`def GPRRegBank`） | 三条定义与LLVM18文件一致；不固定寄存器类总数量。 |
| 7-31 | GPR / FPR候选映射 | [`llvm/lib/Target/AArch64/GISel/AArch64RegisterBankInfo.cpp:300`](/opt/llvm-project/llvm/lib/Target/AArch64/GISel/AArch64RegisterBankInfo.cpp:300)（`case TargetOpcode::G_OR:`） | 两个替代候选仍存在，FPR是按位或而非浮点算术。 |
| 7-32 | 成本8/8/72 | [`llvm/lib/Target/AArch64/GISel/AArch64RegisterBankInfo.cpp:218`](/opt/llvm-project/llvm/lib/Target/AArch64/GISel/AArch64RegisterBankInfo.cpp:218)（`unsigned AArch64RegisterBankInfo::copyCost`） | 在给定频率下局部演算成立；修正copy方向：GPR→FPR=4，反向=5。 |
| 7-33 | RegBankSelect后GMIR | [`llvm/lib/Target/AArch64/AArch64RegisterBanks.td:13`](/opt/llvm-project/llvm/lib/Target/AArch64/AArch64RegisterBanks.td:13)（`def GPRRegBank`） | 改 gpr32 为 gpr(s32)/gpr，明确RegisterBank和RegisterClass分阶段。 |
| 7-34 | GINodeEquiv类 | [`llvm/include/llvm/Target/GlobalISel/SelectionDAGCompat.td:22`](/opt/llvm-project/llvm/include/llvm/Target/GlobalISel/SelectionDAGCompat.td:22)（`class GINodeEquiv`） | 两个核心字段仍有，补说明LLVM18其余条件字段未展示。 |
| 7-35 | GINodeEquiv<G_ADD,add> | [`llvm/include/llvm/Target/GlobalISel/SelectionDAGCompat.td:22`](/opt/llvm-project/llvm/include/llvm/Target/GlobalISel/SelectionDAGCompat.td:22)（`class GINodeEquiv`） | 定义仍存在，静态复用关系一致。 |

## 正文算法、图示与版本差异

| 范围 | LLVM 18 证据 | 修订结论 |
|---|---|---|
| 7.1 / 7.2.3 合法化调用顺序 | [SelectionDAGISel.cpp:844](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/SelectionDAGISel.cpp:844)、[902](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/SelectionDAGISel.cpp:902)、[942](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/SelectionDAGISel.cpp:942) | 第二次类型合法化位于向量操作合法化后、普通操作合法化前，且有条件执行。 |
| nsw 与内存宽度 | [LangRef.rst:9272](/opt/llvm-project/llvm/docs/LangRef.rst:9272)、[LegalizeIntegerTypes.cpp:2185](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/LegalizeIntegerTypes.cpp:2185) | nsw 不插运行时检查；Promote 使用 extload / truncstore，不能把 i32 对象扩大读写为 i64。 |
| BPF ABI / 浮点 | [BPFISelLowering.cpp:432](/opt/llvm-project/llvm/lib/Target/BPF/BPFISelLowering.cpp:432)、[491](/opt/llvm-project/llvm/lib/Target/BPF/BPFISelLowering.cpp:491) | i32 是否合法依 ALU32；五个寄存器参数、首参 r1、r0 返回；栈参数、动态栈及自动 builtin 外部符号调用受限制。 |
| BPF SELECT_CC | [BPFISelLowering.cpp:612](/opt/llvm-project/llvm/lib/Target/BPF/BPFISelLowering.cpp:612)、[656](/opt/llvm-project/llvm/lib/Target/BPF/BPFISelLowering.cpp:656) | 无 JmpExt 时交换 SETULT 操作数并改条件为 SETUGT；常量 10 来自通用 ISD CondCode，不是 BPF 私有 ult 编号。 |
| 图 7-15 / 7-26 | [SelectionDAG.h](/opt/llvm-project/llvm/include/llvm/CodeGen/SelectionDAG.h)、[BPFISelLowering.h:26](/opt/llvm-project/llvm/lib/Target/BPF/BPFISelLowering.h:26) | 已补全图中文字并修正 EntryToken 只输出 chain、RET_GLUE 名称、%ir.c 变量；保留原 PDF 和原图裁剪以追溯。 |
| 图 7-25 | [SelectionDAGISel.cpp:3051](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/SelectionDAGISel.cpp:3051) | 加 Mermaid 表示纠正后的 ADD 匹配路径；原图 ADD_ri 成功终点误标 ADD_rr，RecordChild 并不做匹配失败判断。 |
| GI 遍历 / 失败 | [InstructionSelect.cpp:140](/opt/llvm-project/llvm/lib/CodeGen/GlobalISel/InstructionSelect.cpp:140) | 按 CFG 后序遍历块、逆序处理块内指令；失败可由配置控制回退，不能简化成所有情况直接报错。 |
| AArch64 GI Pass | [AArch64TargetMachine.cpp:698](/opt/llvm-project/llvm/lib/Target/AArch64/AArch64TargetMachine.cpp:698) | 用 Mermaid 更新具体顺序；O0 仍有 combiner / Localizer / lowering，优化 Pass 数量与位置依配置。 |

## 未验证范围

未运行任何代码；C/IR/MIR 的解析、具体 CPU 下的 ABI 与调试输出、生成表字节偏移以及性能结论留待后续。代码清单的静态语义和源码定义核对，不能替代编译运行或宣称输出逐字复现。

- 补充复核：通用 DAG 指令选择的 NP 困难性不证明每个实例必须花指数时间，已修正该推论。InstrEmitter.cpp:84、1202 的 `EmitCopyFromReg` / `EmitSpecialNode` 表明 EntryToken、TokenFactor 不发射 MI，CopyToReg / CopyFromReg 仅在需要时产生 COPY；正文已区分 DAG 依赖与 MIR 伪指令。
