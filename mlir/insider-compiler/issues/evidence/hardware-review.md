# 第 11、13 章硬件说明独立核对

本记录针对原书硬件背景中的具体断言，不替代章节转写。LLVM 方言/API 仍以本地 18.1.8 为准；寄存器、同步与内存层次等架构语义补查 Arm、NVIDIA 官方资料。校核日期：2026-09-13。没有进行 GPU 或 SME 硬件实测。

## Arm SME（合订 PDF 第 8–10 页）

依据 Arm 官方 [SME Introduction](https://developer.arm.com/community/arm-community-blogs/b/architectures-and-processors-blog/posts/arm-scalable-matrix-extension-introduction) 的 Streaming SVE mode、ZA array、ZA tiles 说明：

- 区分非流式向量长度与流式 SVL，二者可以不同；不能把“运行时有效长度”说成编译阶段自动选定任意硬件位宽。
- ZA 按字节表示为 `(SVL/8) × (SVL/8)` 字节阵列（SVL 以 bit 计）。原文裸写 `SVL × SVL` 缺少单位；图也需要明确单位。
- `ZA[m][n]` 只能作为概念索引，不能冒充 SME 汇编语法。架构有按元素类型区分的 tile 与水平／垂直切片，不是任意 4×4、8×8 子矩阵均有直接寻址语法。

依据 Arm 官方 [SME Instructions](https://developer.arm.com/community/arm-community-blogs/b/architectures-and-processors-blog/posts/arm-scalable-matrix-extension-introduction-p2) 的 Outer product、Predication、Tile slice load/store/move 说明：

- `FMOPA` 将两向量的外积累加到 ZA tile，不是用一条指令完成任意完整矩阵乘法。
- 两个输入向量分别受谓词控制；并非给任意 ZA 元素配独立的一位掩码。
- 不活跃元素行为取决于指令：切片加载的 `/Z` 清零，切片移动的 `/M` 保持，存储不写对应内存；原书将加载也说成“保持不变”应改正。

## NVIDIA 执行与存储模型（PDF 第 13–16 页及第 51 页）

依据固定版本 [CUDA 12.6 Programming Guide](https://docs.nvidia.com/cuda/archive/12.6.0/cuda-c-programming-guide/index.html) 的 Thread Hierarchy、Thread Block Clusters、Grid Synchronization、Compute Capability 8.x 说明：

- block 大小可以小于 32；cluster 是计算能力 9.0 起的可选层级，不能泛化到所有 GPU。图中的 cluster 应带条件说明。
- grid 内的跨 block 同步不会由运行时自动插入；协作网格需支持条件、协作启动及显式 `grid.sync()`。独立线程调度也不能作为免除程序同步的理由。
- L1 与共享内存在某些架构中共用可配置片上容量，但共享内存不是“由 L1 缓存的内存”。
- warp 在 NVIDIA CUDA 中为 32 线程，不是用户可自由调整的硬件参数。

依据 [CUDA 12.6 Best Practices Guide](https://docs.nvidia.com/cuda/archive/12.6.0/cuda-c-best-practices-guide/index.html) 的 Shared Memory and Memory Banks、Occupancy、Thread and Block Heuristics：

- 计算能力 5.x 及以后共享内存按连续 32-bit 字映射到 32 个 bank；不能写成“四字节 bank 仅适用于 Ampere 之前”。
- occupancy 提高不保证更快，寄存器压力、访存、指令并行等共同影响性能；块大小也不是 occupancy 的唯一决定因素。
- 没有给定 GPU 型号、缓存命中、访问模式与测量方式时，不能把寄存器 1–2、共享内存 2–5、全局内存 400–800 周期及容量 16–80 GB 写成通用规范。正文应保留层次差异，原数值作为原书举例存入问题记录。

依据 NVIDIA 官方 [Programming Tensor Cores in CUDA 9](https://developer.nvidia.com/blog/programming-tensor-cores-cuda-9/)，4×4 矩阵乘加／周期的描述是 Volta Tensor Core 背景，不能泛化为所有代际及每条 warp 级矩阵指令的延迟。cuBLAS 是否采用 Tensor Core 还取决于算法、类型及使用条件。

原文“Intel Ponte Vecchio 矩阵引擎自动识别任意数据重排模式并优化路径”没有在本次所核对的代码或资料中得到支持；应保留其为原书待证断言，不另造硬件机制。没有显式寄存器分配语法，也不能推出编译器没有寄存器复用，更不能据此证明 Triton 必然达不到某一性能上限。

## NVVM 所对应的硬件语义（PDF 第 27–29 页）

先核对本地 [NVVMOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/LLVMIR/NVVMOps.td)，硬件含义不足处补查 [NVIDIA PTX ISA](https://docs.nvidia.com/cuda/parallel-thread-execution/index.html) 对应操作／特殊寄存器条目：

| 项目 | 校订依据 |
| --- | --- |
| WGMMA 层级 | 本地定义第 1890 行明确为 128 线程的 warpgroup。不能等同多个 block 组成的 cluster。 |
| `mbarrier.init` | 本地第 217 行起区分 generic pointer 与 shared pointer；对象仍在共享内存，generic 地址不表示在寄存器创建 barrier。 |
| `expect_tx` | tx-count 的单位由被跟踪异步操作定义；bulk copy 的 bytes 形式计字节，不应笼统写为“复制操作的个数”。 |
| `setmaxregister` | 本地第 518 行映射到 `setmaxnreg.inc/dec` intrinsic。它在运行时调整执行 warp 的每线程寄存器额度，不能混同编译期 `.maxnreg` 限制。 |
| `%nsmid` | 返回 SM 标识符空间上界所需的数量，SM 编号不保证连续，可能大于物理 SM 数。 |
| `cluster.ctarank`／`cluster.nctarank` | 分别是 block 在 cluster 内的线性序号与 cluster 中 block 总数；不是 cluster 的 ID 与网格内 cluster 总数。 |
| `tcgen05.*` | 本地 18.1.8 没有这些 NVVM 操作。PTX 将其归入第五代 Tensor Core 指令并列出 `sm_100a` 等目标，不能将它们归为 Hopper 的指令。各操作支持范围需分别查目标条件。 |

这些核对不表示已生成并执行全部 PTX 操作。尤其原书列举的指令集合混合不同硬件代际和 MLIR 版本，不能当作本地支持列表。
