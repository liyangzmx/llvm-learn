# 第 13 章流水线阶段与边界独立核对

范围：合订 PDF 第 92–95 页的清单 13-37～13-40，以及第 13 章流水线解释。固定 Triton 提交为 `47fc046ff29c9ea2ee90e987c39628a540603c8f`，见[源码来源](triton-source.md)。本记录没有编译 Triton 或运行 GPU。

## 默认阶段数及粗调度

- [`Passes.td:20`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/include/triton/Dialect/TritonGPU/Transforms/Passes.td#L20) 的 `tritongpu-pipeline` 默认 `num-stages=3`；[`compiler.py:65`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/third_party/nvidia/backend/compiler.py#L65) 的 NVIDIA 后端配置也默认 3。
- [`SoftwarePipeliner.cpp:100`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/lib/Dialect/TritonGPU/Transforms/Pipeliner/SoftwarePipeliner.cpp#L100) 优先采用循环上的阶段数属性；阶段数 ≤ 1 时跳过。外层循环的另一条尝试路径使用 2 阶段，不能将其误当作本例的默认值。
- [`MatmulLoopPipeline.cpp:578`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/lib/Dialect/TritonGPU/Transforms/Pipeliner/MatmulLoopPipeline.cpp#L578) 将 dot 等根使用者置于 `numStages - 1`，本例为 2。没有间接加载层级时，两条 load 的粗阶段为 0。阶段数为 3，最大阶段编号为 2，应区别这两个数字。
- 主校对与章节代理分别目视 PDF 第 95 页：清单 13-40 先有一个空的 `Ops in stage 1`，随后才是 `Ops in stage 2` 和 dot。Vision 漏识后一标题，不是原书把 dot 放到 stage 1。

## 清单 13-38 的尾声下标

对迭代空间 `[0, N)`、单位步长、`N ≥ 2` 的三阶段教学模型，前言执行 `S0(0), S0(1), S1(0)`；稳态循环 `I in [0, N-2)` 执行 `S0(I+2), S1(I+1), S2(I)`。剩余尾声应为：

```text
S1(N-1)
S2(N-2)
S2(N-1)
```

原书的 `S1(N), S2(N-1), S2(N)` 多处理了越界的第 N 次，并分别漏掉 `S1(N-1)`、`S2(N-2)`。这是原图可见的内容错误。[枚举程序](ch13-pipeline-boundary.py)核对修正模型每个阶段的每次迭代恰出现一次，并输出原式反例，见 [运行结果](ch13-pipeline-boundary.json)。`N < 2` 需要保护或回退，本枚举采用未流水化的回退，未声称原书裸伪代码能处理短循环。

## 教学模型与真实实现的区别

本提交 [`MatmulLoopPipeline.cpp:1127`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/lib/Dialect/TritonGPU/Transforms/Pipeliner/MatmulLoopPipeline.cpp#L1127) 实际设置 `peelEpilogue = false`，并提供 `predicateFn = tt::predicateOp`、`supportDynamicLoops = true`。因此不应把清单 13-38 的显式尾声教学形式写成后续所有真实 IR 的结构。

[`PipelineExpander.cpp:440`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/lib/Dialect/TritonGPU/Transforms/Pipeliner/PipelineExpander.cpp#L440) 仅在剥离尾声时将上界改为 `ub - maxStage * step`；未剥离路径通过谓词处理向前错开的操作。阶段划分、缓冲区个数也不同：[`createAsyncOps`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/lib/Dialect/TritonGPU/Transforms/Pipeliner/MatmulLoopPipeline.cpp#L942) 按 load 到使用者的最大阶段距离决定缓冲区数，对某些 Hopper 情形还会增加，不能简单把三阶段等同三份共享缓冲区。

上游 `test/TritonGPU/loop-pipeline.mlir` 是变换结构测试，且与书例的返回值、B 缩放等内容不同；正文不能直接用该整份输入替换扫描件清单，源码仅用于核对机制和指出差异。
