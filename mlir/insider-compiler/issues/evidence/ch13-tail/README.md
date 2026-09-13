# 第13章尾段校核证据

覆盖合订扫描PDF118的第8项至PDF130；实际目视118–130全部13页。正文保留12份清单（48–59）、6张表（8–13）、图6、7条脚注。PDF118的页标由前段提供，尾段仅增加119–130。

本目录中的 `listing-13-48`～`listing-13-59` 为永久清单；普通输入/输出使用 `.mlir`，两个未完成构造过程的快照55、56使用 `.txt`。原OCR不修改。清单53、55、56将扫描中重复展开的类型或布局提取为别名，完整类型和操作内容保留。

## 版本与验证边界

参考原书固定 [Triton commit 47fc046ff29c9ea2ee90e987c39628a540603c8f](https://github.com/triton-lang/triton/tree/47fc046ff29c9ea2ee90e987c39628a540603c8f)，源码来源/归档哈希见[共同来源记录](../triton-source.md)。其配套LLVM提交为 `657ec7320d8a28171755ba0dd5afc570a5a16791`；本地LLVM18.1.8 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff` 不注册这些Triton方言，也不是该Triton编译版本。

**未构建或运行 triton-opt，未做 Triton parser/verifier、实际 pass、PTX 或 GPU 执行。**结构检查不能代替编译器验证。清单55、56保留书中短暂不一致的IR构造快照，不能单独送给 verifier。清单48、50、58与固定源码测试输入核对；其他输出的操作、属性、类型和数据流按源码审阅。

## 实际执行的检查

从仓库根目录运行；脚本默认只依赖本目录的永久清单。合并后可增加正式正文路径以检查跨页拼接及编号。

```sh
python3 mlir/insider-compiler/issues/evidence/ch13-tail/verify_tail.py
python3 mlir/insider-compiler/issues/evidence/ch13-tail/verify_tail.py \
  --markdown mlir/insider-compiler/insider-compiler-ch13.md
```

实际检查结果写入 [tail-check-results.json](tail-check-results.json)：

- 12份永久清单词法分隔符检查通过；其中55/56仍明确标为临时不合法IR。
- 正文清单48–59与永久清单12/12逐项匹配；119–130页标12/12，表8–13共6张，图6，7条尾部脚注。
- 对清单58进行独立算术推导：repShape `[16,1]`，inVec/outVec均为1，pad后`[16,2]`，按f32为128字节。它没有运行Allocation.cpp；源函数与计算理由见[章节校订记录](../../ch13.md#ch13-tail-allocation)。
- 对54与57建立有序store轨迹语义模型，比较false和true两个条件分支。false只有最后存1张量；true保留先存输入、再存0张量，两种改写前后轨迹均相同。这个检查不将设备存储模型或Triton源码当作已执行。

## 对应源码与预期复现入口

以下命令仅供配套Triton环境复现，本轮**没有执行**：

```sh
triton-opt listing-13-48.mlir -split-input-file -tritongpu-optimize-dot-operands
triton-opt listing-13-50.mlir -split-input-file -tritongpu-reduce-data-duplication
triton-opt listing-13-52.mlir -decompose-unsupported-nvidia-conversions
triton-opt listing-13-54.mlir -tritongpu-combine-tensor-select-and-if
triton-opt listing-13-58.mlir -split-input-file -allocate-shared-memory
```

| 清单/表 | 固定提交的主要实现或测试 |
| --- | --- |
| 48–49、表8 | [`OptimizeDotOperands.cpp`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/lib/Dialect/TritonGPU/Transforms/OptimizeDotOperands.cpp)、[`dot-operands.mlir`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/test/TritonGPU/dot-operands.mlir) |
| 50–51 | [`ReduceDataDuplication.cpp`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/lib/Dialect/TritonGPU/Transforms/ReduceDataDuplication.cpp)、[`reduce-data-duplication.mlir`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/test/TritonGPU/reduce-data-duplication.mlir) |
| 表9–13 | [`ReorderInstructions.cpp`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/lib/Dialect/TritonGPU/Transforms/ReorderInstructions.cpp) |
| 52–53 | [`DecomposeUnsupportedConversions.cpp`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/third_party/nvidia/lib/TritonNVIDIAGPUToLLVM/DecomposeUnsupportedConversions.cpp) |
| 54–57 | [`CombineTensorSelectAndIf.cpp`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/lib/Dialect/TritonGPU/Transforms/CombineTensorSelectAndIf.cpp) |
| 58–59 | [`Allocation.cpp`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/lib/Analysis/Allocation.cpp)、[`AllocateSharedMemory.cpp`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/lib/Conversion/TritonGPUToLLVM/AllocateSharedMemory.cpp)、[`divide-by-0.mlir`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/test/Conversion/divide-by-0.mlir) |

共享分配的第二次独立源码核对见 [allocation-review.md](allocation-review.md)；原divide-by-0测试检查的是避免除零，不是128字节断言，不能把测试文件存在当成运行证据。

13.4历史事实、性能比例、论文限定和未确认Google Slides链接见 [future-review.md](future-review.md)。原Google Slides脚注已对照 [PDF129页底局部扫描](footnotes-129.png)；本次未获取幻灯片内容，未声称已读。
