# 第 2 章核查记录

基线为 LLVM 18.1.8，源码提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。全文按源码和本章实验修订；工具来自统一更新后的 Debug / assertions 构建。本文区分真实工具输出、教学算法模型和仅按源码核对的接口。

| 清单/位置 | 依据 | 结论/修正 |
| --- | --- | --- |
| 2-1 | `clang AST；clang/include/clang/Driver/Options.td` | Clang AST 实跑确认 FunctionDecl / CompoundStmt / ReturnStmt / BinaryOperator；修 ParmVarDecl 拼写及隐式左值转换，输入避免有符号溢出 |
| 2-2、2-3 | `llvm/docs/OpaquePointers.rst:265；LangRef.rst:4542` | 完整 add.ll 运行 llvm-as 与 verifier；opaque ptr 与数字编号合法；nsw 产生 poison 而非溢出检查；正文是省略属性的手写可解析模块 |
| 2-4 | `llvm/lib/Passes/PassRegistry.def:320` | 完整函数经 Clang / mem2reg / 解释器运行，factor(5)=120；实际生成 DOT，显式限制 int 范围 |
| 2-5、2-6 | `llvm/docs/LangRef.rst（SSA约束）` | 重命名伪代码静态成立 |
| 2-7、2-8 | `变量定义/路径逐项手工跟踪` | 保留故意未汇聚的中间步骤，非完整合法SSA |
| 2-9、2-10 | `Verifier.cpp:2942；前驱值选择` | if:y3/else:y2互换错误，改if:y2/else:y3，附Mermaid |
| 2-11 | `do-while语义逐步跟踪` | 修复图2-6误作前测循环，出口用y3 |
| 2-12 | `PHIElimination.cpp:269,675` | Lost Copy说明；LLVM并非一律拆全部关键边 |
| 2-13 | `PHIElimination.cpp；并行复制语义` | 改为有界 for 循环，n=0/1/2/9 时返回 0/2/0/2，优化前后解释执行一致 |
| 2-14 | `φ沿前驱边的旧值语义` | 原排序颠倒，需先y2=x2再x2=x1，循环依赖用临时变量 |
| 2-15 | `llvm/include/llvm/CodeGen/SlotIndexes.h` | 活跃区间半开表示需细分指令时刻，不能忽略early-clobber约束 |
| 2-16 | `与2-11逐句对照；mlir/docs/LangRef.md` | le→lt，exit携带y3并print，恢复相同语义 |
| 2-17 | `llvm/lib/IR/Verifier.cpp:2957；MLIR块参数` | 完整 MLIR 解析并转换到 LLVM 方言；导出 LLVM IR 时新增边块和两个 PHI；verifier 与 true/false 解释执行通过 |
| 2.2 | `Verifier.cpp:2933` | 普通call可不返回且不是terminator；LLVM IR无隐式fallthrough |
| 2.3.2/2.3.4 | `PromoteMemoryToRegister.cpp:802` | IDF迭代，mem2reg使用live-in剪枝 |
| 2.3.3 φ-web | `PHI消除实现与原书并行复制定义对照` | φ-web包含结果和输入；条件是同一个web内部无干涉；Briggs/Sreedhar说明属算法背景，不冒充LLVM完整实现 |

正文的 LLVM IR / CFG 组织、普通 call 与 terminator、SSA 变量与内存修改、SelectionDAG / GlobalISel 阶段均已重写。错误或不对应新样例的图换为 Mermaid / 明确的复制步骤。

## 独立复核补充

| 检查点 | 依据与结论 |
|---|---|
| 2-2/2-3 编号 | `LangRef.rst:874`：未命名参数 %0/%1 后，隐含入口块占 %2，指令从 %3 起，迁移为 ptr 后没有数字断档。对应完整模块实际通过 llvm-as 与 verifier。 |
| 2-14 并行赋值 | 保持已修订的先 `y2=x2` 再 `x2=x1`；右侧 x2 是回边旧值。所有 PHI 按边读取旧输入，与 CPU 是否乱序/并行执行无关。 |
| 基本块与异常 | `Instruction.def:123`、`Verifier.cpp:2933`：再次修正“任意可能抛异常指令之后都建块”；普通 call 并不因此成为 terminator。 |
| IDF/最小SSA | `PromoteMemoryToRegister.cpp:802`：DF 是 CFG 基本块关系；经典最小放置不保证没有死 PHI，mem2reg 的 live-in 剪枝另述。 |
| PHI-web/块参数 | 修正未定义名字 y 与“只改一个输入就删PHI”的表述；基本块参数仍有并行绑定语义，不能绕过交换与边上复制问题。`mlir/docs/LangRef.md:383`。 |
| 示例结论 | 单例产生较好合并机会不证明 Sreedhar 对所有输入更优；历史论文算法不是本地 PHIElimination 的完整实现。 |

## MLIR 导出证据

- `mlir/lib/Target/LLVMIR/ModuleTranslation.cpp:1677`：`translateModuleToLLVMIR` 在导出前调用 `LLVM::ensureDistinctSuccessors`。
- `mlir/lib/Dialect/LLVMIR/Transforms/LegalizeForExport.cpp:30`：对带块参数的重复后继，从第二条边开始添加中间块；不是要求前端禁止这种 IR。
- `edge-values.mlir` 转成 LLVM 方言时仍为同目标两条边；导出后两个分支目标不同，汇合处和中间块各有一个 PHI。两种条件实参分别得到 1 / 2。

## 已执行覆盖

`experiments/ch2/runner.py` 覆盖 AST、IR 解析、3 个 verifier 反例、mem2reg、死 PHI 剪枝、CFG DOT、MachineVerifier 下的 PHI 消除及 MLIR 导出。C 模块的 15 个返回值断言在优化前后均通过；机器 PHI 为 2→0。独立数学模型穷举 1–4 个位置的 288 种并行复制映射，并复现 Lost Copy 错误放置的 10→11 差异。

解释器用于纯 IR 的值语义；机器实验停在 PHIElimination 前后，不证明最终复制数或性能。Briggs / Sreedhar 与 φ-web 是算法背景，本章不声称实现完整论文算法。实际命令和工具版本见 [experiments-ch2.json](experiments-ch2.json)。
