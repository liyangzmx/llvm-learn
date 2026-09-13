# 第1章示例与验证证据

> 本目录是第1章扫描补录批次的历史输入、输出与运行记录。此后的校订读本已修正清单1-4～1-7的偏置加入顺序；当前正文请使用[新版验证入口](../reading-edition/ch1/README.md)。下文“与最终Markdown一致”和bias-first结果均指本历史批次，不再代表当前正文；旧 `verify.py` 对照当时正文，不能直接当作当前正文检查脚本。

第1章使用更新后的14页PDF。本目录原有的 `preexisting-content-sha256.json`、`manifest-before-ch1.json` 由根代理持有，校订代理未修改它们。背景核对与浮点反例文件亦由根代理独立提供。

## 输入与边界

- `listing-1-1.py`、`listing-1-2.mlir`～`listing-1-8.mlir`与最终Markdown清单保持一致。1是补齐导入后的Python语法示例；2–7保留原书的截断常量；8是缺少入口和部分值定义的LLVM方言节选，不能直接作为完整程序运行。
- `validation-data.json`记录本次单独选定的权重和偏置。`complete-1-2.mlir`～`complete-1-7.mlir`只替换这两处截断数据，未伪造恢复原书参数；脚本逐项核对替换内容。
- `snippet-fixture.mlir`为清单8补类型/控制流验证用上下文，参数并不重建模型的地址或向量化方式，未将其当模型kernel执行。
- 本次验证所用的Python环境无torch、torch_mlir。Python只做AST与compile语法检查，未导入或执行前端。

本地MLIR/LLVM版本是18.1.8、提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。详细内容改正与本地源码链接见[第1章校订记录](../../ch1.md)。

## 永久复现入口

在仓库根目录执行。小型翻译工具只使用现有已构建的MLIR库，将LLVM方言导出LLVM IR并调用LLVM verifier；不构建LLVM本身。

```sh
cmake -S mlir/insider-compiler/issues/evidence/ch1 \
  -B /private/tmp/insider-ch1-build \
  -DMLIR_DIR=/opt/llvm-project/build/lib/cmake/mlir \
  -DLLVM_DIR=/opt/llvm-project/build/lib/cmake/llvm
cmake --build /private/tmp/insider-ch1-build --target ch1-translate
python3 mlir/insider-compiler/issues/evidence/ch1/verify.py \
  --translator /private/tmp/insider-ch1-build/ch1-translate
```

本轮实际复用了第11章已编译的相同翻译器二进制 `/private/tmp/insider-ch11-build/ch11-translate`；本目录保存字节相同的 `translate.cpp` 及独立CMake目标，临时二进制丢失后可按上述命令重建。实际调用路径及每条命令的退出状态记录在 [verification-results.json](verification-results.json)。没有声称本轮又编译了ch1-translate目标。

## 已执行结果

`verify.py`共执行22条命令，全部符合预期退出状态；其中21条成功、1条是明确记录的BaseInference预期失败：

- 正式正文14页标、8清单、4图号、12脚注、1注意框与永久清单一致。
- 六份补全参数的IR通过LLVM18的parser/verifier；TOSA的MainInference profile验证通过。
- `tosa-to-linalg-explicit.mlir`是实际显式转换结果。它先零初始化batch_matmul，再单独加bias，与原书bias-first手工改写有浮点次序差别。
- `linalg-to-affine.mlir`是实际One-Shot Bufferize加linalg-to-affine输出；仍保留尺寸为1的外层循环和返回缓冲区等形式，不冒充书中手工简化的输出参数版本。
- `affine-to-llvm.mlir`是1-6完整实例实际降低后的LLVM方言；三个主要转换输出均再解析一次。
- `affine.ll`、`snippet-fixture.ll`通过翻译器内置LLVM verifier并通过本地llvm-as。
- 系统clang以`-O0 -ffp-contract=off`编译 `affine.ll` 与 `run-forward.c`，实际运行结果：

```text
PASS: 40 inputs x 10 outputs; generated LLVM18 scalar kernel matches bias-first f32 reference.
```

这个测试覆盖非均匀输入、非对称权重、偏置、索引次序、输出初值与memref ABI，对比的是同一求值顺序。测试数据采用易于精确表示的值；它不是对任意浮点重排的等价证明，不验证原书缺失权重，更不是GPU性能测试。

默认 `--tosa-to-linalg-pipeline`退出1、无诊断，是本地快捷pipeline硬编码BaseInference并拒绝f32所致；对应源码定位见[校订记录](../../ch1.md#ch1-validation)。脚本将该失败作为预期行为单独记录，再使用适合浮点示例的MainInference校验和显式lowering，未把失败输出假装成转换结果。

## 独立复核

[context-review.md](context-review.md)包含Presburger常数除法约束、TensorFlow/StableHLO历史、Verona及企业贡献说法的确认边界。

[bias-order.py](bias-order.py)和[bias-order.json](bias-order.json)展示bias后加与先加的binary32反例。原始PDF12脚注已访问确认，指向2022年《从PyTorch到RTL：基于MLIR的高层次综合技术》；未据其旧版本代码替代本地验证。
