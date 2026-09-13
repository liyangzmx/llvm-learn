# 第 8 章校订记录

覆盖 `insider-compiler-ch7-ch10.pdf` 的 PDF 第 21–26 页（书页 148–153）。Apple Vision 原始 OCR 不改动；已实际目视全部 6 张逐页 PNG，保留 8.1、8.2、8.2.1–8.2.3、8.3 正文，代码清单 8-1/8-2、图 8-1、3 条页脚脚注与 1 个注意框；本章没有表格。图 8-1 的 `tosa` 到 `linalg/tensor/scf/arith/ml_program` 五条边已重建为 Mermaid。

校订基准是本地 LLVM **18.1.8**，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`，工具为 `/opt/llvm-project/build/bin/mlir-opt`。原书参考 LLVM 20，但部分示例与已查证的 LLVM 20.1.8 也不一致，不能统一归为版本差异。下面区分 OCR/印刷错误、内容问题与本地缺失的功能。

## 修正与依据

| 扫描位置 | 修正内容 | 依据 |
| --- | --- | --- |
| p. 21，8.1 | “5 种业务接入方言”改为本书的分类，不声称 MLIR 仅有这五种接入方式或仅两个机器学习相关方言。原文 `mcp` 改为 `mpi`；本地源码没有 MPI 方言，保留书稿项目并标注不能在本地验证。 | 本地 `/opt/llvm-project/mlir/include/mlir/Dialect/` 目录及 `mlir-opt --help`；未以本地缺失推断所有版本均无 MPI。 |
| p. 21–22，ml_program | 原文“社区尚未实现其优化与降级”过度概括。本地已有全局读写优化 `mlprogram-pipeline-globals`。正文区分已有优化与目标执行环境的完整后续降级；保留 IREE 历史脚注并注明未编译外部项目。 | [Passes.td](/opt/llvm-project/mlir/include/mlir/Dialect/MLProgram/Transforms/Passes.td:16) |
| p. 22，TOSA 设计目标 | 保留操作集、功能最小化、精度三项目标与权衡叙述；“几乎所有 AI 模型需要条件与循环”改为部分模型需要相应逻辑。数值行为强调版本化精度/兼容性要求，而非所有硬件无条件逐位相同。 | [TosaOpBase.td](/opt/llvm-project/mlir/include/mlir/Dialect/Tosa/IR/TosaOpBase.td:23)、[TOSA 官方介绍](https://www.mlplatform.org/tosa/) |
| p. 22–23，操作名称与含义 | `arg_pool2d` 改为 `avg_pool2d`；`argmax` 返回最大值所在的索引，不是最大值；恢复 OCR 破坏的 `fft2d/rfft2d`。布尔逻辑与整数逻辑移位分别说明；本地整数除法名为 `tosa.div`，书写 `int_div`，本地也没有 `sin/cos`，在正文保留差异说明。本地操作 TD 中共 75 个操作（TosaOps 70 + TosaUtilOps 5）。 | [TosaOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Tosa/IR/TosaOps.td:35)、[TosaOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Tosa/IR/TosaOps.td:64)、[TosaOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Tosa/IR/TosaOps.td:609)、[TosaUtilOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Tosa/IR/TosaUtilOps.td:28) |
| p. 23，8.2.1 | 恢复 `ApplyScaleGenericOpConverter` 大写名称；同时说明可转换 `tosa.const`。区分 C++ `IfOp/WhileOp` 与文本 `tosa.cond_if/tosa.while_loop`。变量操作的真实名称为 `variable.write/variable.read`。各后端可能同时生成辅助方言，不能保证“其他所有操作均能无条件降级”。 | [TosaToArith.cpp](/opt/llvm-project/mlir/lib/Conversion/TosaToArith/TosaToArith.cpp:61)、[TosaToArith.cpp](/opt/llvm-project/mlir/lib/Conversion/TosaToArith/TosaToArith.cpp:243)、[TosaToSCF.cpp](/opt/llvm-project/mlir/lib/Conversion/TosaToSCF/TosaToSCF.cpp:178)、[TosaToMLProgram.cpp](/opt/llvm-project/mlir/lib/Conversion/TosaToMLProgram/TosaToMLProgram.cpp:74)、[TosaToTensor.cpp](/opt/llvm-project/mlir/lib/Conversion/TosaToTensor/TosaToTensor.cpp:419) |
| p. 23，形状推导 | tensor 的 `ShapedType` 相关抽象不是 `shape` 方言的 shape 类型。`shapeInterface` 是局部变量，真正接口为 `InferShapedTypeOpInterface`，通过 `inferReturnTypeComponents` 推导返回类型组成。 | [TosaInferShapes.cpp](/opt/llvm-project/mlir/lib/Dialect/Tosa/Transforms/TosaInferShapes.cpp:203) |
| p. 23–24，常量与广播 | 常量合并改为常量折叠；广播 Pass 通过前置大小为 1 的维度统一输入秩，不是修复任意不一致类型，也不改变元素类型或使不兼容尺寸合法。 | [Passes.td](/opt/llvm-project/mlir/include/mlir/Dialect/Tosa/Transforms/Passes.td:20)、[Passes.td](/opt/llvm-project/mlir/include/mlir/Dialect/Tosa/Transforms/Passes.td:51) |
| p. 24，分解 | 1×1 卷积分解还要求步长为 1 等条件；本地主要路径为 reshape → fully_connected → reshape，不是单靠 reshape 完成卷积。 | [TosaDecomposeConv2D.cpp](/opt/llvm-project/mlir/lib/Dialect/Tosa/Transforms/TosaDecomposeConv2D.cpp:9)、[TosaDecomposeConv2D.cpp](/opt/llvm-project/mlir/lib/Dialect/Tosa/Transforms/TosaDecomposeConv2D.cpp:43) |
| p. 24，减少转置 | 本地不存在 `tosa-reduce-transposes` Pass 名称或对应源码。保留书稿对算法的描述并标记为本地不可用，未将该段删除或声称已运行。 | 全树 `rg -e reduce-transposes -e ReduceTransposes /opt/llvm-project/mlir` 无匹配，工具帮助中无此项；[Passes.td](/opt/llvm-project/mlir/include/mlir/Dialect/Tosa/Transforms/Passes.td:20) |
| p. 24，validate | `tosa-validate` 是验证 Pass，依据 profile、level 和严格对齐选项执行检查，不是优化，也不替代操作自身 verifier 或证明所有语义正确。 | [Passes.td](/opt/llvm-project/mlir/include/mlir/Dialect/Tosa/Transforms/Passes.td:98) |
| p. 24–25，清单 8-1/8-2 | 书中 `tosa.const` 属性为 `values`，本地为单数 `value`；四输入 `matmul` 与本地两输入定义不符。正文给出本地修订版，保留两零常量用于后文死代码演示；输出清单采用本地实际降级结果，仅调整排版与添加解释注释。 | [TosaOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Tosa/IR/TosaOps.td:250)、[TosaOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Tosa/IR/TosaOps.td:1883)，实际错误输出见证据目录。 |
| p. 24，零点语义 | 零点是量化整数中对应实数零的位置，不是类型标志；int8 量化可以使用零零点。“int8 则标志非零”已修正。 | [TosaOpBase.td](/opt/llvm-project/mlir/include/mlir/Dialect/Tosa/IR/TosaOpBase.td:101)、[TosaToLinalgNamed.cpp](/opt/llvm-project/mlir/lib/Conversion/TosaToLinalg/TosaToLinalgNamed.cpp:591)，本次实际零零点测试。 |
| p. 25，累加与转换选择 | 本地 `matmul` 无独立 `acc_type`；转换按结果元素类型构造零累加张量。是否生成 `quantized_batch_matmul` 的直接条件为 `quantization_info` 是否存在，而不是输入为 int8。保留 f16/f32 组合并说明本次验证范围。 | [TosaToLinalgNamed.cpp](/opt/llvm-project/mlir/lib/Conversion/TosaToLinalg/TosaToLinalgNamed.cpp:557)、[TosaToLinalgNamed.cpp](/opt/llvm-project/mlir/lib/Conversion/TosaToLinalg/TosaToLinalgNamed.cpp:584) |
| p. 25，注意框 | 原文 CSE 可删除 `%0/%1` 的结论正确，已实测，不误改为“CSE 不能删除死代码”。补充 CSE 实现先检查 `isOpTriviallyDead` 的原因。 | [CSE.cpp](/opt/llvm-project/mlir/lib/Transforms/CSE.cpp:233) |
| p. 25–26，linalg 设计 | `tensor.empty` 构造张量值，不立即决定物理内存分配。完美循环改为完美嵌套循环；`linalg.generic` 受索引映射、迭代空间等约束，并非任意未知秩 tensor 或任意程序都可表示。保留两种方言设计目的比较。 | [Linalg 文档](/opt/llvm-project/mlir/docs/Dialects/Linalg/_index.md:456) |

## 矩阵乘法示例的较大版本差异

[扫描清单 8-1 的完整目视转写](evidence/ch8/book-8-1.mlir)保留书中的 `values` 与四操作数形式。本地直接解析首先报常量缺少 `value` 属性；只修正属性名后，[四操作数输入](evidence/ch8/book-four-operands.mlir)继续报 `expected 2 operands, but found 4`。这两项错误是实际工具结果，不是仅凭推测判断。

额外读取了官方固定标签 [LLVM 20.1.8 的 TosaOps.td](https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-20.1.8/mlir/include/mlir/Dialect/Tosa/IR/TosaOps.td)，其 `Tosa_MatMulOp` 同样只声明 `a`、`b` 两个张量输入和可选 `quantization_info`。因此书中四输入形式与本地 18.1.8 以及本次核对的 20.1.8 均不相符。其是否来自更晚的开发版本，扫描书页没有足够信息确定；不将这个推测写成已核实事实。正文以本地真实代码为准，并保留原例链接供追溯。

## 实际验证

输入、输出、命令及返回码保存在 [evidence/ch8](evidence/ch8/)。复现入口为 [run_checks.py](evidence/ch8/run_checks.py)，完整本次执行记录见 [commands-and-results.txt](evidence/ch8/commands-and-results.txt)。

```sh
python3 mlir/insider-compiler/issues/evidence/ch8/run_checks.py
```

所有下列预期均已由真实本地工具确认：

1. [matmul-local.mlir](evidence/ch8/matmul-local.mlir) 经 `builtin.module(func.func(tosa-to-linalg-named))` 转换成功，生成 `tensor.empty`、`linalg.fill`、`linalg.batch_matmul`，并保留两个无用途 `tosa.const`；[实际输出](evidence/ch8/matmul-local.out)与正文清单 8-2 对应。
2. 转换管线追加 `cse` 后两个常量均删除：[matmul-cse.out](evidence/ch8/matmul-cse.out)。
3. [matmul-quantized.mlir](evidence/ch8/matmul-quantized.mlir) 使用 int8 输入、i32 结果，零点 `a_zp=0/b_zp=0`，成功生成 `linalg.quantized_batch_matmul`，反证“量化零点必须非零”。
4. [broadcast.mlir](evidence/ch8/broadcast.mlir) 从 `tensor<4xf32>` 与 `tensor<2x4xf32>` 广播，经 `tosa-make-broadcastable` 插入到 `tensor<1x4xf32>` 的 reshape，验证 Pass 针对秩的补齐。
5. [matmul-f16.mlir](evidence/ch8/matmul-f16.mlir) 的 f16 输入、f16 结果，以及 f16 输入、f32 结果均成功转换为 `linalg.batch_matmul`；未声称该工具验证等于全部 TOSA 数值一致性测试。
6. 两个原书形式分别按预期退出 1，分别捕获 [属性名错误](evidence/ch8/book-8-1.out) 和 [操作数数量错误](evidence/ch8/book-four-operands.out)。修订版成功解析，错误原例没有被算作通过。

本章没有尚未辨认的扫描文字或图节点。历史外部依赖的限度：IREE 项目主页已核对，历史 `ml_program` 降级实现未在本地构建；TensorFlow 历史 legalization 页面未成功通过官方固定版本地址取回，保留原书 Fossies 脚注链接，不声称复现其工程。`mpi`、`tosa-reduce-transposes`、TOSA `sin/cos` 的本地不可用性已在正文明确。没有为了验证这些差异修改本地 LLVM 源码。
