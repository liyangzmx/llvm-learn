# 附录 A 核查记录

LLVM 18.1.8 静态核查；未构建、未运行示例。

| 清单/位置 | 核查依据 | 结论与修正 |
| --- | --- | --- |
| A-1/A-2 | LangRef.rst；OpaquePointers.rst:265 | 保留C示例；ptr迁移、长字符串接回；目标/ident是历史记录 |
| A-3 | Verifier.cpp；LangRef.rst | load不得在模块顶层；补入函数块 |
| A-4/A-5 | LangRef.rst:835；LLParser.cpp | 标明文法骨架，补partition，纠正prologue解释；并非完整可执行IR |
| A-6 | LangRef.rst:4542 | 加法语义成立，nsw是poison约束；未运行O2 |
| A-7/A-8 | User.h；Value.h:376,421 | Use-Def与Def-Use写反；users不等同调用图 |
| A-9 | SelectionDAGNodes.h；BPFISelLowering.cpp:678 | RET_FLAG→RET_GLUE；SDValue引用结果；日志非本轮输出 |
| A-10 | MachineInstr.h；BPFInstrInfo.td（HEAD） | tied-def及gpr含义；多个Def/隐式操作数；片段不是完整MIR文件 |
| A-11/A-12 | BPFInstrInfo.td；MCInst.h:184；BPFMCInstLower.cpp | 删除不可靠固定opcode枚举示例，历史日志明确版本；MIR→MC非一对一 |
| A.1/A.3/A.4 | DerivedTypes.h:52；Metadata.h:62；MCInst.h:184 | 布局解释错配、浮点名称、opaque ptr、元数据继承、字段数量修正 |

待后续：实际 IR/工具命令输出；C++ 片段的包含文件、调用上下文与构建验证尚未执行。

## 独立复核补充

| 检查点 | 依据与结论 |
|---|---|
| A-2 数字编号 | 隐含入口块占 %2，alloca从%3起，后续%4…%9无断档；ptr迁移与元数据没有被伪称为LLVM18实际输出。 |
| A-5 函数声明 | `llvm/lib/AsmParser/LLParser.cpp:6015,6110`：声明同样解析地址空间和函数属性，补文法骨架缺少的字段，并指出 LangRef 的 declare 展示是简化形式。 |
| Value/User/Use | `Use.h:72`、`Value.h:202,376,421`：Use 是具体操作数槽；users()是直接使用者且可重复，不递归展开 ConstantExpr/alias。A-7/A-8的Use-Def/Def-Use方向保持正确。 |
| 无结果指令 | `Verifier.cpp:4883`：void指令没有可命名数据结果；不能因Instruction继承Value就说每条指令结果都能用作操作数。 |
| MachineOperand | `MachineOperand.h:379`：isUse/isDef只适用寄存器操作数；立即数等无该寄存器活跃性标志。操作数数量不限制为3。 |
| 分支分析与GMIR | `TargetInstrInfo.h:648`默认analyzeBranch可失败；`docs/GlobalISel/GMIR.rst:28,50,156`解释通用opcode/LLT，不能把GMIR理解为永远不混入目标指令。 |
| IR演进 | `Instruction.def`、`OpaquePointers.rst`：opaque pointer不只影响GEP；指令变化不限异常处理。博客日期仅纠正原文与其URL的2012/2021不一致，未联网核验文章。 |
