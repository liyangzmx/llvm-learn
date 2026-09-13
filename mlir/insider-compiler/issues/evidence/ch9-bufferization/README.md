# 第 9 章缓冲化的独立源码与运行复核

范围：合订 PDF 第 70–75 页（9.4 及 9.5 开头）。基准：本地 LLVM 18.1.8，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`，见 [版本记录](../../source-files.md)。本记录供正文校订使用，未运行本书全部工作负载。

## 源码事实

1. 缓冲化把 tensor 值语义表示转换为 memref 缓冲区表示，并分析何时可复用存储，不是 CPU 缓存优化。DPS 的 destination 是与结果对应的操作数；不能简单等同于“所有函数的输出都由调用者预先分配”。见 [Bufferization.md](/opt/llvm-project/mlir/docs/Bufferization.md:8)。
2. RaW 是 **写后读**，不是“读后写”。原地写入若改变后续对旧 tensor 值的读取，就会破坏值语义。无 RaW 冲突也不保证可原地写：还须可写等条件。见 [接口的可写性说明](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/IR/BufferizableOpInterface.td:369)。不能由 tensor SSA 推论所有底层缓冲区都没有其他依赖。
3. `bufferization.clone` 的合法实现可以返回别名，也可以实际复制；克隆后再修改源或结果被该操作契约规定为未定义行为。因此“clone 仅创建别名”错误。见 [BufferizationOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/IR/BufferizationOps.td:190)。
4. `bufferization.dealloc` 根据条件和 retained memrefs 的别名关系决定释放及所有权转移。Ownership-based Buffer Deallocation 插入的是这个操作，不能写成 `dealloc_tensor`。One-Shot 本身不承担释放。见 [实际所有权实现](/opt/llvm-project/mlir/lib/Dialect/Bufferization/Transforms/OwnershipBasedBufferDeallocation.cpp)、[释放说明](/opt/llvm-project/mlir/docs/Bufferization.md:295)。`dealloc_tensor` 的 TableGen 介绍仍残留 One-Shot 自动插入释放的旧说法，不能据此否定实际实现。
5. 本地 `BufferizableOpInterface` 的 API 是 `getAliasingValues` 和 `getAliasingOpOperands`，没有原书列出的 `getAliasingOpResult`，也没有独立 `bufferRelation` hook。别名项中携带 `relation` 与 `isDefinite`；`Equivalent` 表示同一缓冲区且大小、偏移、步长对应，`Unknown` 表示除别名之外没有更强关系信息，绝非“不别名”。允许保守地多报别名，不允许漏报可能别名。见 [接口 TD](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/IR/BufferizableOpInterface.td:229)。**本地文档 Bufferization.md 955–971 也保留旧 API 名称，正文以 TD 定义为准。**
6. 本地枚举只支持 `BottomUp`、`TopDown`，默认 bottom-up；随机顺序通过测试选项 `analysis-fuzzer-seed` 提供。书中 `bottom-up-from-terminators` 不是这个检出的可用配置。见 [OneShotAnalysis.h](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/Transforms/OneShotAnalysis.h:27)、[Passes.td](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/Transforms/Passes.td:453)。未据此判断全部 LLVM 20 版本。
7. 默认函数所有权约定：输入借用、调用者保有所有权；返回 memref 向调用者转移所有权；返回缓冲区的底层分配不能别名于输入。`private-function-dynamic-ownership` 默认为 false，启用后可在私有函数边界显式传递动态所有权信息。不能把默认规则当成无例外的所有权模型。见 [Passes.td](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/Transforms/Passes.td:193)。
8. Buffer Hoisting 优化合法 IR 中分配的位置，不负责修复定义不支配使用的无效 IR。Buffer Loop Hoisting 是移出循环；Deallocation Simplification 利用静态事实减少运行时别名检查，并非只有执行这个优化 pass 才能避免重复释放。通用 dealloc 的条件和别名语义本来就要保证正确性。见 [Passes.td](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/Transforms/Passes.td:235)。
9. Lower Deallocations 除 `memref.dealloc` 外，还可能产生 `arith`、`scf`、`func` 操作及辅助函数；完整 pipeline 还在它之后执行 CSE 和 canonicalization。Results To Out Params 需要同时修改函数与调用点，不能只改一个函数签名，也不自动保证减少分配。见 [Passes.td](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/Transforms/Passes.td:255)。
10. 本地 `buffer-deallocation-pipeline` 的确是八步：expand-realloc（`emit-deallocs=false`）、canonicalize、ownership-based-buffer-deallocation、canonicalize、buffer-deallocation-simplification、bufferization-lower-deallocations、cse、canonicalize。见 [BufferizationPipelines.cpp](/opt/llvm-project/mlir/lib/Dialect/Bufferization/Pipelines/BufferizationPipelines.cpp:21)。书中图 9-9 的此顺序正确；本地 Bufferization.md 的概要列表遗漏了第一个 canonicalize。该 pipeline 的输入不应已有其他释放操作（realloc 的特殊处理除外）。
11. 四种变换操作属于 **Transform 方言的 Bufferization 扩展**，不是原文误写的 Vector 方言。完整名为 `transform.bufferization.buffer_loop_hoisting`、`transform.bufferization.one_shot_bufferize`、`transform.bufferization.eliminate_empty_tensors`、`transform.bufferization.empty_tensor_to_alloc_tensor`。见 [BufferizationTransformOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/TransformOps/BufferizationTransformOps.td:26)。
12. 9.5 中 clone 示例主动释放 `%arg0`；需要明确它假设函数有权释放这个分配，不能与默认“参数只借用”的所有权 ABI 混用，也不能把已有显式 dealloc 的示例直接喂给上述所有权 pipeline。具体 `convert-bufferization-to-memref` 的复制输出只证明这次转换的行为，不能据此把 clone 的抽象契约缩成单一实现。

## 实测

执行 `python3 mlir/insider-compiler/issues/evidence/ch9-bufferization/run.py` 可复现；命令和退出状态见 [results.json](results.json)。

- [analysis.mlir](analysis.mlir) 两个函数仅返回标量。无冲突版本使用一次分配，冲突版本读取旧 tensor，实际产生第二次分配和 `memref.copy`，见 [one-shot.mlir](one-shot.mlir)。
- One-Shot 输出没有 `memref.dealloc`；接入释放 pipeline 后，所有这些局部分配在返回前释放，见 [deallocated.mlir](deallocated.mlir)。这只验证这两个简单函数，不代表复杂跨函数所有权已全覆盖。
- [pipeline.stderr.txt](pipeline.stderr.txt) 是 `--dump-pass-pipeline` 的实际输出，确认八步顺序。
- 不受支持的 `bottom-up-from-terminators` 在当前 DEBUG 构建中触发 `llvm_unreachable`，以 SIGABRT（Python 返回码 -6）结束，见 [unsupported-order.stderr.txt](unsupported-order.stderr.txt)。这是保存的预期失败证据，不是通过解析的例子。
