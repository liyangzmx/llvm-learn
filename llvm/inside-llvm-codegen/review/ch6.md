# 第 6 章核查与实验记录

- 原书：LLVM 15.0.1。校订基线：本地 `/opt/llvm-project`，LLVM 18.1.8，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。
- 方法：基线为 LLVM 18.1.8，源码提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。全文按源码和本章实验修订；工具来自统一更新后的 Debug / assertions 构建。本文区分真实工具输出、教学算法模型和仅按源码核对的接口。
- 校订全文：[inside-llvm-codegen-ch6.md](../inside-llvm-codegen-ch6.md)。原始转写和原图裁剪保留在 origin，完整版面见原 PDF。

## 逐代码清单核查

| 清单 | LLVM 18 证据（行号以基线为准） | 结论与处理 |
| --- | --- | --- |
| 6-1 | `llvm/docs/TableGen/ProgRef.rst:164`（TokInteger:）；`llvm/lib/TableGen/TGLexer.cpp:465`（tgtok::TokKind TGLexer::LexNumber()） | 文法与 18 一致，保留；十进制可带正负号，十六进制 A–F 也合法。language.td 实际确认 -42、0x2A、0b101010 的值。 |
| 6-2 | `llvm/docs/TableGen/ProgRef.rst:176`（TokString:）；`llvm/docs/TableGen/ProgRef.rst:179`（A :token:`TokCode`） | 两类均是字符串；规范解释双引号及转义，TokCode 保留跨行换行，不在 TD 前端当 C++ 执行。 |
| 6-3 | `llvm/docs/TableGen/ProgRef.rst:194`（TokIdentifier:）；`llvm/lib/TableGen/TGLexer.cpp:337`（tgtok::TokKind TGLexer::LexIdentifier()） | 标识符与 $ 参数名文法保留，说明大小写和数字歧义；关键字补 in。 |
| 6-4 | `llvm/docs/TableGen/ProgRef.rst:336`（Value: `SimpleValue`）；`llvm/lib/TableGen/TGParser.cpp:229`（bool TGParser::SetValue(）；`llvm/lib/TableGen/TGParser.cpp:969`（bool TGParser::ParseRangePiece(） | 文法断行整理，解释部分位赋值保留其余位。a{1...3}=110 对应第 1/2/3 位为 1/1/0；只有其余位已为 0 才推出 0110。连字符范围是兼容的弃用形式。 |
| 6-5 | `llvm/lib/TableGen/TGParser.cpp:3593`（bool TGParser::ParseDef(）；`llvm/docs/TableGen/ProgRef.rst:706`（A ``def`` statement defines） | records.td 实际输出字段 a=1、b="def example"。 |
| 6-6 | `llvm/docs/TableGen/ProgRef.rst:631`（Record Bodies）；`llvm/lib/TableGen/TGParser.cpp:3450`（// LET ID OptionalRangeList） | records.td 实际确认 class/def/let 继承；高六位为1/2，低26位为未赋值；未继承 Instruction，不能当作完整机器指令。 |
| 6-7 | `llvm/lib/TableGen/TGParser.cpp:4058`（bool TGParser::ParseMultiClass()）；`llvm/lib/TableGen/TGParser.cpp:4157`（bool TGParser::ParseDefm(） | multiclass 包含两个 def 模板，defm 加名前缀；不是声明多个 class，两个结果继承 Instr。 |
| 6-8 | `llvm/lib/TableGen/TGParser.cpp:4157`（bool TGParser::ParseDefm(）；`llvm/docs/TableGen/ProgRef.rst:916`（``multiclass`` --- define multiple records） | 将原书错误 class rr/rm 伪代码改成两个等价 def 展开示意，明确依赖 Instr。 |
| 6-9 | `llvm/lib/TableGen/TGParser.cpp:4157`（bool TGParser::ParseDefm(）；`llvm/utils/TableGen/TableGen.cpp:67`（PrintRecords, "Print all records） | 基于实际 JSON 字段整理打印示意；记录继承 Instr，字段 name 为 rr/rm。 |
| 6-10 | `llvm/include/llvm/Target/Target.td:518`（class InstructionEncoding）；`HEAD:llvm/lib/Target/BPF/BPFInstrFormats.td:103`（class InstBPF<）；`HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:273`（class ALU_RI<）；`HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:297`（multiclass ALU<） | 逐层换为 LLVM 18 相关片段；ALU 新增 off，ADD 传 0，补闭合 let；四记录名正确。Constraints 是绑定，isAsCheapAsAMove 是不高于 move，ALU/JMP 共用布局而 class 不同。 |
| 6-11 | `llvm/utils/TableGen/TableGen.cpp:67`（PrintRecords, "Print all records） | 命令由 runner 导出固定提交快照后打印记录；三个生成后端均实际运行，并与工作树生成物逐字节比较。 |
| 6-12 | `llvm/include/llvm/Target/Target.td:572`（dag OutOperandList;）；`HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:298`（def _rr : ALU_RR<）；`llvm/utils/TableGen/CodeGenInstruction.cpp:30`（DagInit *OutDI） | 完整 JSON 验证四个 ADD 变体、Size、绑定和代价属性；纠正 InOperandList/OutOperandList 为机器使用/定义操作数，不是匹配规则输入/输出指令序列。保留节选状态。 |
| 6-13 | `llvm/utils/TableGen/CodeGenDAGPatterns.cpp:3956`（void CodeGenDAGPatterns::ParseInstructions()）；`llvm/utils/TableGen/DAGISelEmitter.cpp:191`（X("gen-dag-isel"） | 替换为实际生成的完整 ADD 分支，偏移2518→2589；包含FI_ri、两种位宽立即数及寄存器变体，非ADD_rr独占。测试按动作/符号检查，不固定偏移。 |
| 6-14 | `HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:738`（def : Pat<(BPFcall imm:$dst)）；`HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:739`（def : Pat<(BPFcall GPR:$dst)） | 两条定义在 18 保留。修正 JAX/JAXL 名称为 JAL/JALX，同一调用择一；补说明 tglobaladdr/texternalsym 模式，清单非全部模式。 |
| 6-15 | `llvm/include/llvm/Target/TargetSelectionDAG.td:1951`（class Pattern<）；`llvm/include/llvm/Target/TargetSelectionDAG.td:1960`（class Pat<） | 完整类定义与 18 一致，跨页围栏合并；Pat 是独立显式模式。 |
| 6-16 | `llvm/lib/TableGen/TGParser.cpp:3593`（bool TGParser::ParseDef(）；`llvm/utils/TableGen/CodeGenDAGPatterns.cpp:4359`（void CodeGenDAGPatterns::ParsePatterns()） | 实际 JSON 中立即数与寄存器调用模式的匿名记录为7228/7229；正文按内容展示，不将编号当作稳定接口。 |
| 6-17 | `llvm/lib/Target/BPF/BPFISelDAGToDAG.cpp:104`（bool BPFDAGToDAGISel::SelectAddr(） | 用完整 18 方法替换省略的骨架。FrameIndex、符号节点拒绝、基址加有符号 16 位偏移和 Base=Addr 回退逐分支核对；需要现有类上下文。 |
| 6-18 | `HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:100`（def ADDRri : ComplexPattern）；`llvm/include/llvm/Target/TargetSelectionDAG.td:1973`（class ComplexPattern<） | 定义与 18 一致；NumOperands=2 是 Base/Offset 输出数量，不是 Addr 节点的输入数。 |
| 6-19 | `llvm/include/llvm/Target/TargetSelectionDAG.td:1973`（class ComplexPattern<）；`llvm/utils/TableGen/DAGISelMatcherEmitter.cpp:1107`（// Emit CompletePattern matchers.） | 逐字段对应构造参数与默认值，SelectFunc 类型 string，生成器输出命名方法调用而非读取函数指针。JSON 验证字段，并检查生成方法中实际调用 SelectAddr 的两个结果槽。 |
| 6-20 | `HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:543`（class LOADi64<）；`HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:570`（def LDW : LOADi64<） | 修正为 18 的 ModOp 参数与 BPF_MEM，补 BPFNoALU32 谓词。BPFWidthModifer/ModeModifer 沿用源码拼写。 |
| 6-21 | `HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:528`（class LOAD<）；`HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:570`（def LDW : LOADi64<）；`HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:1103`（def LDW32 : LOADi32<） | 实际 JSON 验证 Predicates 和 zextloadi32 模式；32 位内存读扩展为 64 位值。ALU32 可走 LDW32，不能无条件宣称总选 LDW。 |

## 算法与正文核查

| 项目 | 证据 | 结论与处理 |
| --- | --- | --- |
| dag 值和类型 | `llvm/docs/TableGen/ProgRef.rst:412`（DagArg:）；`llvm/lib/TableGen/Record.cpp:906`（case SIZE:） | 运算符为 record，参数是 value/value:$name/$name；补 ClassID 类型、int 有符号和 !size 的直接参数计数。嵌套 dag 不是任意有向图通用接口。 |
| 工具链划分 | `llvm/utils/TableGen/CMakeLists.txt:33`（add_tablegen(llvm-tblgen）；`clang/utils/TableGen/CMakeLists.txt:3`（add_tablegen(clang-tblgen）；`mlir/tools/mlir-tblgen/CMakeLists.txt:8`（add_tablegen(mlir-tblgen） | 共享前端，各自可执行工具装入相应后端；图 6-1 邻近说明纠正“一切都由 llvm-tblgen”的印象。 |
| 编码位与字节 | `HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:162`（class TYPE_ALU_JMP<）；`llvm/lib/Target/BPF/MCTargetDesc/BPFMCCodeEmitter.cpp:113`（void BPFMCCodeEmitter::encodeInstruction(） | Inst 高 8 位由发射器先输出为 opcode 字节；不与小端内存整数低 8 位混淆，4/1/3 位含义明确。 |
| 绑定与代价属性 | `llvm/utils/TableGen/CodeGenInstruction.cpp:336`（// TIED_TO:）；`llvm/include/llvm/Target/Target.td:629`（bit isCommutable）；`llvm/include/llvm/Target/Target.td:644`（bit isAsCheapAsAMove） | Constraints 非交换律；绑定输出/输入形成二地址约束；cheap 标记允许等于 move 成本。 |
| 隐式/显式模式与 set | `llvm/include/llvm/Target/TargetSelectionDAG.td:1945`（// define patterns in most cases）；`llvm/utils/TableGen/CodeGenDAGPatterns.cpp:3775`（void CodeGenDAGPatterns::parseInstructionPattern(） | 保留章节名并指出原书术语颠倒；Instruction 的 Pattern 推导目标指令，Pat 显式添加规则；set 是模式结构，不是额外目标 COPY。 |
| PatFrag / PatLeaf | `llvm/include/llvm/Target/TargetSelectionDAG.td:933`（class PatFrag<）；`llvm/include/llvm/Target/TargetSelectionDAG.td:945`（class PatLeaf<） | OpNode=zextloadi32 属于 PatFrag，ADDRri 属于 ComplexPattern；无模式参数不表示不能引用其他记录。 |
| GCC 比较 | 本次范围仅为本地 LLVM 18；未核对 GCC 源码 | 移除“采用 MD 必须自行开发汇编器”等绝对结论，保留编译器描述与编码工具职责的区分。 |

## 已执行覆盖与边界

`experiments/ch6/runner.py` 运行语言值和记录展开、2个诊断反例、BPF JSON记录、DAG选择器、机器指令描述与MC编码器生成。language.td / records.td 是独立输入；摘录的 LLVM 类片段依赖完整库定义，实际验证使用完整 BPF.td。

源码以 `git archive 3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff` 导出所需目录到临时位置，不改LLVM源文件。实验还对当前工作树执行相同三种生成命令：DAG选择器、指令描述、MC编码器的输出均与基线逐字节相同，SHA-256 见 [experiments-ch6.json](experiments-ch6.json)。用户的文本改动并不意味着这些生成结果有变化。

清单6-17的C++方法按完整源码核对，生成器实际发出SelectAddr调用。TableGen运行成功不独立证明地址边界选择、大小端机器字节或程序运行性能；相应机器代码行为应由后续代码生成实验覆盖。未对GCC作超出本地LLVM证据的结论。
