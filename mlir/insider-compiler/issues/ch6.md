# 第6章校订记录

校订对象：[第6章 Markdown](../insider-compiler-ch6.md)。源文件 `pdf/insider-compiler-ch5-ch6.pdf` 的 PDF 第 17–37 页，印刷页 107–127。21 页全部逐页通过 `view_image` 查看；4 图均核对节点、连线及图旁文字后用 Mermaid 重绘；保留代码清单 6-1 至 6-14、表 6-1 的全部 7 个比较维度及四条脚注。

本地核对基准：LLVM **18.1.8**，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`，`/opt/llvm-project`。`mlir-opt` 实际输出版本 18.1.8，Debug 且启用 assertions。原书以 LLVM 20 为背景：本地不存在的内部实现不直接判作 OCR 错误；差异较大的清单 6-13、6-14 在正文使用本地对应代码，原书完整片段保留于本记录。

## 页覆盖

| PDF 页 | 印刷页 | 内容 |
| --- | --- | --- |
| 17 | 107 | 章题、引言、SSA 与匹配、区域脚注 |
| 18 | 108 | 优化范围、6.1 三部分、6.1.1 开头 |
| 19 | 109 | 图 6-1、图 6-2、清单 6-1 前半 |
| 20 | 110 | 清单 6-1 后半、三种模式编写方式、6.1.2 开头 |
| 21 | 111 | 图 6-3、Rewriter 比较、清单 6-2 前半 |
| 22 | 112 | 清单 6-2 后半、清单 6-3 前半 |
| 23 | 113 | 清单 6-3 后半、6.1.3、清单 6-4 前半 |
| 24 | 114 | 清单 6-4 后半、6.2、6.2.1 开头 |
| 25 | 115 | 贪婪驱动步骤、终止条件、模式排序、遍历脚注 |
| 26 | 116 | 图 6-4、MultiOp 驱动、清单 6-5 |
| 27 | 117 | 自顶向下命令及清单 6-6 前半 |
| 28 | 118 | 清单 6-6 后半、自底向上命令、清单 6-7 前半 |
| 29 | 119 | 清单 6-7 后半、清单 6-8 及应用讲解 |
| 30 | 120 | 6.2.2、三种区别、清单 6-9、6-10 |
| 31 | 121 | 延迟替换与值映射、清单 6-11、类型物化 |
| 32 | 122 | 类型物化、清单 6-12 前半、Toy 项目脚注 |
| 33 | 123 | 清单 6-12 后半、事务性问题引入、合法化图 |
| 34 | 124 | OpA/OpB/OpC 示例、事务性、清单 6-13、6-14 前半 |
| 35 | 125 | 清单 6-14 后半、三种转换方式、动态合法性 |
| 36 | 126 | 6.2.3、折叠、表 6-1 前六项 |
| 37 | 127 | 表 6-1 第七项、开发者大会引用、6.3、文献脚注 |

## 基础概念修订

<a id="ch6-foundations"></a>

### SSA、DAG、Pass 与优化范围（PDF 17–18）

- 原书把“整个程序的 Use-Def 信息通常是 DAG”直接归因于 SSA。SSA 数据流通过循环和基本块参数可以形成依赖环，不能据此推断全程序有向无环。正文保留 DAG 匹配的引入，但限定为无循环依赖的局部表达式。
- 匹配/重写框架并非必须基于 Pass 才可使用。`PatternApplicator`、`applyPatternsAndFoldGreedily` 等 API 接收操作、模式与上下文，调用者不必须是 Pass。常见做法是在 Pass 中使用，仍需遵守 Pass 约束。
- `IsolatedFromAbove` 不会“切断全部 Def-Use 联系”，只禁止嵌套区域隐式捕获上层 SSA 值；嵌套内部的 SSA 联系、符号引用等仍在。该约束也不意味着所有优化只能在一个基本块中进行。
- CSE 的通用实现不需要为每种操作编写独立匹配模板，而使用等价性、副作用、支配关系等通用信息。不能从 CSE 的 Pass 实现推出模式系统不具备通用操作匹配能力。
- 原文对 DAG 匹配和自底向上遍历性能的概括改为限定性描述，不声明一种策略对所有程序都最佳。

依据：[MLIR LangRef 的 Blocks 和 Regions](/opt/llvm-project/mlir/docs/LangRef.md)、[Traits 的隔离约束](/opt/llvm-project/mlir/docs/Traits/_index.md)、[CSE.cpp](/opt/llvm-project/mlir/lib/Transforms/CSE.cpp)、[GreedyPatternRewriteDriver.h](/opt/llvm-project/mlir/include/mlir/Transforms/GreedyPatternRewriteDriver.h:36)、[PassManagement.md](/opt/llvm-project/mlir/docs/PassManagement.md:25)。

<a id="ch6-pattern-api"></a>

### Pattern 构造器和重载声明（PDF 19–20）

清单 6-1 原书任意操作构造器写为 `RewritePattern(benefit, MatchAnyOpTypeTag())`，本地构造器是标签、收益、上下文，不能省略 `MLIRContext *`。正文增加对应重载 `MyPattern(MatchAnyOpTypeTag tag, PatternBenefit benefit, MLIRContext *context)`。原书的 `rewrite` 和 `matchAndRewrite` 缺少 `const`，不能正确覆盖基类方法；正文采用 `const override`。两种实现方式是分别覆盖 `match` / `rewrite`，或者覆盖合并入口，不能误以为必须三个都实现。

根操作过滤只筛出候选根，不自动保证完整子图满足模式约束。`OpRewritePattern<MyOp>` 的意义也据此澄清。

依据：[PatternMatch.h 构造器](/opt/llvm-project/mlir/include/mlir/IR/PatternMatch.h:179)、[RewritePattern 的虚函数](/opt/llvm-project/mlir/include/mlir/IR/PatternMatch.h:251)。已经包含完整头文件，以 `clang++ -std=c++17 -fsyntax-only` 验证 [API 检查文件](evidence/ch6-pattern-api.cpp)，退出码 0。原书使用的 MyOp 及业务实现未完整给出，不能把声明检查说成完整模式编译运行。

<a id="ch6-applicator"></a>

### 候选类别与收益排序（PDF 18、23–25）

原书一处说固定按常规模式、任意模式、PDL 模式依次匹配，另一处说明同优先级时才如此，前者过于绝对。正文统一为先比较收益，平局时按特定操作原生模式、通用原生模式、PDL 的次序选择。原生模式包括手写 C++ 与 DRR 生成的 C++；`Pat` 是 TableGen 记录，不是 `pat` 方言。社区通常称声明式规则为 DRR，保留原书 TDRR 的全称并注明对应关系。

本地 PatternApplicator 在原生模式之前先运行 PDL 字节码以收集候选，此时不执行重写；然后在各候选之间选择收益最高者，首次成功重写后结束这次调用。这个实现细节不等于 PDL 重写一定先执行。

依据：[PatternApplicator.cpp](/opt/llvm-project/mlir/lib/Rewrite/PatternApplicator.cpp:126)，其中第 132 行开始匹配 PDL 字节码，第 159 行起比较候选收益，第 208 行附近执行实际重写；[DeclarativeRewrites.md](/opt/llvm-project/mlir/docs/DeclarativeRewrites.md)。清单 6-4 的失败分支补 `return`，使注释与实际控制流一致。

<a id="ch6-rewriters"></a>

### Rewriter 继承与通知机制（PDF 19、21）

原书注意框称 Operation 继承自 OpBuilder，这不是版本差异，而是错误的继承关系。Operation 实际继承 intrusive list 节点等内部设施；RewriterBase 才继承 OpBuilder。原书还称 IRRewriter 只匹配/重写一次，PatternRewriter 只处理当前操作且自身提供贪婪行为，同样不准确。两者均为重写接口，是否匹配、遍历多少次由驱动决定；IRRewriter 适用于模式驱动之外。

正文图 6-2 的全部节点已在本地找到，完整保留，没有因为 OCR 长名称换行而删节点。其主体为 Pattern → RewritePattern，具体模式直接派生自 RewritePattern；OneToN 链为 RewritePatternWithConverter → OneToNConversionPattern → OneToNOpConversionPattern。图 6-3 也保留全部节点，并说明 Greedy 两个派生驱动的范围。

依据：

- [Operation.h](/opt/llvm-project/mlir/include/mlir/IR/Operation.h:83)、[PatternMatch.h](/opt/llvm-project/mlir/include/mlir/IR/PatternMatch.h:399)、[IRRewriter 和 PatternRewriter](/opt/llvm-project/mlir/include/mlir/IR/PatternMatch.h:720)。
- [OneToNTypeConversion.h](/opt/llvm-project/mlir/include/mlir/Transforms/OneToNTypeConversion.h:124) 的 RewritePatternWithConverter、OneToNPatternRewriter 及派生模式链。
- [VectorDropLeadUnitDim.cpp](/opt/llvm-project/mlir/lib/Dialect/Vector/Transforms/VectorDropLeadUnitDim.cpp:473)：CastAwayElementwiseLeadingOneDim。
- [VectorUnroll.cpp](/opt/llvm-project/mlir/lib/Dialect/Vector/Transforms/VectorUnroll.cpp:421)：UnrollElementwisePattern。
- [CommutativityUtils.cpp](/opt/llvm-project/mlir/lib/Transforms/Utils/CommutativityUtils.cpp:230)：SortCommutativeOperands。
- [Linalg/Transforms/Loops.cpp](/opt/llvm-project/mlir/lib/Dialect/Linalg/Transforms/Loops.cpp:259)：LinalgRewritePattern、FoldAffineOp。
- [ElementwiseToLinalg.cpp](/opt/llvm-project/mlir/lib/Dialect/Linalg/Transforms/ElementwiseToLinalg.cpp:77)：ConvertAnyElementwiseMappableOpOnRankedTensors。
- [LinalgTransformOps.cpp](/opt/llvm-project/mlir/lib/Dialect/Linalg/TransformOps/LinalgTransformOps.cpp:3004)：VectorizationPattern；同文件及 PDLExtensionOps.cpp 均有 TrivialPatternRewriter 的局部定义。

<a id="ch6-drr"></a>

### OpN / OpP 规则及生成代码（PDF 21–23）

源 TD 确有两个 I32 操作数的 OpN、六个 I32 操作数的 OpP，以及 `TestNestedOpEqualArgsPattern`。正文将误识别的 `OpR`、`OP_P`、`Sb` 等改为 `OpP`、`op_p`、`$b` 等；清单 6-3 根据本地生成文件补齐七个捕获变量、空定义检查以及原书省略的操作数捕获，去掉多出的闭括号和重复 `(void)odsLoc`。

本地生成器把外层第一个操作数命名为 b，内层 OpP 第二个操作数命名为 b0；原书相反。捕获名字是生成细节，两个值相等的匹配要求未变。默认 benefit 2 来自源模式中的两个操作，并非所有手写模式都会自动获得这种收益。

依据：[TestOps.td](/opt/llvm-project/mlir/test/lib/Dialect/Test/TestOps.td:1030)、[本地生成 TestPatterns.inc](/opt/llvm-project/build/tools/mlir/test/lib/Dialect/Test/TestPatterns.inc:554)、[对应社区测试](/opt/llvm-project/mlir/test/mlir-tblgen/pattern.mlir:153)。

独立实测使用如下两种输入结构，六个函数参数均为不同的 i32 SSA 值：

```mlir
// 匹配：OpN 的第一个输入 b 与 OpP 的第二个输入 b 相同。
%p = "test.op_p"(%a, %b, %c, %d, %e, %f)
    : (i32, i32, i32, i32, i32, i32) -> i32
%n = "test.op_n"(%b, %p) : (i32, i32) -> i32
return %n : i32

// 不匹配：OpN 的第一个输入 a 与 OpP 的第二个输入 b 不同。
%p = "test.op_p"(%a, %b, %c, %d, %e, %f)
    : (i32, i32, i32, i32, i32, i32) -> i32
%n = "test.op_n"(%a, %p) : (i32, i32) -> i32
return %n : i32
```

执行 `mlir-opt -test-patterns` 成功：匹配函数的返回值变成 `%arg1`（b），不匹配函数保留 `test.op_n`。这验证了等值条件，不能只用一个正例宣称模式正确。已保存[完整正负例输入](evidence/ch6-drr.mlir)及[实际输出](evidence/ch6-drr-out.mlir)。从仓库根目录可复现：

```sh
/opt/llvm-project/build/bin/mlir-opt \
  mlir/insider-compiler/issues/evidence/ch6-drr.mlir \
  -test-patterns -o /private/tmp/ch6-drr-out.mlir
diff -u mlir/insider-compiler/issues/evidence/ch6-drr-out.mlir \
  /private/tmp/ch6-drr-out.mlir
```

<a id="ch6-greedy"></a>

### 贪婪驱动、图 6-4 与终止（PDF 25–26、29）

原图 6-4 有实质性错误：循环条件用“worklist 不为空 **或者** IR 修改次数不超过阈值”，实际应为逻辑与；死亡操作节点将删除路径接在“否”分支，实际死亡操作应删除并继续下一项；原图把所有匹配都说成自顶向下，也与可配置的初始顺序矛盾。正文 Mermaid 按实际流程重绘，包含外层迭代、收集工作列表、取尾部操作、死代码删除、折叠、模式应用、区域简化和收敛判断全部阶段。

源码为 `while (!worklist.empty() && (numRewrites < maxNumRewrites || maxNumRewrites == kNoLimit))`。死亡操作先删除，然后 `continue`；常量类操作不再重复折叠，避免常量物化循环。自底向上的初始化用 region 后序遍历；自顶向下用前序遍历再 reverse，工作列表从尾部取出。addToWorklist 可添加作用域内祖先并去重，但并非无条件添加所有祖先或跨出所选 scope。

原书“最大迭代次数能防止死循环”不完整。`maxIterations` 默认 10，只限制外层区域迭代；`maxNumRewrites` 默认 `-1` 不限制单轮模式重写。因此错误模式在一轮中无限产生新操作时，外层限制不保证终止。公开驱动返回值表示是否收敛，不能与每个模式是否重写、内部本轮是否 changed 混为一谈。

MultiOp 驱动并非输入操作在不同直接父区域中就不再贪婪处理；未指定 scope 时会寻找公共祖先区域，后续入队受 scope 和 strictMode 控制。删除的操作本身不会再入队，应是仍存活的相关操作入队。代码 6-8 的“无匹配模式”也不表示驱动不会进行折叠或死代码检查。

依据：[GreedyPatternRewriteDriver.cpp 工作列表](/opt/llvm-project/mlir/lib/Transforms/Utils/GreedyPatternRewriteDriver.cpp:443)、[区域驱动](/opt/llvm-project/mlir/lib/Transforms/Utils/GreedyPatternRewriteDriver.cpp:777)、[MultiOp 公共作用域](/opt/llvm-project/mlir/lib/Transforms/Utils/GreedyPatternRewriteDriver.cpp:964)、[GreedyRewriteConfig](/opt/llvm-project/mlir/include/mlir/Transforms/GreedyPatternRewriteDriver.h:36)。

<a id="ch6-logs"></a>

### 日志忠实转写与实测边界（PDF 27–29）

代码清单 6-6、6-7 保留原书的日志结构、操作顺序和解释注释，并纠正 OCR、标点、`i32` / `func.func` / `scf` 等拼写。原书日志中的 `The initial op to be processed at N times` 及单独列举的工作列表，不存在于本地驱动日志字符串中，故明确标为书中带注释的示意日志，不能冒充本地原样输出。原书地址保留作历史示意，不据此识别当前对象。

解释注释中另纠正：yield 的输入是 `%0`，不是 `%if`；yield 是终结操作，并非因没有 SSA 结果使用者即可独立当作死代码删除，而是删除整个 if 时随内嵌区域一起删除。原注释混用前序/后序以及工作列表存放顺序/出队顺序，已按本地驱动说明。

实际执行与证据：

- 输入：[ch6-greedy.mlir](evidence/ch6-greedy.mlir)。
- `mlir-opt '-test-patterns=top-down=true' -debug-only=greedy-rewriter`：[完整日志](evidence/ch6-greedy-top-down.log)、[结果 IR](evidence/ch6-greedy-top-down.mlir)。操作处理次数 12（7 + 3 + 2），三轮。
- `mlir-opt '-test-patterns=top-down=false' -debug-only=greedy-rewriter`：[完整日志](evidence/ch6-greedy-bottom-up.log)、[结果 IR](evidence/ch6-greedy-bottom-up.mlir)。操作处理次数 8（6 + 2），两轮。

两个结果均只保留参数及 return，处理较少不等同于已经证明运行时间更短；本次未做性能基准测试。

## 方言转换的重要修订

### 类型映射、物化方向和职责（PDF 30–32）

原书将“延迟重写”和“类型映射”描述为两种替代实现，然后称 MLIR 选择第一种。实际同时存在延迟替换及 `ConversionValueMapping`，该映射记录旧 SSA 值和转换后值，远不只是新旧类型表。`operands` 和 OpAdaptor 提供映射后的 SSA 值，让模式同时读取源操作信息和使用目标操作数。

原书称 ConversionPattern 重载 rewriter 的事件函数，混淆了模式与重写器：ConversionPattern 定义匹配，ConversionPatternRewriter 管理修改及回滚通知。原书 source materialization 将目标值称为“非法目标类型”，同段又称其合法，正文按接口修正为合法目标表示到旧源表示；target 是源到目标，argument 处理块参数签名转换时的物化。

类型转换并非每个 dialect conversion 都必须发生。full/partial 的合法性规则也不等于“所有高级方言操作与类型都必须消失”。

依据：[DialectConversion.h 物化](/opt/llvm-project/mlir/include/mlir/Transforms/DialectConversion.h:168)、[ConversionPattern](/opt/llvm-project/mlir/include/mlir/Transforms/DialectConversion.h:380)、[ConversionValueMapping](/opt/llvm-project/mlir/lib/Transforms/Utils/DialectConversion.cpp:58)。

<a id="ch6-conversion-example"></a>

### Toy 转换示例的局限及修复（PDF 32–33）

清单 6-12 修复：

- 空输入会访问 `inputs[0]` 越界，先拒绝空输入。原书没有规定零项相加的语义，未擅自设为某种零值。
- C++ 标识符统一为 `runOnOperation`、`arith::AddIOp`、`addDynamicallyLegalOp`、`UnrealizedConversionCastOp` 等正确大小写，并补 `const override`。
- TypeConverter 增加一般类型恒等转换，再注册 ToyIntegerType 特例；回调按逆序尝试，使合法的非 Toy 类型不会因无规则而转换失败。
- `addLegalDialect<arith::ArithDialect>()` 不是“仅 arith 合法、所有其他操作非法”的声明。显式标记必须移除的 MyAddOp 非法，并要求完整示例对其他必须移除的源操作或源方言作出同样声明。
- 原检查只看操作数类型，漏了结果、函数签名和块参数。正文示意采用 `converter.isLegal(op)` 并单独检查函数签名与 body。
- 不把 target materialization 当作完整类型处理；可能还需 source / argument materialization。UnrealizedConversionCastOp 是类型连接占位，允许其在阶段中保留不等于已经生成最终可执行语义。

本地没有该书自定义 Toy 方言的全部定义，原书也未列出 SubOpPat、ConstantOpPat、ReturnOpPat、CallOpPat 等实现。ReturnOp、CallOp、FuncOp 的具体归属与签名需由该外部项目确认，不能仅根据书中短片段证明整个 Pass 正确。正文清楚标为依赖缺失定义的结构性示例，而没有声称端到端运行成功。整数类型、同宽性及结果类型要求仍需由 MyAddOp 的验证器和转换规则确保；若其契约不保证这些条件，模式必须在修改 IR 前显式检查。

依据：[DialectConversion.h 类型规则与合法性接口](/opt/llvm-project/mlir/include/mlir/Transforms/DialectConversion.h:274)、[TypeConverter 实现](/opt/llvm-project/mlir/lib/Transforms/Utils/DialectConversion.cpp:2965)。原书脚注链接经扫描目视还原，历史访问时间保留；本次没有将外部仓库当作已编译的本地代码。

<a id="ch6-legalization"></a>

### 合法化图不等于 SSA 依赖图（PDF 33–34）

原书先称“模式输出是另一个模式输入”构成依赖，随后以 OpC 使用 OpA 的结果为由，断言必须先 Pattern1(OpA)，再 Pattern3(OpC)，最后 Pattern2(OpB)，并称这样就能保证全部降级。这混淆了两个层次：

1. 模式合法化图以模式可能 **生成的操作名称** 为依据，评估这些操作能否继续合法化、路径多深。
2. 程序中的 SSA 使用关系连接 **具体操作结果值**，通过值映射和遍历顺序处理，不能直接推导上述固定模式执行次序。

正文保留 HighDialect、LowDialect、OpA/OpB/OpC、三个 Pattern 及 OpC 使用 OpA 的设定，并解释三者若都直接产生合法目标操作，就各自具有直接合法化路径；SSA 依赖不意味着 Pattern3 在模式图中依赖 Pattern1。合法化图只是辅助选路，动态约束仍可能导致失败。

依据：[buildLegalizationGraph](/opt/llvm-project/mlir/lib/Transforms/Utils/DialectConversion.cpp:2112)、[computeOpLegalizationDepth](/opt/llvm-project/mlir/lib/Transforms/Utils/DialectConversion.cpp:2222)、[applyCostModelToPatterns](/opt/llvm-project/mlir/lib/Transforms/Utils/DialectConversion.cpp:2248)。实际输入操作遍历使用 [PreOrder 和 ForwardDominanceIterator](/opt/llvm-project/mlir/lib/Transforms/Utils/DialectConversion.cpp:2410)。

<a id="ch6-transaction-version"></a>

### 事务性与 LLVM 20 相关片段（PDF 33–35）

原书反复称 `create` / `replaceOp` / `eraseOp` 等“不会真正修改或创建操作，只记录行为，最后统一执行”。实际创建会立即插入新操作；原位更新也会发生并保存旧状态。替换、删除等一部分动作延迟提交；失败时撤销已经发生的动作并丢弃延迟动作。某个模式失败也不等于整体立即失败，驱动可以撤销该模式尝试并继续寻找其他方案。

依据：[DialectConversion.cpp 的 discardRewrites / applyRewrites](/opt/llvm-project/mlir/lib/Transforms/Utils/DialectConversion.cpp:1017)、[getCurrentState / resetState](/opt/llvm-project/mlir/lib/Transforms/Utils/DialectConversion.cpp:1092)、[插入通知](/opt/llvm-project/mlir/lib/Transforms/Utils/DialectConversion.cpp:1609)、[原位更新保存](/opt/llvm-project/mlir/lib/Transforms/Utils/DialectConversion.cpp:1617)。

原书明确写“以 LLVM 20 为例”的清单 6-13 如下，已按扫描修复 OCR，11 个枚举项全部保留。本地 LLVM 18.1.8 不含这一统一枚举，故正文列本地七组状态记录作为对应说明。这里不声称已经取得并验证 LLVM 20 的精确对应实现。

```cpp
// 原书代码清单 6-13：系统在方言降级过程中的 11 种行为。
enum class Kind {
  // 基本块行为。
  CreateBlock,
  EraseBlock,
  InlineBlock,
  MoveBlock,
  BlockTypeConversion,
  ReplaceBlockArg,
  // 操作行为。
  MoveOperation,
  ModifyOperation,
  ReplaceOperation,
  CreateOperation,
  UnresolvedMaterialization
};
```

原书清单 6-14 的完整转写如下，注意这也是版本相关的内部实现片段，不是本地 API：

```cpp
// 原书：记录操作的创建或移动行为，行为对象存储于 SmallVector。
void ConversionPatternRewriterImpl::notifyOperationInserted(
    Operation *op, OpBuilder::InsertPoint previous) {
  // ...
  if (!previous.isSet()) {
    // 记录创建行为，用 CreateOperationRewrite 表示。
    // appendRewrite 将行为对象放入 SmallVector 中。
    appendRewrite<CreateOperationRewrite>(op);
    return;
  }
  // 如果不是创建行为，说明是移动操作，用 MoveOperationRewrite 表示。
  Operation *prevOp = previous.getPoint() == previous.getBlock()->end()
                          ? nullptr
                          : &*previous.getPoint();
  appendRewrite<MoveOperationRewrite>(op, previous.getBlock(), prevOp);
}
```

本地签名是 `ConversionPatternRewriter::notifyOperationInserted(Operation *op)`，调用 `impl->createdOps.push_back(op)`。差异涉及类归属、参数、记录组织，不能当作标点或 OCR 差错简单替换。即使在原书版本中，`notifyOperationInserted` 的意义也是对已经发生的插入进行通知和记录，不能从“记录创建行为”推出“尚未创建 IR”。

### 三种转换方法（PDF 35）

原书 full conversion 描述为每个操作都重写，甚至与 MLIR 到 LLVM IR 翻译混为一谈。实际上 full 要求所有剩余操作均合法，已合法操作不需重写；生成 LLVM IR 属于另一个翻译层。partial 会尽可能合法化，显式非法操作未能合法化才必须失败，未知操作可保留。

原书 analysis conversion 称“不会执行重写”。实际它会执行推测性匹配和重写，再通过 `discardRewrites()` 撤销；它关心哪些操作可合法化，不因某些操作不可合法化就必然失败。成功返回不能替代检查已转换操作集合。

依据：[DialectConversion.h 三种入口契约](/opt/llvm-project/mlir/include/mlir/Transforms/DialectConversion.h:1072)、[OperationConverter::convert](/opt/llvm-project/mlir/lib/Transforms/Utils/DialectConversion.cpp:2374)、[分析模式在成功后撤销](/opt/llvm-project/mlir/lib/Transforms/Utils/DialectConversion.cpp:2444)。

<a id="ch6-comparison"></a>

### 折叠及表 6-1（PDF 36–37）

原书称折叠不会删除任何节点，事实不符。fold 方法返回结果后，驱动可替换结果并删除原操作。原书也笼统说“始终先折叠”，但转换驱动先检查目标合法性，已合法操作可以直接返回；贪婪驱动先检查平凡死亡，再尝试非 ConstantLike 操作的折叠，再应用模式。

表中保留全部比较项，并修正：

- 匹配方式：转换不只处理显式非法操作；unknown 的处理依 full / partial 而定。
- 类型处理：TypeConverter 可选，不是所有方言转换都必须改变类型；贪婪模式也可以处理类型，但没有转换框架的统一协调。
- 回滚：说明本地转换驱动行为，不外推全部未来版本。
- 遍历顺序：合法模式应保持语义，但顺序可能改变最终 IR、匹配机会及终止行为。
- 顺带执行优化：折叠与死代码消除不能混为一项返回语义。
- 成功/失败：单个模式的 `LogicalResult`、工作列表的 changed、公开贪婪驱动的 converged，以及转换入口整体的合法化结果是不同概念。无修改却成功可能反复应用；修改后失败违反模式契约，不能仅说“终止迭代”。
- 重写模式：绕过通知可能破坏状态或崩溃，不是每次都立即崩溃；仍必须通过正确重写接口更新。

依据：[GreedyPatternRewriteDriver.cpp](/opt/llvm-project/mlir/lib/Transforms/Utils/GreedyPatternRewriteDriver.cpp:463)，第 550 行附近执行 fold 后 `replaceOp`；[区域驱动的收敛返回值](/opt/llvm-project/mlir/lib/Transforms/Utils/GreedyPatternRewriteDriver.cpp:839)；[OperationLegalizer::legalize](/opt/llvm-project/mlir/lib/Transforms/Utils/DialectConversion.cpp:1807)；[PatternMatch.h](/opt/llvm-project/mlir/include/mlir/IR/PatternMatch.h:245)。

## 验证结论和剩余边界

本章全部 PDF 页已目视，全部图和代码清单均完成校对。运行证据包括：两种贪婪遍历输出与完整日志、模式 API 声明的 C++ 语法检查、DRR 相等/不等两种实际匹配输入。未运行缺少方言定义的完整 Toy 转换，未编译原书 LLVM 20 内部事务记录代码，未进行性能基准测试。原始 Apple Vision OCR 未改写。

四张 Mermaid 图依据原图与本地继承/控制流实现转写，已核对语义并通过 Mermaid 渲染检查；图 6-2 使用左右布局使子类纵向排列。没有因图像模糊而遗留的无法辨读段落。
