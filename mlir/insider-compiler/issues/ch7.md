# 第 7 章校订记录

对应 [第 7 章：MLIR 中常见的通用优化技术](../insider-compiler-ch7.md)。扫描来源为 `pdf/insider-compiler-ch7-ch10.pdf` 的 **PDF 第 1–17 页，即书页 128–144**。原始 Apple Vision OCR 位于 `ocr/insider-compiler-ch7-ch10/`，本次没有修改原始识别文本、识别 JSON 或扫描 PNG。

## 基准与覆盖

- 本地源码 `/opt/llvm-project`，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`，实际版本 **LLVM 18.1.8**。版本依据为 [llvm/CMakeLists.txt](/opt/llvm-project/llvm/CMakeLists.txt:18) 及 [工具版本和执行日志](evidence/ch7/checks.log)。本地工具为带断言的 Debug 构建。
- 原书参考 LLVM 20。本记录区分 OCR 识别错误、原书概念错误、本地源码注释错误及本地 API 差异。没有对照 LLVM 20 的具体提交时，不把所有差异一律归因于版本升级。
- **17/17 页均实际使用 `view_image` 查看对应扫描 PNG**，再结合原始 OCR 转写。四幅示意图的节点、箭头和旁注均检查了原图，随后按本地实现校订并重绘为 Mermaid。保留全部章节、正文论述、清单、图号、脚注及末页注意框；只移除页眉、印刷页码和装饰元素。
- 正文含 **17 份编号清单、4 幅编号图、0 张原书表格、5 条脚注**。页标完整连续覆盖 PDF 第 1–17 页。本文中的覆盖表和验证表是校订记录新增内容，不计入原书图表数。

| PDF 页 | 书页 | 完整转写及目视核验内容 |
| --- | --- | --- |
| 1 | 128 | 章首、通用 Pass 列表、7.1 开头、Pass 名称脚注 |
| 2 | 129 | 操作数排序、清单 7-1、7.2 两种归一化机制 |
| 3 | 130 | 接口原型、清单 7-2/3、7.3 条件 |
| 4 | 131 | 清单 7-4/5、7.4 CSE 与第一种副作用情形 |
| 5 | 132 | CSE 第二种情形、清单 7-6/7、7.5、7.6 |
| 6 | 133 | 清单 7-8/9、7.7 开头 |
| 7 | 134 | mem2reg 四步骤、清单 7-10、Polygeist 脚注 |
| 8 | 135 | 清单 7-11、7.8、清单 7-12/13 |
| 9 | 136 | 7.9.1、清单 7-14/15、7.9.2 导语 |
| 10 | 137 | SROA 两阶段与全部子步骤、7.10 导语 |
| 11 | 138 | 完整清单 7-16/17、内联结果解释 |
| 12 | 139 | 7.10.2 SCC、递归、四阶段与方言钩子 |
| 13 | 140 | 内联接口说明续、7.11 三项复杂性、7.11.1 理论与公式 |
| 14 | 141 | 框架四对象、图 7-1、分析类别前三项 |
| 15 | 142 | 分析类别续、7.11.2 DCA、图 7-2 |
| 16 | 143 | 稀疏常量传播、图 7-3/4、性能说明、三项局限、RFC 脚注 |
| 17 | 144 | 会议资料、7.12 小结、注意框、两条演讲 PDF 脚注 |

## OCR 和排版修复

统一修复 `ML.IR/MILIR`、`RewritePatter`、`getCanonicalizationPattems`、`Runtime VerifiableOpInterface`、`generateRuntimeYerification`、`lo0p`、`11vm`、`132/164/11`、`£32`、`fo0/f0o` 等识别错误；恢复 `%`、`@`、`$`、指针、模板尖括号、引号、花括号、方括号、分支标签及跨行类型。代码段统一为可复制的字符和缩进，没有把 OCR 错误标点保留在修订版代码中。

清单 7-10 的 `^bb2:`、清单 7-16 的 `%c`、`%b` 和多个闭合括号等由扫描图恢复。清单 7-13 最后一个操作在原图中是 **`test.bar`**，OCR 误识为 `test.baz`；已恢复为 `test.bar`，这属于 OCR 错误而非拓扑排序改变操作名称。原书函数名 `check_cummutative_cse` 的非标准英文拼写只影响符号名称，代码中保留并通过验证。脚注 URL 中的 `lvm/llv​​m`、空格及文件名乱码按原资料地址修复，保留原书记载的访问年月。

<a id="pass-names"></a>
## 1. 通用 Pass 的前提和名称

**位置：PDF 第 1 页，书页 128。类别：概念修正及本地版本对齐。**

原文说这些优化“仅与 IR 的结构相关，而与 IR 的内容并无关联”。该说法过强。CSE、LICM、下沉、内联等都需要特质或接口提供语义保证，例如可交换性、内存副作用、可安全推测执行以及内联合法性；只看 IR 形状不够。正文改成“借助 IR 结构以及操作提供的特质、接口和语义约束跨方言工作”。

本地 [Passes.td](/opt/llvm-project/mlir/include/mlir/Transforms/Passes.td:19) 中，内联为 `Pass<"inline">`（267 行），循环不变量外提为 `Pass<"loop-invariant-code-motion">`（327 行）；原书的 `inliner`、`licm` 可作为术语，但不是本地对应的命令行选项。`sccp` 选项采用小写。原书的 `composite-fixed-point-pass` 在本地 `mlir/include`、`mlir/lib` 中没有定义，正文保留这个条目的出处并明确不可在该基准下直接使用，没有擅自虚构兼容替代。

操作统计、位置快照和操作图显示等属于辅助 Pass，而不是都以缩短程序执行时间为目的。正文据此将列表称为“通用优化与辅助 Pass”。

<a id="operand-sorting"></a>
## 2. 操作数排序：原书与上游注释都有错误

**位置：PDF 第 1–2 页，书页 128–129；清单 7-1。类别：原书错误、源码注释错误。**

原文：“按照深度优先遍历的方式依次进行比较”；原示例结果为：

```text
%5 = foo.commutative %4, %3, %2, %1
```

实际 [CommutativityUtils.cpp](/opt/llvm-project/mlir/lib/Transforms/Utils/CommutativityUtils.cpp:23) 以 `AncestorKey` 比较类别和操作名，类别顺序为基本块参数、非常量操作、常量操作。[祖先队列及更新](/opt/llvm-project/mlir/lib/Transforms/Utils/CommutativityUtils.cpp:73) 明确执行 BFS；[稳定排序](/opt/llvm-project/mlir/lib/Transforms/Utils/CommutativityUtils.cpp:300) 使用 `std::stable_sort`。公共入口是 [populateCommutativityUtilsPatterns](/opt/llvm-project/mlir/lib/Transforms/Utils/CommutativityUtils.cpp:312)。

本地源码 [Example 2 注释](/opt/llvm-project/mlir/lib/Transforms/Utils/CommutativityUtils.cpp:193) 也给出 `%4, %3, %2, %1`，但这与执行算法不一致。对 `%2`、`%3`，首项同为 `foo.mul`，第二项分别为基本块参数和非常量操作，前者较小。因此实际顺序是 **`%4, %2, %3, %1`**。

证据：[可运行输入](evidence/ch7/sort.mlir)、[实际输出](evidence/ch7/sort.out.mlir)。用注册的 `test.op_commutative` 提供可交换特质，以 `arith.constant` 提供常量特质，并用未注册的 `foo.mul/foo.add` 保持原示例名称和依赖；`--test-commutativity-utils --allow-unregistered-dialect` 真实输出的对应顺序为 `%a0, %m, %n, %c`。这既验证类别比较，也验证同名根操作的后续祖先比较。

原清单没有类型、定义或合法的 `<block argument>` 语法，因此正文明确标注为伪代码。没有声称它本身可以作为完整 MLIR 文件直接运行。

<a id="canonicalization"></a>
## 3. 归一化接口及折叠边界

**位置：PDF 第 2–3 页，书页 129–130；清单 7-2/3。类别：原书表述过强、API 区分。**

原文将操作和方言的 `getCanonicalizationPatterns` 都写成带 `MLIRContext *` 的静态函数。实际操作声明使用该形式，而 [Dialect.h](/opt/llvm-project/mlir/include/mlir/IR/Dialect.h:77) 中是 `virtual void getCanonicalizationPatterns(RewritePatternSet &) const`，正文分别列出。

`hasCanonicalizeMethod` 会生成包装单个 `canonicalize` 钩子的模式，不能据此推断任何 `getCanonicalizationPatterns` 都只能实现一个模式。`hasCanonicalizer` 则用于声明自行填充模式集的方法，参见 [OpBase.td](/opt/llvm-project/mlir/include/mlir/IR/OpBase.td:408)。原书后面添加两个模式的示例本身也反证了“只实现一个模式”的一般性说法。

原文“fold 不能生成新的值”改为不能直接创建新的操作，但可返回已有 SSA 值或常量属性；常量由框架物化。`fold` 不只由 canonicalizer 使用，`OpBuilder::createOrFold` 等也会调用折叠流程。`createCanonicalizerPass()` 是创建 Pass 的函数，应将返回对象加入 `PassManager`，不是在 `PassManager` 内调用一个同名成员方法。

清单 7-2 与 [ArithOps.cpp](/opt/llvm-project/mlir/lib/Dialect/Arith/IR/ArithOps.cpp:1432) 一致。清单 7-3 对照 [ArithCanonicalization.td](/opt/llvm-project/mlir/lib/Dialect/Arith/IR/ArithCanonicalization.td:351) 恢复语法；已补入两个必要 include 后运行真实 `mlir-tblgen -gen-rewriters`，生成 [listing-7-3.inc](evidence/ch7/listing-7-3.inc)。规则片段不含方言定义，不将其误标成无需 include 的完整 TD 文件。

另以 [canonicalize.mlir](evidence/ch7/canonicalize.mlir) 运行 `--canonicalize`，得到 [输出](evidence/ch7/canonicalize.out.mlir)：两个 `i8 → i32` 扩展后的 `andi` 改为先做 `i8` 的 `andi`，再扩展一次。这里只补充验证一条代表性无符号扩展规则；有符号规则的 TD 生成同样通过，没有另外声称运行过其数值穷举测试。

<a id="cse"></a>
## 4. CSE 的副作用和区域限制

**位置：PDF 第 4–5 页，书页 131–132；清单 7-6/7。类别：原书概念错误。**

原文：“操作未定义接口 MemoryEffectOpInterface：这种情况下，可以直接执行消除操作。”这会把未知副作用当成无副作用，不正确。

实际 [CSE.cpp](/opt/llvm-project/mlir/lib/Transforms/CSE.cpp:230) 先尝试删除 trivially dead 操作，随后检查区域条件。对于重复操作，若 `isMemoryEffectFree` 不成立，必须能取得 `MemoryEffectOpInterface` 且声明只有 `Read` 效果，才可能继续处理；否则直接失败。只有读取效果的重复操作还需位于同一基本块，且两次读取之间没有可能写入的操作。[中间副作用检查](/opt/llvm-project/mlir/lib/Transforms/CSE.cpp:165) 对未知效果保守处理。本地检查是针对潜在写入，原书“中间除读取外不能有任何其他效果”的说法不准确。

原文“要求嵌套操作最多包含一个基本块”也过宽：局部限制检查的是候选操作**自身的每个区域**为空或单基本块；[多基本块区域处理](/opt/llvm-project/mlir/lib/Transforms/CSE.cpp:308) 仍遍历支配树，不是整个 Pass 拒绝多基本块函数。正文保留这一限制并明确其作用对象。

原文把“操作数、结果均相等”作为判等描述，容易理解成两个结果必须是同一个 SSA 值。实际 [OperationEquivalence::computeHash](/opt/llvm-project/mlir/lib/IR/OperationSupport.cpp:670) 和 [isEquivalentTo](/opt/llvm-project/mlir/lib/IR/OperationSupport.cpp:823) 比较结果类型、属性、properties、操作数及相关结构；CSE 忽略位置信息与结果身份，还识别可交换操作数。

实际 `--cse` 将 [原清单输入](evidence/ch7/cse.mlir) 中交换操作数的两个 `arith.addi` 合并，见 [输出](evidence/ch7/cse.out.mlir)。对两个完全同形、未注册的 `unknown.op`，[反例输入](evidence/ch7/cse-unknown.mlir) 的 [输出](evidence/ch7/cse-unknown.out.mlir) 仍保留两个操作，直接反驳“没有接口即可消除”。

<a id="motion-and-verification"></a>
## 5. 下沉、运行时验证和 LICM

**位置：PDF 第 3–6 页，书页 130–133；清单 7-4/5/8/9。类别：遗漏前提和术语修正。**

控制流下沉中的 `RegionBranchOpInterface` 用于识别候选目标区域所属的分支操作，不是要求被移动的普通计算都实现这个接口。[ControlFlowSink.cpp](/opt/llvm-project/mlir/lib/Transforms/ControlFlowSink.cpp:37) 取得至多执行一次的区域，并将 `isMemoryEffectFree` 作为移动条件。正文补上了这一被原书遗漏的语义条件。真实 `--control-flow-sink` 的 [输入](evidence/ch7/sink.mlir) 与 [输出](evidence/ch7/sink.out.mlir) 和清单 7-4/5 一致。

运行时验证由 [GenerateRuntimeVerification.cpp](/opt/llvm-project/mlir/lib/Transforms/GenerateRuntimeVerification.cpp:32) 调用 `RuntimeVerifiableOpInterface::generateRuntimeVerification`，是在 IR 中插入运行时检查。它不是替代静态 verifier，也不一定是性能优化。用 [runtime-verification.mlir](evidence/ch7/runtime-verification.mlir) 运行 `--generate-runtime-verification`，在 [输出](evidence/ch7/runtime-verification.out.mlir) 中实际产生 `arith.remsi`、`arith.cmpi` 与 `cf.assert`，检查展开形状的源维度能否被静态因子 5 整除。此验证检查生成的 IR，没有执行最终程序触发断言。

原文 LICM 条件“①在循环外部定义；②不产生副作用”缺少推测执行安全性，且混淆候选计算和输入。实际 [LoopInvariantCodeMotionUtils.cpp](/opt/llvm-project/mlir/lib/Transforms/Utils/LoopInvariantCodeMotionUtils.cpp:31) 检查输入是否来自循环外，以及嵌套操作中的依赖；[LoopLike 重载](/opt/llvm-project/mlir/lib/Transforms/Utils/LoopInvariantCodeMotionUtils.cpp:103) 要求 `isMemoryEffectFree(op) && isSpeculatable(op)`。循环实现 `LoopLikeOpInterface`，普通候选计算不必实现循环接口。

`--loop-invariant-code-motion` 的 [输入](evidence/ch7/licm.mlir) 与 [输出](evidence/ch7/licm.out.mlir) 确认两条 `arith.addf` 均移到两个循环之外。原例中 `%v1` 未被使用，LICM 本身仍保留该计算；本次没有偷偷叠加 `canonicalize`，从而改变原书希望展示的结果。

<a id="mem2reg"></a>
## 6. mem2reg 的 SSA 含义和四步骤

**位置：PDF 第 6–8 页，书页 133–135；清单 7-10/11。类别：概念修正与历史陈述边界。**

原文“本质上是对内存 SSA 形式的优化”以及“虚拟寄存器即 alloca 操作的返回值”容易将三件事混淆：分配结果是引用内存槽的 SSA 值；槽内存储内容会随读写变化；LLVM `MemorySSA` 又是独立的内存依赖分析。此处 mem2reg 将可提升槽的存储内容显式化为 SSA 值和基本块参数，不是把 `alloca` 返回的指针当作存储内容。

正文完整保留分析、修改两阶段及四步骤，按 [Mem2Reg.cpp 的算法说明](/opt/llvm-project/mlir/lib/Transforms/Mem2Reg.cpp:30) 和执行代码修正：

- [阻塞使用分析](/opt/llvm-project/mlir/lib/Transforms/Mem2Reg.cpp:239) 利用内存槽接口及前向切片，判断读写和间接使用是否可处理；不能简单认为所有 `load` 后面的 `cast` 都必须一起删除。
- [活入计算](/opt/llvm-project/mlir/lib/Transforms/Mem2Reg.cpp:305) 考虑块内读写顺序，并非只要块内有 `load` 就一定活入；[IDF 计算](/opt/llvm-project/mlir/lib/Transforms/Mem2Reg.cpp:364) 使用定义块和活入块求需要基本块参数的汇聚点。
- [可到达定义传播](/opt/llvm-project/mlir/lib/Transforms/Mem2Reg.cpp:422) 处理块参数和分支传值；[移除阻塞使用](/opt/llvm-project/mlir/lib/Transforms/Mem2Reg.cpp:544) 通过接口逆序改写，再完成分配的提升。

真实 [输入](evidence/ch7/mem2reg.mlir) 运行 `--mem2reg` 后得到 [输出](evidence/ch7/mem2reg.out.mlir)：`alloca/load/store` 全部消失，两个循环基本块各增加一个 `i64` 参数。清单 7-11 保留原书将 `@use` 排在 `@cycle` 前的显示方式，本地打印器保留输入的函数顺序；单独提取清单仍通过解析与 verifier。

原书称其最初来自 Polygeist，并于 2023 年整合进社区。本次没有独立追溯所有引入提交，因此正文将此明确表述为**原书关于 MLIR 通用实现的历史记载**，不把它写成 LLVM 传统 mem2reg 的起源。这一历史细节不影响本地算法和示例核验。

<a id="sroa"></a>
## 7. 拓扑排序与 SROA

**位置：PDF 第 8–10 页，书页 135–137；清单 7-12 至 7-15。类别：OCR、接口名和算法描述修正。**

图区域可允许使用先于定义，拓扑排序便于形成依赖顺序；不能由此推断该 Pass 对任意循环图都能生成线性拓扑序，或能保证任意程序的运行正确性。[TopologicalSort.cpp](/opt/llvm-project/mlir/lib/Transforms/TopologicalSort.cpp:1) 和 [TopologicalSortUtils.cpp](/opt/llvm-project/mlir/lib/Transforms/Utils/TopologicalSortUtils.cpp:1) 是本地实现。用注册测试方言的 [输入](evidence/ch7/sort-topological.mlir) 实际运行 `--topological-sort` 后，得到 `test.foo → test.baz → test.bar` 的 [顺序](evidence/ch7/sort-topological.out.mlir)。原扫描最后一项也是 `test.bar`，只是 OCR 误读。

SROA 原文接口名 `DestructurableAllocaOpInterface`、`DestructableTypeInterface` 与本地定义不符；实际为 **`DestructurableAllocationOpInterface`** 与 **`DestructurableTypeInterface`**，参见 [MemorySlotInterfaces.td](/opt/llvm-project/mlir/include/mlir/Interfaces/MemorySlotInterfaces.td:234)。算法由接口驱动，并非硬编码只支持两个方言的 `alloca`。

原文称索引 `[0, 2]` 访问“第 2 个元素”，已纠正为索引 2、即第 3 个元素。清单本身缺少初始化，正文明确这里只演示内存结构转换，不据其推断确定的返回值。

对于实现过程，原文称所有前向使用者都需实现 `PromotableOpInterface`。实际 [computeDestructuringInfo](/opt/llvm-project/mlir/lib/Transforms/SROA.cpp:46) 先处理 `DestructurableAccessorOpInterface`，再检查可安全使用的子槽；只有不能安全重接或访问的**阻塞使用**，才走可提升、可移除的检查路径。

原文“若存在……单个元素的 load 操作，可将其替换为一个新的 alloca 操作”不正确。实际 [destructureSlot](/opt/llvm-project/mlir/lib/Transforms/SROA.cpp:133) 调用分配接口 `destructure(slot, usedIndices, ...)`，按实际使用的子槽创建分配，再以逆拓扑顺序重接或删除访问，最后完成原分配的清理。不能给每次 load 各建一块新内存，也不能把读取语义替换成分配语义。

[SROA 输入](evidence/ch7/sroa.mlir) 运行 `--sroa` 的 [输出](evidence/ch7/sroa.out.mlir) 与修订清单 7-15 一致：数组分配与 GEP 被单个 `i32` 分配替代，`load` 仍然保留，并指向新分配。

<a id="inlining"></a>
## 8. 内联：递归历史、外部可见性和接口

**位置：PDF 第 10–13 页，书页 137–140；清单 7-16/17。类别：原书概念错误及实现细化。**

原文关于 `A → B → C → A` 的叙述将 `C、B、A` 写成必然的处理次序。实际 [Inliner.cpp](/opt/llvm-project/mlir/lib/Transforms/Inliner.cpp:689) 自底向上迭代 SCC，但 SCC 内具体访问和合法变换取决于输入、策略及历史；正文完整保留该循环例子，并明确它是概念示意，不是固定输出契约。

原文“一旦某个函数已经被内联，就终止对该函数的内联操作”会被理解为全局只能内联一次。实际 [inlineHistoryIncludes](/opt/llvm-project/mlir/lib/Transforms/Inliner.cpp:384) 检查的是当前调用点祖先链，防止同一展开链上的递归重复。多个独立调用点仍可内联相同函数。[Pass 默认配置](/opt/llvm-project/mlir/include/mlir/Transforms/Passes.td:267) 还设置 SCC 最大迭代数为 4，并以 canonicalize 为默认可调用体优化流水线。

原文：“如果符号被使用，表明该操作在外部处于活跃状态，那么就不能被内联。”这混淆了**允许内联**与**允许删除原符号**。实际 [inlineCallsInSCC](/opt/llvm-project/mlir/lib/Transforms/Inliner.cpp:480) 使用 `hasOneUseAndDiscardable` 决定能否移动原体，否则通常克隆，并不一概禁止内联公开函数。对 [公开 callee 反例](evidence/ch7/inline-public.mlir) 运行 `--inline` 后，[输出](evidence/ch7/inline-public.out.mlir) 中调用已消失，而公开的 `@callee` 定义仍保留。原书完整示例的 [输入](evidence/ch7/inline.mlir) 与 [输出](evidence/ch7/inline.out.mlir) 则确认两个 private 函数内联后被删除。

原书把 `isLegalToInline`、`handleTerminator` 等称作多个接口。实际它们是 [DialectInlinerInterface](/opt/llvm-project/mlir/include/mlir/Transforms/InliningUtils.h:43) 的方法；存在多个适用于不同对象的合法性重载及终止操作处理重载，其他钩子按需要实现。不能要求每个参与普通算子内联的方言都实现某个与其无关的返回终止操作处理。

原文“操作接口仅能对单独的操作区域起作用”不是操作接口的普遍限制。`CallOpInterface`、`CallableOpInterface` 等操作接口本来就在描述调用关系；方言内联接口负责集中提供方言策略。这是一种职责划分，不是操作接口无法跨区域。

<a id="dataflow-math"></a>
## 9. 数据流公式与 meet/join

**位置：PDF 第 13–14 页，书页 140–141。类别：数学表述不严谨及术语颠倒；大差异原文保留。**

原扫描首个公式为：

\[
S_{i+1}(P_{n+1})=S_i(P_{n+1})\cup f_{\mathrm{op}}[S_i(P_{n+1})].
\]

原文对组合分析写道：

> 在 \(f_{\mathrm{op}}[S'(p_n)]\) 中，\(S'\) 可表示为 \(S'=\{S_a,S_b,\cdots\}\)，\(f_{\mathrm{op}}\) 则可表示为 \(f_{\mathrm{op}}=f_a\cap f_b\)。所以，\(f_{\mathrm{op}}[S'(p_n)]\) 可以表示为 \((f_a\cap f_b)[S'(p_n)]\)，进一步可展开为 \(f_a[S'(p_n)]\cap f_b[S'(p_n)]\)。不过，在此需要留意的是，\(f_a\) 或者 \(f_b\) 只是 \(S'\) 中部分状态的转移函数。对于 \(f_i\) 而言，无意义的状态应当予以忽略。

最后的泛化公式为：

\[
S_{i+1}(p_{n+1})=S_i(p_{n+1})\cup
\{f_a[S_i(p_n)]\cap f_b[S_i(p_n)]\cap\cdots\}.
\]

原文未说明各函数的共同定义域、值域、偏序和交运算含义，直接把不同分析的转移函数视作可做集合交的对象，无法作为一般组合数据流框架的准确方程。首个式子还把转移输入写在目标点，与随后从 `p_n` 传播到 `p_{n+1}` 的意图不一致。

正文保留其教学目的，改成一条传播边 `p → q` 上的抽象域合并，再用复合状态和显式依赖说明多个分析如何交换信息。使用 `⊔` 表示具体 lattice 的 join，避免在未定义集合域时直接用 `∪`。公式是用于说明思想的数学模型，并不声称求解器每次迭代同步扫描所有程序点；执行实现是依赖驱动的工作队列。

原文“并（meet）和交（join）”颠倒，已改成 meet 为最大下界、join 为最小上界。具体抽象域的合并不能只凭中文“并、交”套用普通集合运算。对于本章的常量传播，[ConstantValue::join](/opt/llvm-project/mlir/include/mlir/Analysis/DataFlow/ConstantPropagationAnalysis.h:73) 给出了实际合并规则，是正文叙述的直接依据。

<a id="dataflow-implementation"></a>
## 10. 数据流框架和 SCCP 的本地实现

**位置：PDF 第 13–17 页，书页 140–144；图 7-1 至 7-4。类别：概念修正、历史 API 差异、图示校订。**

原文将 MLIR SCCP 称为“全局流不敏感分析”，并将处理调用图作为理由。跨过程分析与流敏感性是不同维度。实际 [SCCP.cpp](/opt/llvm-project/mlir/lib/Transforms/SCCP.cpp:123) 同时加载 `DeadCodeAnalysis` 和 `SparseConstantPropagation`，利用可执行路径信息推导常量；[DataFlowConfig](/opt/llvm-project/mlir/include/mlir/Analysis/DataFlowFramework.h:180) 的 `interprocedural` 默认为 true。正文改为“跨过程分析带来的复杂性”，不再把忽略程序顺序作为 SCCP 的特征。

可复现的 [SCCP 输入](evidence/ch7/sccp.mlir) 在常真条件两侧分别向汇聚块传入 42、99。运行 `--sccp` 后，[输出](evidence/ch7/sccp.out.mlir) 返回已知常量 42，证明不可执行路径没有把该值合并为未知。同时，该 Pass 输出中两个分支基本块仍存在，故正文没有把 DCA 的“分析出不可执行”误写成“已从 IR 删除全部死块”。

本地 API 与原书的关键差异如下。

| 原书表述 | 本地实际及修订 |
| --- | --- |
| 程序点用 Generic Program Point 表示 | [ProgramPoint](/opt/llvm-project/mlir/include/mlir/Analysis/DataFlowFramework.h:153) 是 `GenericProgramPoint * / Operation * / Value / Block *` 的联合表示，自定义程序点只是其中一种 |
| DCA 状态有 Unknown、Live、Uninitialized | [Executable](/opt/llvm-project/mlir/include/mlir/Analysis/DataFlow/DeadCodeAnalysis.h:39) 的内部是默认 false 的 `live`；原文混入其他分析的状态分类 |
| AnalysisState 定义 meet/join | 本地 [AnalysisState](/opt/llvm-project/mlir/include/mlir/Analysis/DataFlowFramework.h:314) 管理程序点及依赖，没有这两个统一虚函数；具体 lattice/状态提供所需更新 |
| DataFlowAnalysis 就是一个转移函数 | 它是分析基类，包含初始化、程序点访问等逻辑，其中实现若干转移规则 |
| Executable 描述基本块和控制流图 | 本地 [CFGEdge](/opt/llvm-project/mlir/include/mlir/Analysis/DataFlow/DeadCodeAnalysis.h:145) 描述一条块间边，不能把边误称为整张图 |
| DenseForward 提供非 SSA 分析，强制更新所有点 | 稠密分析把状态关联于程序位置，稀疏分析常关联于 SSA 值；二者均可用于 SSA IR，仍通过依赖及状态变化迭代 |
| 图 7-1 的 SparseForward 等是直接类名及完整层次 | 本地展开为相应 `*DataFlowAnalysis` 模板类，并补充已存在的 DenseBackward；省略中间抽象层，图明确说明不是完整直接继承图 |

类名和继承依据：[SparseAnalysis.h](/opt/llvm-project/mlir/include/mlir/Analysis/DataFlow/SparseAnalysis.h:180)、[DenseAnalysis.h](/opt/llvm-project/mlir/include/mlir/Analysis/DataFlow/DenseAnalysis.h:71)、[ConstantPropagationAnalysis.h](/opt/llvm-project/mlir/include/mlir/Analysis/DataFlow/ConstantPropagationAnalysis.h:99)、[IntegerRangeAnalysis.h](/opt/llvm-project/mlir/include/mlir/Analysis/DataFlow/IntegerRangeAnalysis.h:90)。图 7-2 至 7-4 保留原来的输入—分析—输出和循环依赖关系，将 `SparseForward` 这一基类占位展开为实际参与 SCCP 的 `SparseConstantPropagation`，将输出明确标为 `ConstantValue` 所在 lattice，并修正“所有变量初始即常量”的误导。

原书描述的历史图示和 `AnalysisState` 接口可与 [2023 年官方演讲资料](https://llvm.org/devmtg/2023-05/slides/TechnicalTalks-May10/07-TomEccles-JeffNiu-MLIRDataflowAnalysis.pdf) 对照；这解释了部分 API 为什么与本地 18.1.8 不同，但不替代本地执行代码。该资料位于会议 2023 年 5 月 10 日议程，原书“2023 年 4 月”改为 5 月。求解器本地使用 [std::queue 工作队列](/opt/llvm-project/mlir/include/mlir/Analysis/DataFlowFramework.h:278)，正文将“完全不能控制迭代顺序”缩小为缺少通用可插拔优先级调度接口。

**性能数据尚未独立核实。** 原书称新框架使性能提升 5% 以上，并指向 [RFC](https://discourse.llvm.org/t/rfc-a-dataflow-analysis-framework/63340)。本次获取该页面遇到 HTTP 429，没有拿到可核对的测试详情，也没有运行该性能基准。正文保留这一数字及出处，同时明确它是原书转述的特定测试结论，不能当作普遍性能保证。

<a id="region-dominance"></a>
## 11. 区域与支配关系

**位置：PDF 第 17 页，书页 144；本章小结注意框。类别：原书错误及引用范围修正。**

原注意框完整说法为：

> 实际上区域的引入也会改变支配关系，但目前 MLIR 忽略了这一点。对该部分内容感兴趣的读者可参考相关资料。

本地 [Dominance.cpp](/opt/llvm-project/mlir/lib/IR/Dominance.cpp:56) 按区域建立支配信息，通过 `RegionKindInterface` 区分单块区域的 SSA 支配语义；[跨区域关系处理](/opt/llvm-project/mlir/lib/IR/Dominance.cpp:124) 还显式考虑基本块所在区域的嵌套关系。因此，“MLIR 忽略区域对支配的影响”不成立。

原脚注 [Multiple-Exit MLIR Blocks](https://llvm.org/devmtg/2023-05/slides/QuickTalks-May10/01%20-Multiple-Exit%20MLIR%20Blocks-EuroLLVM%202023.pdf) 实际讨论嵌套结构中提前返回、continue、break 等多出口表示及其对分析和副作用建模的影响；其涉及的问题不能推广为所有区域支配关系均未实现。正文保留注意框与外链，改为说明已有支持以及该资料讨论的特定扩展问题。

小结“分析组合是传统数据流分析未曾涉及的内容”也过于绝对，改为 MLIR 将这一能力作为框架设计的重要部分，不作历史上的首次发明断言。

## 可复现验证和边界

关键输入、实际输出和命令均保存在 [evidence/ch7](evidence/ch7/) 中。以下命令从仓库根目录运行：

```sh
python3 mlir/insider-compiler/issues/evidence/ch7/run_checks.py
python3 mlir/insider-compiler/issues/evidence/ch7/verify_markdown.py
/opt/llvm-project/build/bin/mlir-opt \
  mlir/insider-compiler/issues/evidence/ch7/runtime-verification.mlir \
  --generate-runtime-verification \
  -o mlir/insider-compiler/issues/evidence/ch7/runtime-verification.out.mlir
```

第一条命令复现 12 个 Pass 场景；[checks.log](evidence/ch7/checks.log) 记录工具版本、各实际命令与退出码，12 个均为 0。第二条从**最终 Markdown 本身**提取清单验证，避免只验证另写的近似代码；[verify-markdown.log](evidence/ch7/verify-markdown.log) 记录逐清单命令与成功结果。

| 验证内容 | 结果与实际边界 |
| --- | --- |
| 14 份完整 MLIR 清单 7-4 至 7-17 | 全部单独通过 `mlir-opt` 解析与 verifier；对应提取文件均保留 |
| 清单 7-3 两条 TableGen 规则 | 添加依赖 include 后真实 `-gen-rewriters` 成功，生成文件保留 |
| 清单 7-2 C++ 方法 | 对照本地 `ArithOps.cpp`；是类方法摘录，没有声称可单独编译为完整 C++ 程序 |
| 清单 7-1 排序伪代码 | 原文缺少类型与操作定义；用具有真实特质的等价测试结构验证实际排序 |
| 排序、canonicalize、下沉、CSE、LICM、mem2reg、拓扑排序、SROA、内联 | 全部实际运行相应 Pass，输入输出永久保存 |
| 未知副作用 CSE、公开函数内联、SCCP 死路径 | 三个反例实际通过，支持正文的重要概念修正 |
| 运行时验证 | 实际生成检查代码；未执行生成后的机器代码 |
| 四幅图 | 已逐图检查扫描并重绘 Mermaid，由主校对流程统一渲染验收 |

结构检查实际输出：`PASS: 17 pages, 17 listings, 4 figures, 5 footnotes; 14 MLIR listings + 1 TableGen fragment verified`。示例验证属于解析、IR 合法性和 Pass 变换结果检查，并未声称对所有优化做运行时等价性穷举。未独立解决的仅为上述性能测试范围和 Polygeist 引入历史细节；它们已明确标注，正文算法、代码与图示不依赖这些历史或性能断言。
