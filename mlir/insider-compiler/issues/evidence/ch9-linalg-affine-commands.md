# 第9章 linalg / affine 实测命令

工作目录为仓库根目录 `/opt/coding/mlir-toy`。所有输入、输出位于 `mlir/insider-compiler/issues/evidence/`。使用 `/opt/llvm-project/build/bin/mlir-opt`，实际版本 LLVM 18.1.8（Debug、启用 assertions），源码提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。

下表记录本次校订已执行的输入与结果；原始失败命令的输入仍保留，修订后成功输入另存，不覆盖原始 OCR。输出来自实际工具执行，没有手写模拟输出。空 stderr 文件仅表示对应执行没有打印诊断。测试范围为 IR 变换，不包含 JIT 数值运行或目标机器性能测量。

可从仓库根目录设置下面两个临时变量，随后执行表中各条命令：

```sh
ch9_opt=/opt/llvm-project/build/bin/mlir-opt
ch9_evidence=mlir/insider-compiler/issues/evidence
```

| 清单 / 检查 | 已执行的命令 | 结果 |
| --- | --- | --- |
| 9-1 → 9-2 | `"$ch9_opt" "$ch9_evidence/ch9-dot.mlir" --convert-linalg-to-std -o "$ch9_evidence/ch9-dot-std.mlir"` | 退出 0；生成库函数声明和 func.call |
| 9-3 → 9-4 | `"$ch9_opt" "$ch9_evidence/ch9-matmul.mlir" --convert-linalg-to-affine-loops -o "$ch9_evidence/ch9-matmul-affine.mlir"` | 退出 0；affine.for |
| 9-3 → 9-5 | `"$ch9_opt" "$ch9_evidence/ch9-matmul.mlir" --convert-linalg-to-loops -o "$ch9_evidence/ch9-matmul-scf.mlir"` | 退出 0；scf.for |
| 9-3 → 9-6 | `"$ch9_opt" "$ch9_evidence/ch9-matmul.mlir" --convert-linalg-to-parallel-loops -o "$ch9_evidence/ch9-matmul-parallel.mlir"` | 退出 0；scf.parallel 与归约循环 |
| 9-7 → 9-8 | `"$ch9_opt" "$ch9_evidence/ch9-conv1d.mlir" --test-linalg-transform-patterns=test-linalg-to-vector-patterns -o "$ch9_evidence/ch9-conv1d-vector.mlir"` | 退出 0；transfer、切片、contract |
| 9-12 原语法 | `"$ch9_opt" "$ch9_evidence/ch9-matmul-custom-maps-original.mlir" -o /dev/null` | 退出 1；在 indexing_maps 处报区域参数数量不符，诊断见 ch9-matmul-custom-maps-original-out.log |
| 9-12 本地形式 | `"$ch9_opt" "$ch9_evidence/ch9-matmul-transpose.mlir" -o "$ch9_evidence/ch9-matmul-transpose-checked.mlir"` | 退出 0；matmul_transpose_a 验证通过 |
| 9-13 本地形式 | `"$ch9_opt" "$ch9_evidence/ch9-matmul-broadcast.mlir" -o "$ch9_evidence/ch9-matmul-broadcast-checked.mlir"` | 退出 0；generic 广播、归约维度 5 |
| 9-15 → 9-16 | `"$ch9_opt" "$ch9_evidence/ch9-pooling.mlir" --linalg-generalize-named-ops --one-shot-bufferize --convert-linalg-to-loops -o "$ch9_evidence/ch9-pooling-loops.mlir"` | 退出 0；bufferization 和循环下标按正文 |
| 9-17 四种加法 | `"$ch9_opt" "$ch9_evidence/ch9-add-forms.mlir" -o "$ch9_evidence/ch9-add-forms-checked.mlir"` | 退出 0；完整函数四种形式解析验证 |
| 9-18 → 9-19 | `"$ch9_opt" "$ch9_evidence/ch9-elementwise-fusion.mlir" --linalg-fuse-elementwise-ops -o "$ch9_evidence/ch9-elementwise-fusion-out.mlir"` | 退出 0；两个 generic 融合 |
| 9-20 → 9-21 | `"$ch9_opt" "$ch9_evidence/ch9-greedy-fusion.mlir" --test-linalg-greedy-fusion -o "$ch9_evidence/ch9-greedy-fusion-out.mlir"` | 退出 0；生产者被分块融合到消费者循环 |
| 9-22 → 9-23 | `"$ch9_opt" "$ch9_evidence/ch9-conv1d-tensor.mlir" --one-shot-bufferize --convert-linalg-to-loops -o "$ch9_evidence/ch9-conv1d-tensor-loops.mlir"` | 退出 0；卷积双循环 |
| 9-22 → 9-24 | `"$ch9_opt" "$ch9_evidence/ch9-conv1d-tensor.mlir" --test-linalg-transform-patterns=test-linalg-to-vector-patterns -o "$ch9_evidence/ch9-conv1d-tensor-vector.mlir"` | 退出 0；四组 8 元素切片与 outerproduct |
| 9-25 原语法 | `"$ch9_opt" "$ch9_evidence/ch9-tile-forall-original.mlir" --transform-interpreter -o /dev/null` | 退出 1；mapping 后等号不合法，诊断见 ch9-tile-forall-original.log |
| 9-25 → 9-26 | `"$ch9_opt" "$ch9_evidence/ch9-tile-forall.mlir" --transform-interpreter -o "$ch9_evidence/ch9-tile-forall-out.mlir"` | 退出 0；scf.forall、尾块 affine.min、映射属性 |
| 9-31 → 9-32 | `"$ch9_opt" "$ch9_evidence/ch9-affine-loop.mlir" --lower-affine -o "$ch9_evidence/ch9-affine-loop-out.mlir"` | 退出 0；affine.for → scf.for |
| 仿射/半仿射及 min | `"$ch9_opt" "$ch9_evidence/ch9-affine-maps.mlir" --lower-affine -o "$ch9_evidence/ch9-affine-maps-out.mlir"` | 退出 0；三个映射可解析，min 转 arith.cmpi/select |

原始 mapping 失败诊断中的文件名来自当时尚未修订的 `ch9-tile-forall.mlir`；失败输入随后另存为 `ch9-tile-forall-original.mlir`。当前成功输入采用不带等号的测试操作语法。此命名整理没有重新运行已通过的全部测试，也没有将旧失败日志挂在成功输出名下。

逐元素融合和贪婪融合输入分别取自同一提交的 `mlir/test/Dialect/Linalg/fusion-elementwise-ops.mlir`、`tile-and-fuse-tensors.mlir` 对应函数，去掉了 FileCheck 注释，其计算与原书清单一致。贪婪融合例保留原测试的尾块缺失前提，详见 `issues/ch9.md`。

尾段 vector、clone、分块和可伸缩向量化的输入、脚本和结果见 [ch9-tail](ch9-tail/run.py)；独立 Bufferization 分析、释放及 Pass 流水线证据见 [ch9-bufferization/README.md](ch9-bufferization/README.md)。

为了检查正式 Markdown 中的代码未在转写或跨页拼接时损坏，另运行了：

```sh
python3 mlir/insider-compiler/issues/evidence/ch9-verify-front.py
```

前段 25 份完整 MLIR 清单全部解析、verifier 通过，见 [ch9-front-verified/results.json](ch9-front-verified/results.json)。该检查不再次执行上表变换；语法占位符、C 片段和需要外部 SSA 值的示意清单不作为完整 MLIR 输入验证。
