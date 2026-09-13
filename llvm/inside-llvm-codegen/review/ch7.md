# 第 7 章源码与实验核查记录

原始教材基于 LLVM 15.0.1。本轮以 LLVM 18.1.8（提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`）重新组织全部正文，保留 7.1～7.5、7.2/7.4 的所有子节以及清单 7-1～7-35。原始材料保存在 origin，本章不再依赖无法重现的历史节点编号或错误图片；流程改为 Mermaid。

已使用统一新构建运行 [runner](../experiments/ch7/runner.py)，完整范围 20 项检查通过；命令和具体结果见 [experiments-ch7.json](experiments-ch7.json)。LLVM 工作区存在用户和构建修复相关修改，JSON 记录其 tracked 文件列表；我们没有据当前工作区实验宣称运行了完全干净的上游源码，也未修改 LLVM 文件。

| 清单 | 当前内容与判断 | 本地源码依据 / 实验证据 |
|---|---|---|
| 7-1 | 完整 C，指定 BPF v1；long64/int32 | `clang-callee`、`verify-callee`；[BPF LowerCall](/opt/llvm-project/llvm/lib/Target/BPF/BPFISelLowering.cpp:404) |
| 7-2 | 改为本轮 Clang 函数输出；保留 i32 返回、trunc、nsw 和四字节对象 | `callee-finalize`、`caller-i32-object`；[PromoteIntRes_LOAD](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/LegalizeIntegerTypes.cpp:854) |
| 7-3 | 改为输入齐备的 choose IR，volatile 读保留分支 | `verify-selection`；[FunctionLoweringInfo](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/FunctionLoweringInfo.cpp:272) |
| 7-4 | 本轮 MIR 的真实 PHI，明确尚未 PHI 消除 | `machine-phi-survives-isel`；同上 |
| 7-5 | 完整 signext i16 IR + 真实 v1 两次移位 | `signed-i16-expansion`；[BPF 类型和操作动作](/opt/llvm-project/llvm/lib/Target/BPF/BPFISelLowering.cpp:77) |
| 7-6 | 变量双精度除法确实触发 __divdf3 不支持，预期返回 1 | `softfloat-libcall-diagnostic`；[BPF LowerCall](/opt/llvm-project/llvm/lib/Target/BPF/BPFISelLowering.cpp:404) |
| 7-7 | 本地重新生成 ADD matcher；FI_ri 优先候选及 i64/i32 分支 | `tablegen-bpf`；[SelectCodeCommon](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/SelectionDAGISel.cpp:3051) |
| 7-8 | 改用实际 add_reg DAG，两个输入/一个值结果 | `bpf-v1.stderr`；同上 |
| 7-9 | 改用本轮匹配日志；偏移仅本次观察 | `pattern-register`、`pattern-immediate`；同上 |
| 7-10 | 真实 callee Selected DAG，保留 ch/glue | `callee-finalize.stderr`；[InstrEmitter](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/InstrEmitter.cpp:971) |
| 7-11 | 真实 callee MIR body；不是完整 YAML | `callee-finalize.mir`；[EmitSpecialNode](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/InstrEmitter.cpp:1202) |
| 7-12 | AddSub 定义入口节选，指出 ADDXrr 是 codegen pseudo | [AArch64InstrInfo.td](/opt/llvm-project/llvm/lib/Target/AArch64/AArch64InstrInfo.td:2008)、[BaseAddSubRegPseudo](/opt/llvm-project/llvm/lib/Target/AArch64/AArch64InstrFormats.td:2814) |
| 7-13 | 记录关键字段的阅读投影，不冒充完整生成记录 | 同上；Xrr 实例在 [2923](/opt/llvm-project/llvm/lib/Target/AArch64/AArch64InstrFormats.td:2923) |
| 7-14 | 实际重新生成的 i64 fast emitter | `tablegen-fast`、`generated-fast-emitter` |
| 7-15 | 精确引用公共 C++ 函数，源码片段依赖内部上下文 | [FastISel.cpp](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/FastISel.cpp:2026)；`fastisel-without-fallback` |
| 7-16 | C add32 函数有独立文件并经前端检查 | `globalisel.c`、`clang-globalisel`、`verify-globalisel-from-c` |
| 7-17 | 完整固定 add32 IR，使用 nsw | `verify-globalisel`、四个 `gi-*` 命令 |
| 7-18 | 临时 EntryBB 的构造过程示意，不是 Pass dump | [IRTranslator::runOnMachineFunction](/opt/llvm-project/llvm/lib/CodeGen/GlobalISel/IRTranslator.cpp:3634) |
| 7-19 | 预建块和临时入口关系，使用符号名避免伪造编号 | 同上 |
| 7-20 | AArch64 w0/w1 形参 COPY 的内部过程示意 | 同上；最终观察在清单 7-23 |
| 7-21 | G_ADD 构造，明确 nsw 沿用 IR 语义 | 同上 |
| 7-22 | 返回 lowering 与目标 RET 伪指令的混合形态 | 同上 |
| 7-23 | 用真实 irtranslator MIR 替换旧推测日志 | `gi-irtranslator.mir` |
| 7-24 | 真实 s16 G_ADD 输入及 ABI G_TRUNC/ANYEXT | `irtranslator-llt-s16` |
| 7-25 | 真实合法化结果：s16 加法消失，保留 s32 G_ADD | `legalizer-widens-s16`；[AArch64LegalizerInfo](/opt/llvm-project/llvm/lib/Target/AArch64/GISel/AArch64LegalizerInfo.cpp:125) |
| 7-26 | TRUNC/ANYEXT 低位关系示意；明确不是任意扩展都能消除 | [Legalizer artifact](/opt/llvm-project/llvm/lib/CodeGen/GlobalISel/Legalizer.cpp:99) |
| 7-27 | 六个有代表性的位向量检查及 ZEXT/SEXT 反例 | `models.py`、`teaching-bit-vectors-and-costs`；不是完整 poison/undef 模型 |
| 7-28 | C or32 函数编译并验证 | `globalisel.c`、`clang-globalisel` |
| 7-29 | 本轮 legalizer 后、bank 前的 or32 | `gi-legalizer.mir` |
| 7-30 | 完整三条 bank 定义，bank 与 class 分开 | [AArch64RegisterBanks.td](/opt/llvm-project/llvm/lib/Target/AArch64/AArch64RegisterBanks.td:13) |
| 7-31 | 两候选映射的源码投影，说明 32/64 和操作数个数条件 | [getInstrAlternativeMappings](/opt/llvm-project/llvm/lib/Target/AArch64/GISel/AArch64RegisterBankInfo.cpp:300) |
| 7-32 | 替换不可复现的 8/8/72；明确假设下 GPR=1、FPR=14 | `models.py`；[copyCost](/opt/llvm-project/llvm/lib/Target/AArch64/GISel/AArch64RegisterBankInfo.cpp:218)，参数为目的/来源 |
| 7-33 | 真实 gpr(s32) 输出，不误写为寄存器类 gpr32 | `bank-not-register-class` |
| 7-34 | LLVM 18 GINodeEquiv 完整类，包含原子性/扩展/浮点/convergent 条件 | [SelectionDAGCompat.td](/opt/llvm-project/llvm/include/llvm/Target/GlobalISel/SelectionDAGCompat.td:22) |
| 7-35 | opcode 对应声明及本轮 ADDWrr 结果 | `selected-target-opcode`；同上 |

正文重点修正：

- **EntryToken 有两个结果**：上一轮静态校订把它改成只有 chain，这是校订引入的错误。本轮用 [SelectionDAG 构造器](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/SelectionDAG.cpp:1319) 和真实 `ch,glue` 日志纠正；`getEntryNode()` 只是取结果 0。
- 合法化区分类型动作与操作动作；BPF v1/v3 实测表明寄存器变宽不扩大 i32 访存。额外输入检查 i128 两半和向量标量化，未删除进位或混淆 lane。
- [CodeGenAndEmitDAG](/opt/llvm-project/llvm/lib/CodeGen/SelectionDAG/SelectionDAGISel.cpp:778) 的向量/类型再次合法化关系与条件，替换为准确图示；不把 CodeGenPrepare 简化为元数据处理。
- FastISel 以 abort=3 明确禁止回退；GlobalISel 以 abort=1 明确禁止失败后改走 SelectionDAG。分别证明本例路径，不能推广到所有输入。
- GMIR/MIR 共用 MachineFunction 对象，LLT/bank/class/物理分配分阶段；GI 块遍历、指令逆序选择和回退边界依据 [InstructionSelect](/opt/llvm-project/llvm/lib/CodeGen/GlobalISel/InstructionSelect.cpp:140)。
- AArch64 O0 仍有 combiner/Localizer/lowering；完整阶段图按 [AArch64PassConfig](/opt/llvm-project/llvm/lib/Target/AArch64/AArch64TargetMachine.cpp:698) 重画。

剩余边界：没有目标硬件执行或性能基准；中间构造清单、cost 示例和位向量模型仅验证明确说明的性质。对完整 LLVM poison/undef、所有 ABI 输入或任意 matcher 最优性没有作额外保证。没有需要靠保留旧输出才能理解的技术结论。
