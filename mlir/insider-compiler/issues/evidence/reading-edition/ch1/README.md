# 第1章当前阅读版：先归约，后加偏置

本目录对应[当前正文](../../../../insider-compiler-ch1.md)的清单1-4～7及[归约顺序校订](../../../ch1.md#ch1-numerics)。基准为本地 LLVM18.1.8，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。原始OCR与原 `evidence/ch1/` 的输入、输出、脚本都未覆盖；原README可增加批次跳转说明。

正文中的矩阵乘从零初始化，归约完成后才加偏置。旧版把偏置置于初始累加值，会改变浮点舍入次序，现仅保存在 [before-bias-first.md.txt](before-bias-first.md.txt) 中供追溯。旧版40组输入的运行结果不能作为当前清单的验证记录。

## 文件与数据

- `listing-1-4.mlir`～`listing-1-7.mlir`由脚本从正式Markdown直接提取；跨页代码连接后仍与正文一致。
- `complete-1-4.mlir`～`complete-1-7.mlir`只把其中两种截断常量替换为 [validation-data.json](validation-data.json) 的完整参数。该文件逐字复制旧批次的显式测试数据：`W[k][j]=((3*k+5*j)%17-8)/8`，`b[j]=j/4-1`；不冒充原书缺失的训练参数。正文1-2/3没有改动。
- `linalg-to-affine.mlir`是新版1-4通过缓冲化、linalg到affine降级的实际输出。
- `affine-to-llvm.mlir`和`affine.ll`是新版1-6的真实LLVM方言与LLVM IR输出。
- [run-forward.c](run-forward.c)使用由同一参数文件生成的 `validation-data.h`，按明确的标量float32顺序独立计算参考，并检查旧bias-first参考确实有不同结果。
- [old-evidence-sha256.json](old-evidence-sha256.json)保留旧目录35项文件的校订前哈希；脚本严格检查其中34项代码、数据和结果不变，旧README仅作为批次元说明例外。

## 实际验证与复现

```sh
cd /opt/coding/mlir-toy
python3 mlir/insider-compiler/issues/evidence/reading-edition/ch1/verify.py \
  --translator /private/tmp/insider-ch11-build/ch11-translate
```

此次复用第11章已编译的翻译辅助程序；它使用MLIR的LLVM翻译接口并调用LLVM模块验证器。其永久源码是 [translate.cpp](../../ch11/translate.cpp) 和 [CMakeLists.txt](../../ch11/CMakeLists.txt)。若临时构建目录已清理，可按以下命令重建该既有工具；本批次没有重新构建LLVM或辅助工具。

```sh
cmake -S /opt/coding/mlir-toy/mlir/insider-compiler/issues/evidence/ch11 \
  -B /private/tmp/insider-ch11-build \
  -DMLIR_DIR=/opt/llvm-project/build/lib/cmake/mlir
cmake --build /private/tmp/insider-ch11-build --target ch11-translate
```

[verify.py](verify.py)记录13条实际命令至 [verification-results.json](verification-results.json)，全部退出0：

1. 读取工具版本；4份完整化IR经`mlir-opt`解析和验证。
2. 新版1-4实际缓冲化并降为affine；新版1-6降为LLVM方言；两个结果再次解析和验证。
3. 导出LLVM IR，经模块验证器及`llvm-as`检查。
4. `/usr/bin/clang -O0 -ffp-contract=off`编译，执行80组输入、800个输出的逐位比较。

实际原生输出：

```text
PASS: 80 inputs x 10 outputs match zero-initialized, bias-last f32 reference; 39 outputs distinguish the historical bias-first reference.
```

前40组输入沿用旧批次的小数值，后40组乘以`2^24`以放大舍入顺序差异。39项差异说明这组测试能检出原先偏置提前累加的问题。脚本同时检查两组注释版与无注释版代码一致，以及本章14页、8清单、4图、12脚注标记。

## 边界

这次只验证修正后的数值语义链，不再执行未变的Python/TOSA检查。没有执行PyTorch或torch-mlir，没有复原原书权重，也没有重建清单1-8省略的向量化算法。原书的截断常量仍明确是展示省略；完整化文件才可独立解析。Linalg与手工Affine清单保留了偏置的加入阶段，但不声称两者的打印结果或函数ABI相同，也不以有限样例证明所有浮点输入、任意归约调度或目标指令实现均逐位等价。原生测试使用互不重叠的输入与输出缓冲区，未启用浮点收缩或重关联。
