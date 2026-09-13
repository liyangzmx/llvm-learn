# 第 2 章核查记录

基线 LLVM 18.1.8；全文静态校对，未执行 Clang、opt、llc。

| 清单/位置 | 依据 | 结论/修正 |
| --- | --- | --- |
| 2-1 | `clang AST；clang/include/clang/Driver/Options.td` | C 加法示例；函数是 FunctionDecl，CompoundStmt 是函数体；有符号溢出限制 |
| 2-2、2-3 | `llvm/docs/OpaquePointers.rst:265；LangRef.rst:4542` | typed pointer→ptr；中文分号改IR注释；nsw并非溢出检查；保留简化IR，不声称生成输出 |
| 2-4 | `llvm/lib/Passes/PassRegistry.def:320` | C阶乘，保留跨页续码；opt -passes=dot-cfg -disable-output；结果受int范围限制 |
| 2-5、2-6 | `llvm/docs/LangRef.rst（SSA约束）` | 重命名伪代码静态成立 |
| 2-7、2-8 | `变量定义/路径逐项手工跟踪` | 保留故意未汇聚的中间步骤，非完整合法SSA |
| 2-9、2-10 | `Verifier.cpp:2942；前驱值选择` | if:y3/else:y2互换错误，改if:y2/else:y3，附Mermaid |
| 2-11 | `do-while语义逐步跟踪` | 修复图2-6误作前测循环，出口用y3 |
| 2-12 | `PHIElimination.cpp:269,675` | Lost Copy说明；LLVM并非一律拆全部关键边 |
| 2-13 | `PHIElimination.cpp；并行复制语义` | 交换示例含不变n，原文已提示可能不终止；不能作运行验证样例 |
| 2-14 | `φ沿前驱边的旧值语义` | 原排序颠倒，需先y2=x2再x2=x1，循环依赖用临时变量 |
| 2-15 | `llvm/include/llvm/CodeGen/SlotIndexes.h` | 活跃区间半开表示需细分指令时刻，不能忽略early-clobber约束 |
| 2-16 | `与2-11逐句对照；mlir/docs/LangRef.md` | le→lt，exit携带y3并print，恢复相同语义 |
| 2-17 | `llvm/lib/IR/Verifier.cpp:2957；MLIR块参数` | 分支只选择一条边；相同前驱不同值在LLVM phi转换时才需消歧 |
| 2.2 | `Verifier.cpp:2933` | 普通call可不返回且不是terminator；LLVM IR无隐式fallthrough |
| 2.3.2/2.3.4 | `PromoteMemoryToRegister.cpp:802` | IDF迭代，mem2reg使用live-in剪枝 |
| 2.3.3 φ-web | `PHI消除实现与原书并行复制定义对照` | φ-web包含结果和输入；条件是同一个web内部无干涉；Briggs/Sreedhar说明属算法背景，不冒充LLVM完整实现 |

后续验证：实际LLVM IR解析与Verifier、mem2reg、PHIElimination转换结果及终止性样例。原书图中的错误不通过保留图片获得认可，已在相关正文给出修正。

## 独立复核补充

| 检查点 | 依据与结论 |
|---|---|
| 2-2/2-3 编号 | `LangRef.rst:874`：未命名参数 %0/%1 后，隐含入口块占 %2，指令从 %3 起，迁移为 ptr 后没有数字断档。仅静态检查。 |
| 2-14 并行赋值 | 保持已修订的先 `y2=x2` 再 `x2=x1`；右侧 x2 是回边旧值。所有 PHI 按边读取旧输入，与 CPU 是否乱序/并行执行无关。 |
| 基本块与异常 | `Instruction.def:123`、`Verifier.cpp:2933`：再次修正“任意可能抛异常指令之后都建块”；普通 call 并不因此成为 terminator。 |
| IDF/最小SSA | `PromoteMemoryToRegister.cpp:802`：DF 是 CFG 基本块关系；经典最小放置不保证没有死 PHI，mem2reg 的 live-in 剪枝另述。 |
| PHI-web/块参数 | 修正未定义名字 y 与“只改一个输入就删PHI”的表述；基本块参数仍有并行绑定语义，不能绕过交换与边上复制问题。`mlir/docs/LangRef.md:383`。 |
| 示例结论 | 单例产生较好合并机会不证明 Sreedhar 对所有输入更优；历史论文算法不是本地 PHIElimination 的完整实现。 |
