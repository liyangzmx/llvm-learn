# glmcheck：aiversion 各章文档质量检查报告

- 检查对象：`aiversion/README.md`、`00-preflight.md` ～ `07-custom-types.md`（共 9 个文件，约 2980 行）。
- 对照基准：本地 `/opt/llvm-project`，`release/18.x` @ `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`（已用 `git rev-parse` 核实，与文档声明一致）。
- 检查方式：静态审读 + 与源码逐项核对。未构建、未运行（与文档自述"当前只完成文档及源码一致性检查"一致）。
- 结论先行：**整体质量非常高**。下文先列发现的问题（很少），再附核对通过项清单，供复查时参考。

---

## 一、发现的问题

### 问题 1（低严重度，事实性偏差）：`03-rewriting.md` §8.1 "本地 benefit=1" 以偏概全

**位置**：`aiversion/03-rewriting.md` 第 210 行。

**原文**：

> 本地 benefit=1 是模式排序的相对值，不是删除一条指令便计 1。

**问题**：这句话容易被理解为"本章所有本地模式的 benefit 都是 1"，但事实并非如此：

- C++ 模式 `SimplifyRedundantTranspose` 确实显式写了 `benefit=1`（`Ch3/mlir/ToyCombine.cpp:36` 的 `OpRewritePattern<TransposeOp>(context, /*benefit=*/1)`）；
- 但 DRR 生成的三个模式，benefit 由 `Pattern::getBenefit()` 计算：**benefit = 源模式中操作个数 + addBenefit 增量**（见 `mlir/lib/TableGen/Pattern.cpp:699-708`，`initBenefit = getSourcePattern().getNumOps()`）。因此：
  - `RedundantReshapeOptPattern`（源模式 1 个操作）→ benefit = 1；
  - `ReshapeReshapeOptPattern`（源模式 2 个操作）→ benefit = 2；
  - `FoldConstantReshapeOptPattern`（源模式 2 个操作）→ benefit = 2。

**影响**：读者若据"本地 benefit=1"去推断规则排序行为（例如以为 ReshapeReshape 与 RedundantReshape 同优先级），会得出与生成代码不符的结论；文档也没有介绍 DRR "源模式操作数即收益"这一实际生效的机制。

**建议改法**：说明"C++ 模式显式传入 benefit=1；DRR 模式未显式指定时，其 benefit 默认等于源模式中的操作数（因此三个 reshape 规则的 benefit 是 1 或 2），都只是排序用的相对指标"。

### 问题 2（提示级，信息完整性）：`00-preflight.md` §4 的 Ch6 目录树省略了部分实际存在的文件

**位置**：`aiversion/00-preflight.md` 第 68-83 行。

**问题**：目录树以"以第 6 章为例"给出，但 `Ch6/include/toy/` 下实际还有 `MLIRGen.h`、`ShapeInferenceInterface.h`、`ShapeInferenceInterface.td` 三个文件未列出。该树本身是"目录地图"性质的教学简化，不算错误，但既然指向具体某一章，补全或注明"仅列关键文件"会更严谨（尤其 `ShapeInferenceInterface.td` 与第 4 章内容有直接关联，读者按图索骥时可能找不到）。

---

## 二、未发现问题的部分（核对通过项摘录）

以下核对项全部与本地源码/测试一致，列出以便复查时抽样：

### 版本与环境声明（README、00 章）

- `/opt/llvm-project` 分支 `release/18.x`、提交 `3b5b5c1...`：✓ 与 `git rev-parse` 输出一致。
- 已有 `/opt/llvm-project/build/CMakeCache.txt` 为 `clang;clang-tools-extra`、`LLVM_BUILD_EXAMPLES=OFF`：✓ 属实。
- `mlir/CMakeLists.txt:100` 附近按 Native 目标是否在构建列表设置 `MLIR_ENABLE_EXECUTION_ENGINE`；Ch6/Ch7 CMake 在引擎不可用时 `return()`：✓ 属实。
- `examples/toy/CMakeLists.txt` 的 `Toy` 聚合目标：✓ 属实。

### 逐字源码摘录与行号锚点（约 25 处，全部命中且内容逐字一致）

- 02 章：`Ch2/mlir/Dialect.cpp` 的 `ConstantOp::verify`/`build`/`parse`/`print`（锚点 110/124/137/145 均落在摘录内）、`Ch2/include/toy/Ops.td:33`（`Toy_Op` 基类）、`:74`（builders）。
- 04 章：`Ch4/mlir/Dialect.cpp:48`（`ToyInlinerInterface`）、`:330`（`GenericCallOp::getCallableForCallee` 等）、`Ch4/mlir/ShapeInferencePass.cpp:103/111`（`allOperandsInferred`/`returnsDynamicShape`）、`FunctionInterfaces.td:24`（`FunctionOpInterface` 依赖 `CallableOpInterface`）。
- 05 章：`Ch5/mlir/LowerToAffineLoops.cpp:57/80/293`（`insertAllocAndDealloc`/`lowerOpToLoops`/`TransposeOpLowering`）。
- 06 章：`Ch6/mlir/LowerToLLVM.cpp:127/196`（`getPrintfType`/`runOnOperation`）、`Ch6/toyc.cpp:212/256`（`dumpLLVMIR`/`runJit`）。
- 07 章：`Ch7/mlir/Dialect.cpp:509/582/623/446/457/656`（`StructTypeStorage`/`parseType`/`printType`/`StructAccessOp::build`/`verify`/`materializeConstant`）。
- 所有"逐字源码"块与源文件逐字符一致（含注释与空行）。

### 行为性描述（抽查约 30 项，全部属实）

- 02 章：`TransposeOp::build` 总给无秩结果；模块循环不检查 `mlirGen(f)` 返回值；print 语句失败分支 `return success()`；显式 shape 声明无条件插入 `ReshapeOp`；`ReturnOp` verifier 在"类型相同或任一侧无秩"时放行；`ScopedHashTable<StringRef, Value>`；`collectData()`；空 shape 的 `getType` 返回无秩类型；PrintOp 用声明式 `assemblyFormat`（与原文"先手写后收敛"的历史一致）。
- 03 章：`-gen-rewriters` 生成 `ToyCombine.inc` 且在匿名命名空间 include；`ReshapeOp::getCanonicalizationPatterns` 注册三个 DRR 模式；toyc 只在 `-opt` 下加嵌套 Canonicalizer；`Pure`/`hasCanonicalizer` 标注。
- 04 章：shape inference worklist 的"先移出集合再调用接口"次序、`SmallPtrSet` 无序、"就绪但缺接口"与"残项"两条不同错误信息；`CastOp::areCastCompatible`（两边有秩则要求类型全等）；Add/Mul 的 `inferShapes` 只取左输入；非 main 函数 `setPrivate()`；文件头残留的"interprocedural/specialization"注释（实现实为函数内处理）——文档对这处"注释与实现不符"的指出准确。
- 05 章：七个 lowering 及各自基类（Constant/Return 用 `OpRewritePattern`，Add/Mul/Transpose 用 `ConversionPattern`，Func/Print 用 `OpConversionPattern`）；`FuncOpLowering` 只接受无参无结果的 main；`PrintOpLowering` 用 `modifyOpInPlace` 更新操作数；本章确实没有 TypeConverter，只有局部 `convertTensorToMemRef` 辅助函数；alloc 移到块首、dealloc 移到 terminator 前。
- 06 章：`"%f \0"`(4) 与 `"\n\0"`(2) 字符串常量；`lookupSymbol` + `InsertionGuard`；`i != e - 1` 才打印换行（一维/零秩不额外换行）；最内层用原 `printOp.getInput()` 而非 adaptor；pass 流水线表（前处理 / Affine+清理 / `-opt` 追加 LoopFusion+AffineScalarReplacement / LowerToLLVM+DIScope）；`enableOpt || isLoweringToAffine` 才跑前处理；JITTargetMachineBuilder 与 `setupTargetTripleAndDataLayout` 的现行 API。
- 07 章：`StructType::get` 断言非空；结构式唯一化（名字不入键）；`getIndex()` 而非旧式 `getZExtValue()`；structMap/局部符号表的确切类型 `(Value, VarDeclExprAST*)`；functionMap 按生成顺序建立、前向引用/递归不可用；ConstantOp 补接 `ShapeInferenceOpInterface` 恢复形状。

### 测试文件与数值（全部属实）

- `llvm-lowering.mlir`：RUN 行确实只有 `toyc-ch6 %s -emit=llvm -opt`、无 FileCheck 管道；最后一个 CHECK 确实写成 `3.000000e+01`（30），而输入末元素 6 自乘应为 36（`3.600000e+01`）——文档对这处上游过期 CHECK 的识别与分析**完全正确**，是全篇最有价值的核对点之一。
- `jit.toy`（`print([[1,2],[3,4]])`）与"两行 1.000000 2.000000 / 3.000000 4.000000、元素后有空格"的预期一致。
- `transpose_transpose.toy`、`trivial_reshape.toy`、`shape_inference.mlir`（`CHECK-NOT: toy.func private`、`CHECK-NOT: tensor<*xf64>`、mul 两输入同一转置）、`affine-lowering.mlir`（朴素 3 个 alloc 两个循环巢 vs `-opt` 融合）、`struct-opt.mlir`（嵌套 struct 两层 access 后只剩常量与 print）、`struct-codegen.toy`（结果 `[[1,16],[4,25],[9,36]]`）：✓ 全部与文档描述一致。
- 官方 `Ch-1.md` 的 "rank <= 2" 限定、`Ch-6.md` 的历史 `!llvm<"i8*">` 片段：✓ 存在，文档的对比表述准确。

### 数学与示例

- reshape vs transpose 的 2×3/3×2 矩阵手工推导、`transpose(A)*transpose(A)=[[1,16],[4,25],[9,36]]`、memref 地址公式（offset=0、strides=[3,1] 时 [1,2] 偏移 5 即 40 字节；[1,1] 偏移 4 即 32 字节）、非方阵 transpose lowering 的 [j,i] 读取方向（含"方阵上只表现为忘转置、非方阵越界"的提醒）：✓ 全部正确。

### 标注体系

"逐字源码 / 译编 / 示意"三类标注使用严格：抽查所有标"逐字源码"的块均逐字一致；"示意"块（如 02 章带 `$output` 的简化 ODS、06 章 CFG 示例）均在正文注明与实际实现的差异，未发现把示意内容冒充实测输出的情况。

---

## 三、总体评价

- **准确性**：在抽验的 60+ 个可证伪声明中，仅发现 1 处事实性偏差（问题 1）与 1 处信息不完整（问题 2）。尤其难得的是若干"逆向纠错"点（上游测试过期 CHECK=30≠36、文件头注释与实现不符、原文历史 API 与本地代码的差异、Ch2 错误传播缺口）全部经源码核实成立。
- **诚实度**：对"未执行构建/运行"、"示意不等于实测"、"原文设想 vs 本地实现"的边界声明一致且可信。
- **教学结构**：三个运行时刻、值/存储语义、fold 与 lowering、LLVM 方言与 LLVM IR 等贯穿性区分一致贯彻；练习答案与正文呼应。
- 主要改进空间即上述两处；另可考虑（非问题）：若未来构建了 `TOY_BUILD`，可将"待构建后执行"的实验命令实际跑一遍并把"预期"升级为"实测"，进一步消除示意与现实的残余差距。
