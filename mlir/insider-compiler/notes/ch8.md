# 第 8 章精华笔记：TOSA 的形状、数值与降级契约

[校订正文](../insider-compiler-ch8.md) · [读前导读](../guide/ch8.md) · [笔记目录](README.md)

## 1. 接入层保留什么（8.1、8.2）

TOSA 提供适合模型接入的公共张量算子集合，设计重点包括覆盖常见模型、控制单个操作的功能复杂度，以及明确精度和数值行为。它不负责为每种硬件直接选择最优调度。`ml_program` 表达机器学习程序结构与全局状态，可以与 TOSA 配合。

本书还将 mpi、acc、omp 列为接入方言，分别对应 MPI、OpenACC、OpenMP。这里是用途分类；本地 LLVM 18.1.8 不含书中所列 MPI 方言，不能把本地缺项推断为这类接入需求不存在。

## 2. 降级按语义分流（8.2.1）

| TOSA 中的任务 | 常见承接表示 | 需要继续考虑的工作 |
| --- | --- | --- |
| 矩阵乘法、卷积、逐元素计算 | linalg，配合 arith、tensor | 索引、目标初值、分块及后续代码生成 |
| `cond_if`、`while_loop` 等 | scf | 区域控制流和循环携带值 |
| 变量及读写 | ml_program | 全局状态及具体执行环境的后续实现 |
| concat、pad、reshape、slice 等 | tensor | 形状与张量结构，之后仍可缓冲化 |
| `apply_scale` 等数值处理 | arith 等组合 | 整数缩放、舍入及相关边界语义 |

箭头不是“整份输入只生成一个方言”的承诺。命名操作转换、通用计算转换和辅助方言处理可以是不同步骤，目标硬件及输入覆盖范围决定具体流水线。

## 3. 六类处理不能互相替代（8.2.2）

- `tosa-infer-shapes` 利用 `InferShapedTypeOpInterface` 等信息改进结果形状；它不把所有动态维度必然变成常量。
- `tosa-layerwise-constant-fold` 对可静态求值的层计算常量，可能增大常量张量和编译期内存。
- `tosa-make-broadcastable` 通过 reshape 等统一适用操作的输入秩，不转换元素类型，也不能修复不兼容的维度。
- `tosa-optional-decompositions` 将满足条件的较复杂操作分解。例如适用的 1×1 卷积可借助 reshape、fully_connected 等表达；只改形状无法代替卷积计算。
- 原书介绍的转置消减 `tosa-reduce-transposes` 在本地版本不存在，不能直接复制该选项。
- `tosa-validate` 检查指定 profile、level 等要求，与逐操作 verifier、形状推导、优化分别承担不同职责。

## 4. 两输入 matmul 的完整语义链（8.2.3）

本地 `tosa.matmul` 的两个输入与结果形状为：

$$
A:(N,H,C),\qquad B:(N,C,W),\qquad R:(N,H,W).
$$

清单 8-1 的具体形状是 `(1,5,3) × (1,3,6) → (1,5,6)`。两个额外零点张量不是此操作的输入；量化信息由可选 `quantization_info` 属性携带。原清单的四操作数形式已在校订正文纠正。

浮点示例的转换依次创建 `tensor.empty`，以 `linalg.fill` 写入零，再执行 `linalg.batch_matmul`。原因是后者采用目标传递风格并执行累加：

$$
R_{nhw}=C^{\mathrm{init}}_{nhw}
       +\sum_c A_{nhc}B_{ncw}.
$$

零初始化使其与 TOSA 的纯矩阵乘法对应。`tensor.empty` 内容未指定，不能直接当成全零目标；它与 fill 一起仍是张量值表示，不代表物理缓冲区分配已确定。

正文实际采用的入口是：

```sh
/opt/llvm-project/build/bin/mlir-opt matmul.mlir \
  --pass-pipeline='builtin.module(func.func(tosa-to-linalg-named))'
```

输入使用校订正文清单 8-1。输出保留的两个无用 TOSA 常量可以由 CSE 清理；转换模式本身不必包办所有清理。

## 5. 量化零点与计算精度分开看（8.2.3）

带量化属性时，本地转换生成 i32 零点标量，并选择 `linalg.quantized_batch_matmul`。相应整数乘加的核心是先减零点，再累积乘积，可记为 `Σ(qA−a_zp)(qB−b_zp)`；完整的量化模型还要另行处理所需的缩放、输出编码和精度要求，不能仅由这条乘加推导全部数值流程。

选择量化路径的直接依据是 `quantization_info` 是否存在，不是单看输入是否为 int8。两个零点可以都为零。零点也不是“输入类型标志”。

本地 matmul 没有独立 `acc_type` 参数；所示转换按声明的结果元素类型构造累加目标。正文已验证 f16 输入配 f16 结果、f16 输入配 f32 结果的具体转换，不能将其扩展成对任意精度组合或任意版本规范的保证。

## 6. 与 Linalg 的分工

TOSA 的名称和约束贴近模型算子。Linalg 用索引映射、迭代器类别和标量计算区域保留可变换的循环结构；`matmul` 是二维命名操作，`batch_matmul` 是三维批量形式，`generic` 提供更一般的结构化表达。

“通用”仍然要求合法的秩、形状、映射和计算区域。接入时先保住模型语义，降级时把它转成可进行融合、分块和向量化的结构，这正是第 9 章接下来的工作。
