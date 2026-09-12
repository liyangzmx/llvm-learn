# 第 6 章：降级到 LLVM 并生成代码

本地原文：[Ch-6.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-6.md) · [本章源码](/opt/llvm-project/mlir/examples/toy/Ch6/toyc.cpp)

基准：`release/18.x` / `3b5b5c1ec4a3`。本章原文中的若干 API 和 LLVM 文本已滞后于同仓库实现，下列实现摘录直接取自本地代码。

## 1. 降级到 LLVM

上一章把计算部分变为 Affine、Arith、MemRef 和 Func，保留消费 MemRef 的 `toy.print`。本章使用 Dialect Conversion 完成最后转换。打印被展开为 SCF 循环，循环最内层 load 一个 f64 元素，再调用 `printf`；已有转换规则继续把中间操作降至 LLVM 方言。这种 A→B→C 的传递式降级，允许每条规则只处理一个合理的抽象跨度。

### 1.1 外部函数声明与全局字符串

`PrintOpLowering` 继承 `ConversionPattern`。它根据原操作的 `MemRefType` 获取形状，在父 Module 中查找或插入 `printf` 声明。当前 LLVM 指针使用 `!llvm.ptr`，不采用原文历史片段中的 `!llvm<"i8*">`。

> 代码性质：逐字源码（按所引路径与起始行核对；不等于独立可编译）。

[源码：Ch6/mlir/LowerToLLVM.cpp](/opt/llvm-project/mlir/examples/toy/Ch6/mlir/LowerToLLVM.cpp:127)

```c++
  static LLVM::LLVMFunctionType getPrintfType(MLIRContext *context) {
    auto llvmI32Ty = IntegerType::get(context, 32);
    auto llvmPtrTy = LLVM::LLVMPointerType::get(context);
    auto llvmFnType = LLVM::LLVMFunctionType::get(llvmI32Ty, llvmPtrTy,
                                                  /*isVarArg=*/true);
    return llvmFnType;
  }
```

`getOrInsertPrintf` 用 `lookupSymbol<LLVM::LLVMFuncOp>` 避免重复声明；`PatternRewriter::InsertionGuard` 保存插入点，再把新声明插到模块开头。

两个字符串分别为 `StringRef("%f \0", 4)` 和 `StringRef("\n\0", 2)`：长度包含结尾 NUL。`getOrCreateGlobalString` 创建 internal linkage 的常量 `LLVM::GlobalOp`，然后生成 AddressOf 和索引 `[0, 0]` 的 GEP，取得第一个字符的地址。

### 1.2 SCF 循环与换行位置

对形状的每个维度生成 `arith::ConstantIndexOp` 表示 0、维度大小、1，并构造 `scf::ForOp`。为精确控制循环体，源码删除自动产生的 terminator，重新插入 `scf::YieldOp`，再把插入点移回循环体起始处，继续创建更内层循环。

二维张量的外层循环尾部打印换行，内层循环逐元素打印。零秩 MemRef 没有循环，直接用空索引 load 一个元素。源码最内层使用原 `printOp.getInput()` 创建 MemRef load；它是一个先引入 MemRef/SCF、再依靠后续模式合法化的转换，不要把“adaptor 总是应当直接传给新操作”当作不考虑类型阶段的规则。

## 2. Conversion Target、类型转换与规则集合

### 2.1 Conversion Target

本地用 `LLVMConversionTarget` 并显式允许顶层 `ModuleOp`。这比手写只有一行 `addLegalDialect` 更贴近实际实现。转换结束时，所有剩余操作必须被目标判为合法。

### 2.2 Type Converter

`LLVMTypeConverter` 负责将 MemRef 等类型转换为 LLVM 可表示的结构。对于有秩 MemRef，通常需要已分配指针、对齐指针、offset、各维 size 和 stride，而不是只保留一个裸数据指针。类型转换同时影响块参数、函数签名和操作边界。

### 2.3 Conversion Patterns 与完全转换

下面是本地 pass 的完整 `runOnOperation()`。注意 **MemRef 转换规则不可缺少**，而且这里的函数参数和命名空间与旧教程示例有所不同。

> 代码性质：逐字源码（按所引路径与起始行核对；不等于独立可编译）。

[源码：Ch6/mlir/LowerToLLVM.cpp](/opt/llvm-project/mlir/examples/toy/Ch6/mlir/LowerToLLVM.cpp:196)

```c++
void ToyToLLVMLoweringPass::runOnOperation() {
  // The first thing to define is the conversion target. This will define the
  // final target for this lowering. For this lowering, we are only targeting
  // the LLVM dialect.
  LLVMConversionTarget target(getContext());
  target.addLegalOp<ModuleOp>();

  // During this lowering, we will also be lowering the MemRef types, that are
  // currently being operated on, to a representation in LLVM. To perform this
  // conversion we use a TypeConverter as part of the lowering. This converter
  // details how one type maps to another. This is necessary now that we will be
  // doing more complicated lowerings, involving loop region arguments.
  LLVMTypeConverter typeConverter(&getContext());

  // Now that the conversion target has been defined, we need to provide the
  // patterns used for lowering. At this point of the compilation process, we
  // have a combination of `toy`, `affine`, and `std` operations. Luckily, there
  // are already exists a set of patterns to transform `affine` and `std`
  // dialects. These patterns lowering in multiple stages, relying on transitive
  // lowerings. Transitive lowering, or A->B->C lowering, is when multiple
  // patterns must be applied to fully transform an illegal operation into a
  // set of legal ones.
  RewritePatternSet patterns(&getContext());
  populateAffineToStdConversionPatterns(patterns);
  populateSCFToControlFlowConversionPatterns(patterns);
  mlir::arith::populateArithToLLVMConversionPatterns(typeConverter, patterns);
  populateFinalizeMemRefToLLVMConversionPatterns(typeConverter, patterns);
  cf::populateControlFlowToLLVMConversionPatterns(typeConverter, patterns);
  populateFuncToLLVMConversionPatterns(typeConverter, patterns);

  // The only remaining operation to lower from the `toy` dialect, is the
  // PrintOp.
  patterns.add<PrintOpLowering>(&getContext());

  // We want to completely lower to LLVM, so we use a `FullConversion`. This
  // ensures that only legal operations will remain after the conversion.
  auto module = getOperation();
  if (failed(applyFullConversion(module, target, std::move(patterns))))
    signalPassFailure();
}
```

`populateAffineToStdConversionPatterns` 的名字保留了历史用词，不代表本地 IR 中仍存在一个 `std` 方言。SCF 先变为 CF；Arith、MemRef、CF、Func 再分别转换为 LLVM。自定义 Print 模式和标准模式共同构成合法化闭环。

`applyFullConversion` 要求所有操作都合法化；无法转换的未知操作也不能像 partial conversion 那样被默认保留。失败通过 `signalPassFailure()` 传播给 PassManager，驱动不会继续导出这个半成品。

## 3. 代码生成：离开 MLIR

### 3.1 导出 LLVM IR

LLVM 方言仍采用 MLIR 的 `Operation`、`Region`、`Block` 和类型系统。导出为 `llvm::Module` 是下一道明确边界。实现先注册 Builtin 和 LLVM 的翻译接口，再创建独立 `llvm::LLVMContext`，调用 `translateModuleToLLVMIR(module, llvmContext)`。

本地还用 `JITTargetMachineBuilder::detectHost()` 和 `createTargetMachine()` 得到宿主 TargetMachine，再调用 `ExecutionEngine::setupTargetTripleAndDataLayout`。不能照抄上版教材中的 `setupTargetTriple`。

> 代码性质：逐字源码（按所引路径与起始行核对；不等于独立可编译）。

[源码：Ch6/toyc.cpp](/opt/llvm-project/mlir/examples/toy/Ch6/toyc.cpp:212)

```c++
int dumpLLVMIR(mlir::ModuleOp module) {
  // Register the translation to LLVM IR with the MLIR context.
  mlir::registerBuiltinDialectTranslation(*module->getContext());
  mlir::registerLLVMDialectTranslation(*module->getContext());

  // Convert the module to LLVM IR in a new LLVM IR context.
  llvm::LLVMContext llvmContext;
  auto llvmModule = mlir::translateModuleToLLVMIR(module, llvmContext);
  if (!llvmModule) {
    llvm::errs() << "Failed to emit LLVM IR\n";
    return -1;
  }

  // Initialize LLVM targets.
  llvm::InitializeNativeTarget();
  llvm::InitializeNativeTargetAsmPrinter();

  // Configure the LLVM Module
  auto tmBuilderOrError = llvm::orc::JITTargetMachineBuilder::detectHost();
  if (!tmBuilderOrError) {
    llvm::errs() << "Could not create JITTargetMachineBuilder\n";
    return -1;
  }

  auto tmOrError = tmBuilderOrError->createTargetMachine();
  if (!tmOrError) {
    llvm::errs() << "Could not create TargetMachine\n";
    return -1;
  }
  mlir::ExecutionEngine::setupTargetTripleAndDataLayout(llvmModule.get(),
                                                        tmOrError.get().get());

  /// Optionally run an optimization pipeline over the llvm module.
  auto optPipeline = mlir::makeOptimizingTransformer(
      /*optLevel=*/enableOpt ? 3 : 0, /*sizeLevel=*/0,
      /*targetMachine=*/nullptr);
  if (auto err = optPipeline(llvmModule.get())) {
    llvm::errs() << "Failed to optimize LLVM IR " << err << "\n";
    return -1;
  }
  llvm::errs() << *llvmModule << "\n";
  return 0;
}
```

`enableOpt` 决定 LLVM 优化等级是 3 还是 0。优化器可能把常量张量的循环与中间分配进一步消去，留下几次带常量参数的打印调用。这个结果依赖输入、目标和 pass，不应把某次生成的 `%123` 名字或基本块编号当成固定接口。

### 3.2 设置 JIT

本地通过 `ExecutionEngineOptions::transformer` 传入优化函数，调用 `ExecutionEngine::create(module, engineOptions)`，最后 `invokePacked("main")`。这些都是源码中的实际调用形式：

> 代码性质：逐字源码（按所引路径与起始行核对；不等于独立可编译）。

[源码：Ch6/toyc.cpp](/opt/llvm-project/mlir/examples/toy/Ch6/toyc.cpp:256)

```c++
int runJit(mlir::ModuleOp module) {
  // Initialize LLVM targets.
  llvm::InitializeNativeTarget();
  llvm::InitializeNativeTargetAsmPrinter();

  // Register the translation from MLIR to LLVM IR, which must happen before we
  // can JIT-compile.
  mlir::registerBuiltinDialectTranslation(*module->getContext());
  mlir::registerLLVMDialectTranslation(*module->getContext());

  // An optimization pipeline to use within the execution engine.
  auto optPipeline = mlir::makeOptimizingTransformer(
      /*optLevel=*/enableOpt ? 3 : 0, /*sizeLevel=*/0,
      /*targetMachine=*/nullptr);

  // Create an MLIR execution engine. The execution engine eagerly JIT-compiles
  // the module.
  mlir::ExecutionEngineOptions engineOptions;
  engineOptions.transformer = optPipeline;
  auto maybeEngine = mlir::ExecutionEngine::create(module, engineOptions);
  assert(maybeEngine && "failed to construct an execution engine");
  auto &engine = maybeEngine.get();

  // Invoke the JIT-compiled function.
  auto invocationResult = engine->invokePacked("main");
  if (invocationResult) {
    llvm::errs() << "JIT invocation failed\n";
    return -1;
  }

  return 0;
}
```

`invokePacked` 对应 ExecutionEngine 的打包调用入口；本例 `main` 无参数、无返回值，所以没有额外参数数组。源码对引擎创建成功使用 assert；这展示了教程的简化错误处理，面向用户的工具通常还需要消费并报告 `llvm::Error`。

## 4. 驱动程序实际如何决定流水线

`loadAndProcessMLIR` 比较 `emitAction` 的枚举值来决定是否进入 Affine 和 LLVM 阶段。即使没有 `-opt`，只要请求 `mlir-affine` 或更低层输出，内联和形状推断就必须运行，否则没有足够信息生成静态循环。

| 阶段 | Module 上的 pass | 嵌套 pass |
|---|---|---|
| Toy 前处理 | Inliner | `toy.func`：ShapeInference → Canonicalizer → CSE |
| Affine 降级 | LowerToAffine | `func.func`：Canonicalizer → CSE |
| `-opt` 附加优化 | — | `func.func`：LoopFusion → AffineScalarReplacement |
| LLVM 降级 | LowerToLLVM → DIScopeForLLVMFuncOp | — |

最后的 debug scope pass 为基本调试行表提供作用域信息，不是完整的源语言变量调试信息实现。

## 5. 运行与观察

先按 [环境准备](/opt/coding/mlir-toy/aiversion/00-preflight.md) 构建并设置 `TOY_BUILD`。本地现有 `/opt/llvm-project/build` 未启用 MLIR，不能直接假定其中已有这些二进制。

```bash
${TOY_BUILD}/bin/toyc-ch6 /opt/llvm-project/mlir/test/Examples/Toy/Ch6/jit.toy -emit=jit
${TOY_BUILD}/bin/toyc-ch6 /opt/llvm-project/mlir/test/Examples/Toy/Ch6/codegen.toy -emit=mlir
${TOY_BUILD}/bin/toyc-ch6 /opt/llvm-project/mlir/test/Examples/Toy/Ch6/codegen.toy -emit=mlir-affine
${TOY_BUILD}/bin/toyc-ch6 /opt/llvm-project/mlir/test/Examples/Toy/Ch6/codegen.toy -emit=mlir-llvm
${TOY_BUILD}/bin/toyc-ch6 /opt/llvm-project/mlir/test/Examples/Toy/Ch6/codegen.toy -emit=llvm
```

第一个命令的数学结果为两行 `1 2`、`3 4`；源码格式字符串使每个数显示为六位小数，元素后有空格。AST、MLIR 和 LLVM IR 的 dump 写到 **stderr**，应使用 `2> output.mlir` 或 `2> output.ll` 捕获；JIT 的 `printf` 输出写到 stdout。

### 5.1 原文使用的 llvm-lowering.mlir 输入

本地英文原文还引用了 [llvm-lowering.mlir](/opt/llvm-project/mlir/test/Examples/Toy/Ch6/llvm-lowering.mlir)。它从 **Toy 方言 IR** 开始，不是预先降好的混合 IR；可以对同一输入选择不同停止阶段：

```bash
"${TOY_BUILD}/bin/toyc-ch6" /opt/llvm-project/mlir/test/Examples/Toy/Ch6/llvm-lowering.mlir -emit=mlir-affine
"${TOY_BUILD}/bin/toyc-ch6" /opt/llvm-project/mlir/test/Examples/Toy/Ch6/llvm-lowering.mlir -emit=mlir-llvm
"${TOY_BUILD}/bin/toyc-ch6" /opt/llvm-project/mlir/test/Examples/Toy/Ch6/llvm-lowering.mlir -emit=llvm -opt
```

注意本地该文件的 RUN 只有 `toyc-ch6 %s -emit=llvm -opt`，**没有管道连接 FileCheck**。它虽保留若干 CHECK 注释，最后一个浮点数却写成 `3.000000e+01`（30）；输入最后一个元素为 6，逐元素自乘应为 36，即 `3.600000e+01`。因此不能把这些未接入 RUN 的历史 CHECK 当作已验证的数值金标准，也不要直接添加 FileCheck 管道并期待成功。上述命令用于观察各层 IR；本文未执行这些命令，未修改上游测试。

需要追踪 pass 时加入 `-mlir-disable-threading -mlir-print-ir-after-all`。示例输出来自本地测试约定与源码推导；本文没有把未构建运行的结果声称为实测。

下一章在高层加入结构体，并通过折叠把它重新接入这套后端。
