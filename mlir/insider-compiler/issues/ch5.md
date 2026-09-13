# 第5章校订记录

校订对象：[第5章 Markdown](../insider-compiler-ch5.md)，源文件 `pdf/insider-compiler-ch5-ch6.pdf` 的 PDF 第 1–16 页（印刷页 91–106）。第6章从 PDF 第 17 页开始。本章全部 16 页均通过 `view_image` 查看原始渲染 PNG；两张图均逐节点、逐连线检查后转为 Mermaid。保留全部 17 个代码清单、5.1–5.3 节及其小节、四条页脚脚注，删除重复的运行页眉与印刷页码。

核对基准为 `/opt/llvm-project`，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。`build/bin/mlir-opt --version` 与 `build/bin/mlir-tblgen --version` 均实际输出 `LLVM version 18.1.8`，并注明 `DEBUG build with assertions`。不能把该版本简单标为 18.0。原书以 LLVM 20 为背景，本记录只把源码或运行结果足以证实的问题判为错误；没有取得 LLVM 20 对应实现的地方，不宣称差异一定由版本变化造成。

## 逐页覆盖

| PDF 页 | 印刷页 | 校订内容 |
| --- | --- | --- |
| 1 | 91 | 章标题、引言、分析机制说明、5.1 开头 |
| 2 | 92 | 管理器关系、图 5-1、5.1.1 |
| 3 | 93 | 静态调度、5.1.2、清单 5-1 |
| 4 | 94 | 方言依赖、清单 5-2 与 5-3 前半、脚注 |
| 5 | 95 | 清单 5-3 后半、清单 5-4、通用 Pass |
| 6 | 96 | 清单 5-5 至 5-7、流水线顺序、脚注 |
| 7 | 97 | 5.1.3、清单 5-8、5-9 |
| 8 | 98 | 清单 5-10、5-11、注册后的使用 |
| 9 | 99 | 5.1.4、清单 5-12 至 5-14 前半 |
| 10 | 100 | 清单 5-14 后半与 5-15、锚点注意、5.1.5 开头、脚注 |
| 11 | 101 | Pass 约束、5.1.6 前半、脚注 |
| 12 | 102 | 插桩回调、图 5-2、清单 5-16 前半 |
| 13 | 103 | 清单 5-16 后半、5.1.7、时间统计与 IR 打印 |
| 14 | 104 | 打印选项、失败捕获、清单 5-17 前半 |
| 15 | 105 | 清单 5-17 后半、重放、5.2 |
| 16 | 106 | 分析查询、保留与失效、5.3 |

## 重要勘误及依据

<a id="ch5-analysis-model"></a>

### 分析模型、缓存与失效（PDF 1、15、16）

原书引言把 LLVM 分析概括为穿插执行的 Pass，并将 MLIR 独立分析类的设计归因于多种 IR 不统一，最后称其“仅提供在多种 IR 间共享数据的能力”。这混淆了 LLVM 旧、新 Pass Manager，也没有描述 MLIR 实际具备的按需计算、缓存与失效机制。正文改为分别说明旧、新 LLVM Pass Manager，以及 MLIR 的独立分析类；不保留缺乏实现依据的能力限制。

原书称变换 Pass 要“显式生成分析对象”，应改为通过 `getAnalysis` 请求，由管理器按需构造。原书称“所有分析结果在经过一次使用后都被默认无效”，应改为 **每次 Pass 执行后依据保留集合处理失效**，并非每次查询之后。保留标记只声明有效性，不修复已过时的结果。父分析缓存接口也明确提示结果可能过时。

依据：

- [MLIR AnalysisManager.h](/opt/llvm-project/mlir/include/mlir/Pass/AnalysisManager.h:88)：自定义与默认 `isInvalidated` 分派；默认检查 `pa.isPreserved<AnalysisT>()`。
- [AnalysisManager.h](/opt/llvm-project/mlir/include/mlir/Pass/AnalysisManager.h:289)：按操作实例管理及缓存分析；`getCachedParentAnalysis` 注释提示可能过时。
- [Pass.cpp](/opt/llvm-project/mlir/lib/Pass/Pass.cpp:511)：调用 `runOnOperation()` 后，在第 525 行 `am.invalidate(pass->passState->preservedAnalyses)`。
- [本地 PassManagement.md](/opt/llvm-project/mlir/docs/PassManagement.md:215)：MLIR 分析构造、依赖、缓存与失效契约。
- [LLVM PassManager.h](/opt/llvm-project/llvm/include/llvm/IR/PassManager.h)：LLVM 新 Pass Manager 的 AnalysisManager 与 getResult/invalidate 实现。

<a id="ch5-manager"></a>

### 管理器继承方向与嵌套（PDF 2）

原书明确写“OpPassManager（实际上继承自 PassManager 类）”。实际继承方向相反：`class PassManager : public OpPassManager`。正文已改正。OpPassManager 本身不是 Pass，也不是模板；嵌套时通过 `OpToOpPassAdaptor` 作为 Pass 放入父管理器。

依据：[PassManager.h](/opt/llvm-project/mlir/include/mlir/Pass/PassManager.h:232)、[Pass.cpp](/opt/llvm-project/mlir/lib/Pass/Pass.cpp:106)。图 5-1 保留原图的层次、Pass 名称和两段图旁说明；原图最深层从 `PassN` 开始，虽与常见编号习惯不同，但不影响语义，未擅改为 `Pass1`。

<a id="ch5-scheduling"></a>

### 通用操作流水线及静态过滤（PDF 2、3）

原书称 Pass Pipeline “必须指定目标操作类型，否则管道无法执行”。实际 `nestAny()` 可创建通用操作流水线，原书后文自己也使用了该接口。原书关于“一个 Pass 不适用就跳过整个流水线”的说法，适用于通用操作流水线的静态过滤；对于已指定锚点的流水线，包含不兼容 Pass 会报错，不能笼统说只是不执行。

依据：[PassManager.h 的 nestAny](/opt/llvm-project/mlir/include/mlir/Pass/PassManager.h:105)、[Pass.cpp](/opt/llvm-project/mlir/lib/Pass/Pass.cpp:270)：指定锚点时检查所有 Pass，报 `unable to schedule pass`；第 287 行的 `canScheduleOn` 对通用锚点检查注册信息、`IsIsolatedFromAbove`，并对全部 Pass 执行 `llvm::all_of`。

<a id="ch5-tablegen"></a>

### TD 定义、依赖方言与统计（PDF 3–6）

- 原扫描清单中 `Class`、`String`、`Code`、`Using`、`const expr` 等写法既有书中印刷错误，也有 OCR 混淆；已分别改为 TableGen 的 `class`、`string`、`code` 及 C++ 的 `using`、`constexpr`。`Funcop`、`Affineloop...`、`CSB`、`11vm`、`100p` 等 OCR 错误按原图与实际标识符修复。
- `dependentDialects` 是需要提前加载的依赖，不是允许使用的方言白名单。代码注释和正文区分了注册与加载；创建相应方言实体之前必须加载方言，不能在并行 Pass 执行期间临时加载新方言。
- 声明 `Statistic` 不会自动统计 Pass 的执行次数，Pass 实现必须更新计数器。正文保留原书统计功能说明，同时纠正自动计数的暗示。
- 清单 5-2 构造器漏写 `affine::`；原扫描下一清单已经有该命名空间，实际源码也要求它，故不是本地版本特有的替换。
- 清单 5-3 是展开记录的展示，不能将失去 `PassBase` / `Pass` 继承信息的展示文本直接交给 Pass 生成器取得清单 5-4。应在原始 TD 输入上选择 `-gen-pass-decls`。正文保留完整字段，同时说明正确生成方式。
- 原书 summary 中 `out side` 改为源码实际的 `outside`；具体 C++ 实现名为 `LoopInvariantCodeMotion`，生成基类为 `AffineLoopInvariantCodeMotionBase`，已修正清单 5-2 注释。

依据：[PassBase.td](/opt/llvm-project/mlir/include/mlir/Pass/PassBase.td:63)、[Affine Passes.td](/opt/llvm-project/mlir/include/mlir/Dialect/Affine/Passes.td:180)、[AffineLoopInvariantCodeMotion.cpp](/opt/llvm-project/mlir/lib/Dialect/Affine/Transforms/AffineLoopInvariantCodeMotion.cpp)、[Pass.cpp 依赖加载](/opt/llvm-project/mlir/lib/Pass/Pass.cpp:844)、[PassManagement.md 依赖方言](/opt/llvm-project/mlir/docs/PassManagement.md:185)。实际运行 TableGen 已生成与清单 5-4、5-8、5-9 对应的基类和注册函数。

<a id="ch5-order"></a>

### 流水线合并不是任意 Pass 重排（PDF 6、9、10）

原书把连续流水线合并概括为对 Pass 排序。实际 `tryMergeInto` 先检查通用流水线与其他流水线是否存在调度冲突，冲突则不合并；合并后按锚点排序的是子 OpPassManager。具体 Pass 的次序不会因此任意重排。正文补出这一范围限制。原书“与 IR 层次一致就效率最高、只遍历一次”的断言也过强，已改为有助于缓存局部性与减少调度开销。

依据：[Pass.cpp](/opt/llvm-project/mlir/lib/Pass/Pass.cpp:624)，尤其 `hasScheduleConflictWith` 和排序子管理器的 `compareFn`。串行与并行情况下不同操作的执行关系，参见同文件 `OpToOpPassAdaptor::runOnOperation` 及其异步实现。

原书脚注“不同 Pass 顺序可能致使类型不存在”改为类型或操作未转换为后续 Pass 所需的形式，避免误导读者认为 interned 类型会因排序从上下文中消失。

<a id="ch5-registration"></a>

### 注册表归属与是否必须注册（PDF 7、8）

原书称 Pass 和 Pipeline 注册到 MLIRContext，且注册后才可使用。实际是进程全局 `ManagedStatic<StringMap<...>>`；名字注册主要服务于命令行及文本流水线。C++ 可以直接构造 Pass 并 `addPass`，无须先注册其名字。构造 PassManager 也不会自动实例化所有已注册 Pass；构建流水线和运行前初始化是不同步骤。

`PassAllocatorFunction` 是 `std::function<std::unique_ptr<Pass>()>`，不局限于函数指针。注册类的正确大小写为 `PassPipelineRegistration`；原扫描写成小写 `passPipelineRegistration`，已改正。`runOnOperation()` 的纯虚声明实际位于基类 Pass，OperationPass 继承它。

依据：[PassRegistry.cpp](/opt/llvm-project/mlir/lib/Pass/PassRegistry.cpp:26)、[PassRegistry.h](/opt/llvm-project/mlir/include/mlir/Pass/PassRegistry.h:41)、[Pass.h](/opt/llvm-project/mlir/include/mlir/Pass/Pass.h:175)。更正后的注册及工厂调用已通过 C++ 语法检查。

<a id="ch5-spirv"></a>

### SPIR-V 示例及层级不一致（PDF 9、10）

原书清单 5-12 使用 `spirv.module "Logical" "GLSL450"` 和旧式 `func @foo()`，清单 5-13 却列 `spirv.func`，清单 5-14 又以 `func::FuncOp` 为锚点。正文统一为本地可解析的 `spirv.module Logical GLSL450`、`spirv.func @foo() "None"`、`spirv.Return` 和 `spirv::FuncOp`。

值得注意的是，本地 LLVM 18 的 [PassManagement.md](/opt/llvm-project/mlir/docs/PassManagement.md:381) 中也存在旧示例，不能仅凭它来自官方文档就认为语法仍有效。这里依据实际解析器和 SPIR-V 测试文件修正，没有将所有不一致都归因于 LLVM 20 / 18 的版本差异。

清单 5-15 的 `OpPassManager<>` 应与 `OpPassManager<spirv::FuncOp>` 同级，因为两者都由 `nestedModulePM` 创建；原书缩进错误。`createCanonicalizePass()` 应为本地实际的 `createCanonicalizerPass()`。

依据：[SPIR-V control-flow-ops.mlir](/opt/llvm-project/mlir/test/Dialect/SPIRV/IR/control-flow-ops.mlir:158)、[Transforms/Passes.h](/opt/llvm-project/mlir/include/mlir/Transforms/Passes.h)、实际 `mlir-opt` 解析并执行，以及包含所需头文件的 C++ 语法检查。原书自定义 MyModulePass 等没有给实现，本文保留其示意角色，没有宣称完整编译运行这些缺省类。

<a id="ch5-anchor"></a>

### 顶层 module 和报错原因（PDF 10）

原书称输入以 `func.func` 为顶层就会直接报错。实际 `mlir-opt` 默认添加隐式 module，真正需要对齐的是实际顶层操作与 PassManager 的锚点。正文保留原有诊断及完整流水线用法，但修正触发条件。

依据：[MlirOptMain.h](/opt/llvm-project/mlir/include/mlir/Tools/mlir-opt/MlirOptMain.h:147) 中 `useExplicitModule` 的说明与默认值、[MlirOptMain.cpp](/opt/llvm-project/mlir/lib/Tools/mlir-opt/MlirOptMain.cpp:115) 中 `no-implicit-module` 选项。本章清单 5-17 以两个顶层 `func.func` 开始，实际运行成功并输出一个 `module` 包装。

<a id="ch5-constraints"></a>

### Pass 约束含义（PDF 10、11）

原书“一个 Pass 的运行不应依赖于所处理的操作”容易被理解为 Pass 不能依据当前 IR 做决定；实际限制是不能依赖同一 Pass 实例跨调用维护的可变状态，也不能假设该实例会访问所有操作。正文据此修正。

原书将 `IsolatedFromAbove` 解释为不能“跨 Pass 优化”，不成立。它限制的是 SSA 外部捕获以及相关使用链跨作用域访问，配合 Pass 的修改范围保障并发安全；选取更上层锚点仍可实现跨子操作优化。重写框架的辅助 API 也不豁免 Pass 约束。

依据：[PassManagement.md](/opt/llvm-project/mlir/docs/PassManagement.md:25) 的 Operation Pass 约束、[同文件](/opt/llvm-project/mlir/docs/PassManagement.md:358) 的锚点隔离要求。

<a id="ch5-instrumentation"></a>

### 插桩顺序、分析回调及计数器（PDF 12、13）

原书声称最后注册的插桩，其 before 和 after 回调都会先执行。实际 before 按注册顺序，after 按逆序。`addInstrumentation` 用 `emplace_back`，before 正向遍历，after 使用 `llvm::reverse`，各处均持有 instrumentor mutex。

分析依赖会在外层分析的 before / after 之间触发自己的回调；不应在 instrumentation hook 中手动调用依赖回调来运行分析。正文将原文容易误解的表述改为回调对嵌套。

清单 5-16 中 `unsigned domInfoCount;` 必须初始化；已改为 `unsigned domInfoCount = 0;`，并在打印字符串中补空格。原书省略了实际 Pass 添加过程，正文明确没有 Pass 时统计仍为零。

依据：[Pass.cpp](/opt/llvm-project/mlir/lib/Pass/Pass.cpp:1002) 至 `addInstrumentation` 实现、[AnalysisManager.h](/opt/llvm-project/mlir/include/mlir/Pass/AnalysisManager.h:140) 的按需构造及插桩、[PassManagement.md](/opt/llvm-project/mlir/docs/PassManagement.md:1039)。完整化的计数器类及注册调用通过 `clang++ -fsyntax-only`；未运行自定义插桩统计程序，回调次序由实现直接核实。

<a id="ch5-reproducer"></a>

### 失败重放示例及版本边界（PDF 14、15）

清单 5-17 的资源分隔符应为 `{-#` 和 `#-}`，Pass 选项括在 `{...}` 中；OCR 将花括号、连字符、`i32`、`@bar` 等误读，已按图像和本地测试修复。原书示例与本地 [run-reproducer.mlir](/opt/llvm-project/mlir/test/Pass/run-reproducer.mlir:1) 相近，两个简单函数本身不足以展示失败，本地运行成功。因此正文将“可以重现问题”准确说明为“重新执行记录的流水线”，不伪造失败结果。

失败捕获参数需要指定输出文件名；局部 reproducer 是在 crash reproducer 基础上额外启用的模式，要求禁用多线程。机制依据：[PassCrashRecovery.cpp](/opt/llvm-project/mlir/lib/Pass/PassCrashRecovery.cpp:355)。

本地 `region-simplify` 是布尔选项，见 [Transforms/Passes.td](/opt/llvm-project/mlir/include/mlir/Transforms/Passes.td:35)。本次尝试访问 LLVM 20.1.0 的该文件未取得内容，不据此断言 LLVM 20 取值或行为。跨版本重放需再以目标工具确认。

## 实际验证

以下命令均实际执行成功。

1. `mlir-opt --version` 和 `mlir-tblgen --version`：18.1.8。
2. `mlir-tblgen /opt/llvm-project/mlir/include/mlir/Dialect/Affine/Passes.td -I /opt/llvm-project/mlir/include -I /opt/llvm-project/llvm/include -gen-pass-decls -name Affine`：生成 AffineLoopInvariantCodeMotionBase、registerAffineLoopInvariantCodeMotion、registerAffinePasses，与所转写的代码片段核对。
3. 对清单 5-12 的完整 SPIR-V 输入执行 `mlir-opt input.mlir '-pass-pipeline=builtin.module(spirv.module(spirv.func(cse),any(canonicalize,cse)))'`：解析、验证与嵌套流水线均成功，输出保留原结构。
4. 对清单 5-17 的重放文件执行 `mlir-opt input.mlir --run-reproducer -dump-pass-pipeline`：成功，实际流水线包含 `cse,canonicalize{max-iterations=1 max-num-rewrites=-1 region-simplify=false test-convergence=false top-down=false}`；未使用的 `%0` 常量被删除，两个函数保留。
5. 使用 `clang++ -std=c++17 -fsyntax-only`，包含本地源码及 build 生成头文件目录，检查完整的 DominanceCounterInstrumentation 类、计数器注册、`PassManager::on<ModuleOp>`、SPIR-V 两层 `nest`、`nestAny`、`createCanonicalizerPass`、`PassPipelineRegistration` 和 affine LICM 注册工厂调用：退出码 0。

已永久保留 [SPIR-V 输入](evidence/ch5-spirv.mlir)及[实际输出](evidence/ch5-spirv-out.mlir)、[重放输入](evidence/ch5-reproducer.mlir)及[实际输出](evidence/ch5-reproducer-out.mlir)、[C++ API 检查文件](evidence/ch5-api.cpp)。从仓库根目录可复现：

```sh
/opt/llvm-project/build/bin/mlir-opt \
  mlir/insider-compiler/issues/evidence/ch5-spirv.mlir \
  '-pass-pipeline=builtin.module(spirv.module(spirv.func(cse),any(canonicalize,cse)))' \
  -o /private/tmp/ch5-spirv-out.mlir
/opt/llvm-project/build/bin/mlir-opt \
  mlir/insider-compiler/issues/evidence/ch5-reproducer.mlir \
  --run-reproducer -dump-pass-pipeline -o /private/tmp/ch5-reproducer-out.mlir
clang++ -std=c++17 -fsyntax-only \
  mlir/insider-compiler/issues/evidence/ch5-api.cpp \
  -I /opt/llvm-project/mlir/include \
  -I /opt/llvm-project/build/tools/mlir/include \
  -I /opt/llvm-project/llvm/include -I /opt/llvm-project/build/include
```

未构建或执行原书未给完整实现的自定义 MyPass / MyOtherPass / MyModulePass 等类，未声称 17 个代码片段都是独立可运行程序。

## 剩余边界

没有因扫描模糊而遗留无法辨读的正文、代码或图。原始 Apple Vision OCR 未被改写。LLVM 20 的全量对应实现未逐项取得；本文主要依据本地 LLVM 18.1.8，不把未经验证的版本差异当作已证实的原书错误。
