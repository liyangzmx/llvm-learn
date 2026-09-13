# 第 6 章静态校对记录

- 原书：LLVM 15.0.1。校订基线：本地 `/opt/llvm-project`，LLVM 18.1.8，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。
- 方法：完整阅读本章原文，逐清单与涉及的本地实现 / 同版本文档对照，直接修正全文。未编译 LLVM，未运行 C/C++、TableGen、IR/MIR、lit 或性能测试。
- 校订全文：[inside-llvm-codegen-ch6.md](../inside-llvm-codegen-ch6.md)。原始转写和原图裁剪保留在 origin，完整版面见原 PDF。

## 逐代码清单核查

| 清单 | LLVM 18 证据（行号以基线为准） | 结论与处理 |
| --- | --- | --- |
| 6-1 | `llvm/docs/TableGen/ProgRef.rst:164`（TokInteger:）；`llvm/lib/TableGen/TGLexer.cpp:465`（tgtok::TokKind TGLexer::LexNumber()） | 文法与 18 一致，保留；十进制可带正负号，十六进制 A–F 也合法。未运行 lexer 示例。 |
| 6-2 | `llvm/docs/TableGen/ProgRef.rst:176`（TokString:）；`llvm/docs/TableGen/ProgRef.rst:179`（A :token:`TokCode`） | 两类均是字符串；规范解释双引号及转义，TokCode 保留跨行换行，不在 TD 前端当 C++ 执行。 |
| 6-3 | `llvm/docs/TableGen/ProgRef.rst:194`（TokIdentifier:）；`llvm/lib/TableGen/TGLexer.cpp:337`（tgtok::TokKind TGLexer::LexIdentifier()） | 标识符与 $ 参数名文法保留，说明大小写和数字歧义；关键字补 in。 |
| 6-4 | `llvm/docs/TableGen/ProgRef.rst:336`（Value: `SimpleValue`）；`llvm/lib/TableGen/TGParser.cpp:229`（bool TGParser::SetValue(）；`llvm/lib/TableGen/TGParser.cpp:969`（bool TGParser::ParseRangePiece(） | 文法断行整理，解释部分位赋值保留其余位。a{1...3}=110 对应第 1/2/3 位为 1/1/0；只有其余位已为 0 才推出 0110。连字符范围是兼容的弃用形式。 |
| 6-5 | `llvm/lib/TableGen/TGParser.cpp:3593`（bool TGParser::ParseDef(）；`llvm/docs/TableGen/ProgRef.rst:706`（A ``def`` statement defines） | def record_example 语法与字段值保留，b 类型修正为字符串。 |
| 6-6 | `llvm/docs/TableGen/ProgRef.rst:631`（Record Bodies）；`llvm/lib/TableGen/TGParser.cpp:3450`（// LET ID OptionalRangeList） | class/def/let 继承和局部位赋值成立；未赋编码位为 ?，且未继承 Instruction，不能当作完整机器指令。 |
| 6-7 | `llvm/lib/TableGen/TGParser.cpp:4058`（bool TGParser::ParseMultiClass()）；`llvm/lib/TableGen/TGParser.cpp:4157`（bool TGParser::ParseDefm(） | multiclass 包含两个 def 模板，defm 加名前缀；不是声明多个 class，两个结果继承 Instr。 |
| 6-8 | `llvm/lib/TableGen/TGParser.cpp:4157`（bool TGParser::ParseDefm(）；`llvm/docs/TableGen/ProgRef.rst:916`（``multiclass`` --- define multiple records） | 将原书错误 class rr/rm 伪代码改成两个等价 def 展开示意，明确依赖 Instr。 |
| 6-9 | `llvm/lib/TableGen/TGParser.cpp:4157`（bool TGParser::ParseDefm(）；`llvm/utils/TableGen/TableGen.cpp:67`（PrintRecords, "Print all records） | 字段 nameDes 改回清单 6-7 的 name；继承注释 RegInstr 改 Instr；明确为静态推导，匿名/打印格式未采集。 |
| 6-10 | `llvm/include/llvm/Target/Target.td:518`（class InstructionEncoding）；`HEAD:llvm/lib/Target/BPF/BPFInstrFormats.td:103`（class InstBPF<）；`HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:273`（class ALU_RI<）；`HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:297`（multiclass ALU<） | 逐层换为 LLVM 18 相关片段；ALU 新增 off，ADD 传 0，补闭合 let；四记录名正确。Constraints 是绑定，isAsCheapAsAMove 是不高于 move，ALU/JMP 共用布局而 class 不同。 |
| 6-11 | `llvm/utils/TableGen/TableGen.cpp:67`（PrintRecords, "Print all records） | 修复 shell 换行并加续行符，给出两个 include 目录；命令读取当前定制工作树，基线复現应选干净 18.1.8，未运行。 |
| 6-12 | `llvm/include/llvm/Target/Target.td:572`（dag OutOperandList;）；`HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:298`（def _rr : ALU_RR<）；`llvm/utils/TableGen/CodeGenInstruction.cpp:30`（DagInit *OutDI） | 逐字段对照静态继承，字段仍适用；纠正 InOperandList/OutOperandList 为机器使用/定义操作数，不是匹配规则输入/输出指令序列。保留节选状态。 |
| 6-13 | `llvm/utils/TableGen/CodeGenDAGPatterns.cpp:3956`（void CodeGenDAGPatterns::ParseInstructions()）；`llvm/utils/TableGen/DAGISelEmitter.cpp:191`（X("gen-dag-isel"） | 补缺失 /*；这是整个 ISD::ADD 分支片段，Constant 检查属于立即数候选，非 ADD_rr 专用；偏移属于原书历史生成表，未在 18 重生成。 |
| 6-14 | `HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:738`（def : Pat<(BPFcall imm:$dst)）；`HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:739`（def : Pat<(BPFcall GPR:$dst)） | 两条定义在 18 保留。修正 JAX/JAXL 名称为 JAL/JALX，同一调用择一；补说明 tglobaladdr/texternalsym 模式，清单非全部模式。 |
| 6-15 | `llvm/include/llvm/Target/TargetSelectionDAG.td:1951`（class Pattern<）；`llvm/include/llvm/Target/TargetSelectionDAG.td:1960`（class Pat<） | 完整类定义与 18 一致，跨页围栏合并；Pat 是独立显式模式。 |
| 6-16 | `llvm/lib/TableGen/TGParser.cpp:3593`（bool TGParser::ParseDef(）；`llvm/utils/TableGen/CodeGenDAGPatterns.cpp:4359`（void CodeGenDAGPatterns::ParsePatterns()） | 匿名的是记录，不是 class；字段 PatternToMatch 拼写修复；3928/3929 只保留为原书历史编号。 |
| 6-17 | `llvm/lib/Target/BPF/BPFISelDAGToDAG.cpp:104`（bool BPFDAGToDAGISel::SelectAddr(） | 用完整 18 方法替换省略的骨架。FrameIndex、符号节点拒绝、基址加有符号 16 位偏移和 Base=Addr 回退逐分支核对；需要现有类上下文。 |
| 6-18 | `HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:100`（def ADDRri : ComplexPattern）；`llvm/include/llvm/Target/TargetSelectionDAG.td:1973`（class ComplexPattern<） | 定义与 18 一致；NumOperands=2 是 Base/Offset 输出数量，不是 Addr 节点的输入数。 |
| 6-19 | `llvm/include/llvm/Target/TargetSelectionDAG.td:1973`（class ComplexPattern<）；`llvm/utils/TableGen/DAGISelMatcherEmitter.cpp:1107`（// Emit CompletePattern matchers.） | 逐字段对应构造参数与默认值，SelectFunc 类型 string，生成器输出命名方法调用而非读取函数指针。未执行打印。 |
| 6-20 | `HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:543`（class LOADi64<）；`HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:570`（def LDW : LOADi64<） | 修正为 18 的 ModOp 参数与 BPF_MEM，补 BPFNoALU32 谓词。BPFWidthModifer/ModeModifer 沿用源码拼写。 |
| 6-21 | `HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:528`（class LOAD<）；`HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:570`（def LDW : LOADi64<）；`HEAD:llvm/lib/Target/BPF/BPFInstrInfo.td:1103`（def LDW32 : LOADi32<） | 静态展开补 Predicates，模式仍为 zextloadi32；32 位内存读扩展为 64 位值。ALU32 可走 LDW32，不能无条件宣称总选 LDW。 |

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

## 限制与后续验证

本地 BPF.td、BPFCallingConv.td、BPFInstrFormats.td、BPFInstrInfo.td、BPFRegisterInfo.td、BPFMIChecking.cpp、GISel/BPFRegisterBanks.td 有用户未提交改动。本审计涉及的 BPF TD 均以 `git show HEAD:<path>` 读取，表中 `HEAD:` 行号属于该基线；没有修改这些文件。书中命令若对 /opt/llvm-project 直接执行，会读取定制工作树。

后续再执行 TableGen 记录打印、DAGISel 生成以及完整目标 IR 用例。未验证匿名编号、MatcherTable 偏移、生成文件全文、大小端字节输出或最终运行行为。应先决定基线或定制树、ALU32 / 非 ALU32 配置，并确保匹配版本的工具可用；本次不进行构建。
