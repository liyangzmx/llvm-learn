# aiversion 教材核查问题清单

- 核查对象：`/opt/coding/mlir-toy/aiversion/` 第 0～7 章及相关 `README.md`、`SOURCES.md`、`VALIDATION.md`
- 代码基准：`/opt/llvm-project` `release/18.x` / `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`（= tag `llvmorg-18.1.8`）
- 核查日期：2026-09-12
- 核查性质：只读。本清单本身是唯一被写入的文件；核查过程未修改 `aiversion/`、`official/`、`scripts/`、LLVM 源码或任何既有文件。

## 0. 核查方法与总体结论

方法：
1. 通读 aiversion 全部 8 章与三份说明文档，并阅读 `scripts/validate-materials.mjs`。
2. 运行只读校验脚本 `node scripts/validate-materials.mjs`。
3. 逐处比对全部带行号的源码引用；对未带行号但断言"本地实现为 X"的论断到 `/opt/llvm-project/mlir/examples/toy/ChN` 抽样核对。
4. 对比 `official` ↔ `aiversion` ↔ 官方英文原件 `mlir/docs/Tutorials/Toy/Ch-N.md` 的结构、翻译与代码块。

总体结论：**内容事实准确度很高，问题集中在"来源标注与校验覆盖"，而非知识性错误。**

硬证据：
- 校验脚本 `PASS`（退出码 0）：
  `{"documents":20,"localLinks":148,"sourceExcerpts":34,"mermaidBlocks":13,"bashBlocks":30,"sourceFiles":186,"expandedChapters":7,"testPaths":51}`
- 17 处带行号的 `[源码：…]` 摘录：**17/17 逐字一致（含注释与缩进），行号全部落在所引函数/结构体首行**，0 处路径/行号错误。
- 点名的关键论断全部成立（见 §5 已核实清单）。
- Ch1–Ch7 共 28 道练习 + Ch0 3 道自测，答案逐条对源核对全部正确。
- `official` 正文在 aiversion 中被逐字节完整承接（`cmp` 验证，唯一差异是 H1 标题）。

问题分级：**P0 = 影响可信度/自相矛盾；P1 = 表述或覆盖缺陷；P2 = 小瑕疵。**

---

## A. 代码块来源标注与校验覆盖（P0）

### A1. 各章"标明示意"的承诺未兑现，未标注的代码块多为改写/翻译版

- 位置：`aiversion/01..07` 各章第 5 行（例：`aiversion/01-from-source-to-ast.md:5`）；承诺文本见 `official/README.md:34`（"C++ 标识符、API 和源代码注释在摘录中保留原貌"）与 `SOURCES.md:54`（"源码摘录保留英文注释"）。
- 现象：两套文档共 **115 个 `c++`/`tablegen`/`mlir` 代码块，仅 34 个带 `[源码：路径:行号]` 锚点并受 `validate-materials.mjs:65-77` 逐行校验，覆盖率约 30%**（`115/34` 由脚本实测）。其余 81 个未标注块中，多数是改写、翻译或裁剪版，却与受校验块外观一致，读者无法区分"逐字源码"与"教学简化"。
- 代表性差异（全部经手工核对）：

| # | 位置 | 文档写法 | 本地/英文真值 |
|---|---|---|---|
| 1 | `aiversion/04:140` | `InterfaceMethod<"Infer result shapes", "void", "inferShapes">` | `Ch4/include/toy/ShapeInferenceInterface.td:25` 为 `"Infer and set the output shape for the current operation."` |
| 2 | `aiversion/04:138` | `let description = [{根据已知输入推断并设置操作的结果形状。}];` | 本地/英文为英文 description（同文件 :19-22） |
| 3 | `aiversion/04:169` | `op->emitError("缺少 shape inference 接口");` | `Ch4/mlir/ShapeInferencePass.cpp:87` 为英文串，且原文含 `LLVM_DEBUG` 行（:83） |
| 4 | `aiversion/02:50-55` | Toy_Dialect 仅 name/cppNamespace/summary，summary 为中文 | `Ch2/include/toy/Ops.td:23-26` 只有 name/cppNamespace（无 summary）；英文 `Ch-2.md:191-211` 有英文 summary+description |
| 5 | `aiversion/03:29-44` | `using OpRewritePattern::OpRewritePattern;`、`rewriter.replaceOp(op, inner.getOperand());` | `Ch3/mlir/ToyCombine.cpp:33-34` 显式构造 `/*benefit=*/1`；:72 为 `replaceOp(op, {transposeInputOp.getOperand()})`；**benefit 语义在正文中彻底消失** |
| 6 | `aiversion/03:49-51` | 形参名 `patterns`/`ctx` | `Ch3/mlir/ToyCombine.cpp:57-59` 为 `results`/`context` |
| 7 | `aiversion/03:57-58` | `pm.addNestedPass<toy::FuncOp>(...)` | `Ch3/toyc.cpp:129` 为 `mlir::toy::FuncOp`，且省略 :123 的 PassManager 构造 |
| 8 | `aiversion/07:44-63` | `explicit StructTypeStorage(...)`，省略 `hashKey`/`getKey` | `Ch7/mlir/Dialect.cpp:517/529-541` 无 `explicit`，两钩子存在（正文 §10 另有说明） |
| 9 | `aiversion/07:93` | `CPred<"isa<StructType>($_self)">` | `Ch7/include/toy/Ops.td:51` 为 `CPred<"::llvm::isa<StructType>($_self)">` |
| 10 | `aiversion/07:150-160` | `StructAccessOp::fold` 直接 `values[getIndex()]` | `Ch7/mlir/ToyCombine.cpp:38-45` 含中间变量 `structAttr`/`elementIndex` 与 `dyn_cast_if_present` 分支 |
| 11 | `official/05:27` | Type Converter 定义为"转换结果、操作数和块参数类型" | 英文 `Ch-5.md:46-49` 只说转换 block arguments，并明确 "We won't be needing this for our conversion."（§10 有补正） |

- 说明：上表 1–11 中，2/3/4/5/6/7/8/9/10 位于 aiversion 各章的 **official 前半段**（同位置也存在于 `official/`），因 aiversion 逐字承接而一并出现。
- 建议：为代码块建立三态标注（`逐字源码` / `示意` / `译编`），并让校验脚本统计各态数量；把上表 11 处显式标为"示意/译编"，或将文案改回逐字。

### A2. "34 处源码摘录逐行核对通过"未限定覆盖范围

- 位置：`VALIDATION.md:9`、`SOURCES.md:70`。
- 现象：表述为已核对通过，但未说明它只覆盖 115 个源码类代码块中的 34 个（30%），未标注块不在校验范围。
- 建议：补一句限定，例如"34 处带源码锚点的摘录已逐行核对；其余讲解性代码块不在校验范围内"。

---

## B. 表述与事实边界（P1）

### B1. `aiversion/05:198` "原文旧片段常省略第二个参数" 无本地文本依据

- 位置：`aiversion/05-progressive-lowering.md:198`（及 official 同段）。
- 现象：断言官方旧片段常省略 `memRefOperands`。但本地英文 `Ch-5.md:118-141` 的回调三参数齐全（`rewriter`、`memRefOperands`、`loopIvs`），且 :121-124 的文字明确说明 functor 操作重映射 operands 与归纳变量。
- 独立复核：两次独立核查均确认该说法在 release/18.x 文本中无法证实，疑似对更早版本教程的印象。
- 建议：改为"本地回调固定为 `(builder, memRefOperands, loopIvs)`，两者都依赖第二个参数"。这是全材料**唯一一处"原文如何如何"式过度断言**。

### B2. `aiversion/04:235` 残留注释的归属易误读

- 位置：`aiversion/04-interfaces-and-shapes.md:235`。
- 现象：把"原文文件顶部残留'跨过程专门化'的注释"紧接在 `Ch4/toyc.cpp` 链接之后；该注释实际位于 `Ch4/mlir/ShapeInferencePass.cpp:9-10`（`interprocedural ... through function specialization`），而同类 :39-40 又自称 intra-procedural。论断内容为真，仅归属易被读成 toyc.cpp。
- 建议：明确写出文件与行号。

### B3. `aiversion/04` §6 未提 Ch4 流水线受 `-opt` 门控

- 位置：`aiversion/04-interfaces-and-shapes.md` §6（约 :207-235）。
- 现象：`Ch4/toyc.cpp:124` 的 `if (enableOpt)` 包住了 Inliner、ShapeInference、Canonicalizer、CSE 全部 pass；不加 `-opt` 时 ch4 不做内联与形状推断。正文只描述"显式顺序"，未说明这一前置条件（对比：Ch6 §4 明确说明了"即使没有 -opt 也要运行准备阶段"，处理得更严谨）。
- 建议：补一句门控说明。

### B4. `aiversion/README.md:20` "每章前半部分/后半部分" 对 Ch2 不准

- 位置：`aiversion/README.md:20`。
- 现象：Ch2 的 official 承接部分为 267/388 ≈ 69%，并非"前半部分"。
- 建议：改为"每章先完整承接 official 正文，再追加扩充"。

---

## C. 内容覆盖缺口（P1）

### C1. Ch6 遗漏官方测试文件 `llvm-lowering.mlir`

- 证据：英文 `Ch-6.md:331` 引用 `test/Examples/Toy/Ch6/llvm-lowering.mlir`；该文件在本地真实存在，但 `official/` 与 `aiversion/` 全库 `grep llvm-lowering` 无命中。
- 影响：这是 Ch6 现成的 FileCheck 测试入口，本可用于"混合 IR→LLVM 方言"实验，属真实遗漏。
- 建议：在 Ch6 实验小节补上该文件的引用与命令。

### C2. "完整承接 official" 成立，但 aiversion 未补回 official 相对英文的压缩缺口

- 事实：`aiversion` 逐字节包含 `official` 正文（`cmp` 验证，仅 H1 标题不同）；校验脚本 `validate-materials.mjs:110-112` 的包含检查即 `full.startsWith(base)`，`:114` 只要求追加部分 ≥4 个 `## ` 且 ≥2500 字符。因此该"完整"是**复制粘贴式完整**，不能推出"官方英文原文被完整覆盖"。
- 体量对照（EN 行为官方英文原件）：

| 章 | EN 行 | official 行 | aiversion 行 | aiversion 追加行 | 追加占比 |
|---|---:|---:|---:|---:|---:|
| 1 | 131 | 119 | 220 | 101 | 43% |
| 2 | 726 | 267 | 388 | 121 | 30% |
| 3 | 262 | 149 | 242 | 93 | 39% |
| 4 | 463 | 237 | 361 | 124 | 33% |
| 5 | 350 | 233 | 372 | 139 | 34% |
| 6 | 334 | 230 | 406 | 176 | 40% |
| 7 | 516 | 248 | 411 | 163 | 40% |

- 缺失的关键内容（aiversion 中**同样缺失**，未被扩充补回）：
  - **Ch2（最严重）**：手写 C++ `ConstantOp` 全类（EN 254-311）、ODS `Toy_Op` 基类（EN 367-375）、`-gen-dialect-decls`/`-gen-op-defs`、`Adding Documentation` 整节、ODS `verifiers`/`builders` 段、`toy.print` 的 C++ parser/printer（EN 592-708）、两幅完整 IR dump。
  - **Ch3**：动机段（EN 47-71，25 行）、四段关键 IR（EN 134-139/155-159/229-240/245-253）、`class Pattern<...>` 签名。
  - **Ch4**：`CallableOpInterface`/`CallOpInterface` 教学线（EN 131-162）、`getCallableForCallee`/`setCalleeFromCallable`/`getArgOperands` 实现段（EN 164-185）、`OperationPass` 骨架（EN 393-409）、3 段示例 IR 只剩 1 段。
  - **Ch6**：约 130 行 IR/LLVM IR 清单（EN 121-172/195-227/229-245）压成一句散文。
  - **Ch7**：`parseType` 完整实现（EN 252-291）、`printType`（EN 295-315）、`StructTypeStorage` 的 `hashKey`/`getKey`（EN 104-119）。
- 建议：README/SOURCES 的措辞改为"aiversion 逐字包含 official 正文；official 覆盖官方七章的章节骨架与主线结论，但省略/压缩了较多代码块与 IR 清单（Ch2、Ch7 最明显）"，避免读者把"完整包含 official"读成"完整覆盖官方原文"。

---

## D. 小瑕疵（P2）

### D1. `aiversion/03:206` reshape 计数与所引测试文件不符

- 位置：`aiversion/03-rewriting.md:204-206`。
- 现象：工作示例只写 `var a<2,1>`、`var b<2,1>` 两个 reshape；而其参照的 `test/Examples/Toy/Ch3/trivial_reshape.toy:4-6` 实为 a/b/c 三个变量，原 IR 含 3 个 reshape（英文 `Ch-3.md:229-240` 列 `%1/%2/%3`）。
- 建议：补齐 `var c<2,1> = b;` 或说明此处为简化示意。

### D2. 校验脚本说明与"两套章节包含关系"的实际强度

- 位置：`scripts/validate-materials.mjs:110-114`、`SOURCES.md:70`。
- 现象：包含关系检查是字符串前缀比较，且对追加部分只做"≥4 个 `## ` 且 ≥2500 字符"的下限约束。它能证明"承接完整"，不能证明"扩充质量"或"覆盖官方原文"。文档未明确这一强度边界。
- 建议：在 `SOURCES.md` 校验范围处补一句限定。

---

## 5. 已核实为真、无需修改的项（避免误伤）

以下均经源码逐条核对成立，属于该材料的优点：

- 版本基准正确：`3b5b5c1ec4a3…` = `release/18.x` = `llvmorg-18.1.8`。
- 本地 `/opt/llvm-project/build` 未启用 MLIR：`LLVM_ENABLE_PROJECTS=clang;clang-tools-extra;`、`LLVM_BUILD_EXAMPLES=OFF`、`LLVM_TARGETS_TO_BUILD=BPF`，与第 0 章描述一致。
- 源码校正类论断全部为真，且优于英文原文本身：
  - Ch1 rank≤2 只是教学目标（`Parser.h:91-155` 任意深度递归；`LowerToAffineLoops.cpp:94-97` 用 `getRank()`）。
  - Ch1 "按调用签名专门化"未实现，Ch4 实为内联+函数内传播（`Ch4/toyc.cpp:130/135`）。
  - Ch1 Lexer 中 `print`/`transpose` 非关键字（`Lexer.h:31-50/142-148`；`Parser.h:203-207`）。
  - Ch1 优先级 `+`,`-`=20、`*`=40（`Parser.h:453-469`），Ch2 `MLIRGen.cpp:202-212` 只实现 `+`/`*`。
  - Ch1 `Parser.h:144` 在混合嵌套路径用 `cast` 而非 `dyn_cast`（文档指出属实）。
  - Ch2 `TransposeOp::build` 恒给 `tensor<*xf64>`（`Ch2/mlir/Dialect.cpp:297-301`）。
  - Ch2 `double` builder 造**零秩** `RankedTensorType::get({}, f64)`，非广播（`Ch2/mlir/Dialect.cpp:110-115`）。
  - Ch2 `ScopedHashTable<StringRef, Value>`（`MLIRGen.cpp:98`）。
  - Ch2 模块循环未检查 `mlirGen` 返回值（`MLIRGen.cpp:71-72`）；print 失败分支返回 `success`（`MLIRGen.cpp:419-421`）。
  - Ch2 `F64Tensor` 允许无秩、verifier 有秩才逐维比较（`Ch2/mlir/Dialect.cpp:145-171`）。
  - Ch2 英文"未注册操作例子"缺终结符（`test/Examples/Toy/Ch2/invalid.mlir:3-6` 明列 block terminator 错误）。
  - Ch3 DRR 用 `::llvm::cast<ShapedType>`（`Ch3/mlir/ToyCombine.td:45-49`）；三规则注册链完整（`ToyCombine.cpp:57-68`）；`-gen-rewriters`（`Ch3/CMakeLists.txt:9-10`）。
  - Ch4 三个 `isLegalToInline` 重载、`handleTerminator`、`materializeCallConversion`（`Ch4/mlir/Dialect.cpp:56/62/67/77/92`）。
  - Ch4 形状推断只判 `RankedTensorType`，Add/Mul 只传播左输入类型（`ShapeInferencePass.cpp:103-115`；`Dialect.cpp:254/369`）。
  - Ch4 `ShapeInferencePass.cpp:9-10` 残留 interprocedural/specialization 注释与实现矛盾（文档指出属实）。
  - Ch5 循环回调三参数、`modifyOpInPlace` 更新 print 输入、alloc/dealloc 移至块首/块末（`LowerToAffineLoops.cpp:77-105/255-267/57-70`）。
  - Ch5 未使用 `TypeConverter`；注册 7 种 lowering，无 GenericCall/Cast/Reshape（`LowerToAffineLoops.cpp:369-371`）。
  - Ch6 使用 `LLVMConversionTarget`、`LLVMTypeConverter`、`populateFinalizeMemRefToLLVMConversionPatterns`、`applyFullConversion`（`LowerToLLVM.cpp:200-233`）。
  - Ch6 opaque `!llvm.ptr`（`LowerToLLVM.cpp:129`）、`setupTargetTripleAndDataLayout`（`toyc.cpp:241`）、`ExecutionEngineOptions::transformer`/`create(module, options)`/`invokePacked`（`toyc.cpp:273-280`，头文件签名匹配）。
  - Ch6 换行仅在 `i != e - 1`（`LowerToLLVM.cpp:104`）；格式串 `StringRef("%f \0", 4)`/`StringRef("\n\0", 2)`（:83/:85）。
  - Ch6 AST/MLIR/LLVM IR dump 写 stderr、JIT printf 写 stdout。
  - Ch7 `getIndex()` 返回整数（`I64Attr` 生成 `uint64_t`），`getZExtValue()` 旧用法在 release/18.x 已不可编译（`Ch7/mlir/Dialect.cpp:459`；`ToyCombine.cpp:44`）。
  - Ch7 fold→materializeConstant→`ConstantOp::inferShapes` 恢复形状链完整（`ToyCombine.cpp:32-46`；`Dialect.cpp:656-665`、`265-267`）。
- 数值推导全部正确：Ch1/Ch7 的 `[[1,16],[4,25],[9,36]]`；Ch6 jit.toy 两行 `1.000000 2.000000 ` / `3.000000 4.000000 `；`memref<2x3xf64>` 的 `[1,2]`→偏移 5→40 字节、`[1,1]`→4→32 字节。
- 练习答案：Ch1–Ch7 共 28 题 + Ch0 3 题，全部正确（唯一计数瑕疵见 D1）。

---

## 6. 建议修复顺序

1. **P0**：建立并落实代码块三态标注；修正 §A1 表中 11 处未标注的不一致代码块。
2. **P0**：在 `VALIDATION.md`/`SOURCES.md` 说明"34 处摘录"只覆盖 30% 的代码块，并说明包含检查的真实强度。
3. **P1**：修正 `aiversion/05:198` 的"原文旧片段常省略第二个参数"（无依据）。
4. **P1**：补 `Ch6/llvm-lowering.mlir`；修正 README/SOURCES 对"完整包含"的措辞。
5. **P2**：修 `aiversion/04:235` 归属、`aiversion/04` 的 `-opt` 门控说明、`aiversion/03:206` reshape 计数、`aiversion/README.md:20` 措辞。
