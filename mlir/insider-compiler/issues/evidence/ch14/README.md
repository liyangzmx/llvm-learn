# 第14章验证证据

基准：本地 LLVM18.1.8，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`；`mlir-opt` 为 DEBUG build with assertions，宿主为 arm64 macOS。源和修正理由见 [issues/ch14.md](../../ch14.md)，正式正文为 [insider-compiler-ch14.md](../../../insider-compiler-ch14.md)。

## 实际验证结果

[verify.py](verify.py)读取正式正文、提取13清单并核对9张系数矩阵，最近一次运行：**19条命令退出0，32项检查通过**。完整命令和检查名见 [verification-results.json](verification-results.json)。此计数只统计该脚本，独立数学／分块实验另有记录。

- 清单2、3加明确外围参数后解析；清单4、5、6、7、8、9、10、12按完整函数解析。
- 清单4经实际 `--affine-parallelize` 后，与清单5的规范化IR完全一致。
- 清单6和8经实际 `--affine-loop-fusion` 后，分别与清单7和12完全一致；三份转换输出均二次解析通过。
- C++辅助程序真实调用本地 Affine 分析：三层并行判断为 `true,true,false`，代表性访问对在深度1／2／3得到无／无／有依赖；表14-9的17行与实际输出逐行相同，完整整数采样确认最内层关系非空。
- 两个访问关系各6行与正文表14-1／14-2逐行一致。其余矩阵全部系数按访问公式和顺序约束校验；729组小域枚举验证关系组合、消去局部变量及依赖深度，额外检查−1／0／4095／4096边界。
- 真实融合调试日志复现23.81%、6.67x、260、400字节和60字节。动态写量的正确算式为10×15×4=600字节，不是60字节。
- 根代理独立数学反例全部通过，且真实原生执行证实本地分块漏检：原结果2、错误分块后1。

## 构建与复现

从仓库根 `/opt/coding/mlir-toy` 执行：

```sh
cmake -S mlir/insider-compiler/issues/evidence/ch14 \
  -B /private/tmp/insider-ch14-build \
  -DMLIR_DIR=/opt/llvm-project/build/lib/cmake/mlir \
  -DLLVM_DIR=/opt/llvm-project/build/lib/cmake/llvm \
  -DCMAKE_BUILD_TYPE=Release
cmake --build /private/tmp/insider-ch14-build -j2
python3 mlir/insider-compiler/issues/evidence/ch14/verify.py
```

CMake根据本地 `LLVM_ENABLE_RTTI` 关闭不兼容的 RTTI；初次链接遗漏此设置时曾报告 `typeinfo for mlir::FlatLinearValueConstraints` 未定义，已在最终 CMake 修复。最终构建成功，链接器仅提示重复静态库被忽略。

融合日志的原始取得命令：

```sh
/opt/llvm-project/build/bin/mlir-opt \
  mlir/insider-compiler/issues/evidence/ch14/fusion-union.mlir \
  --affine-loop-fusion --debug-only=affine-loop-fusion \
  -o mlir/insider-compiler/issues/evidence/ch14/fusion-union-after.mlir \
  2> mlir/insider-compiler/issues/evidence/ch14/fusion-union-debug.txt
```

初始独立验证输入为 `access.mlir`、`parallel.mlir`、`fusion-simple.mlir`、`fusion-union.mlir`；对应 `*-after.mlir` 为实际 Pass 输出。`analysis.cpp` 和 `CMakeLists.txt` 为永久源，`access-analysis.txt`、`parallel-analysis.txt` 为其实际输出。可单独执行：

```sh
/private/tmp/insider-ch14-build/ch14-analysis \
  mlir/insider-compiler/issues/evidence/ch14/parallel.mlir
/private/tmp/insider-ch14-build/ch14-analysis \
  mlir/insider-compiler/issues/evidence/ch14/access.mlir
```

`listing-14-*` 是从最终正文提取的永久文件：`.normalized.mlir` 为本地解析器规范化结果，`.wrapped.mlir` 为片段明确补充函数包络，`.transformed.mlir` 为实际 Pass 输出。它们不是 OCR 原始记录；原始 OCR 保持在 `ocr/` 中未改动。矩阵全部系数及小域计数保存在 [matrices.json](matrices.json)。

## 独立复核记录与执行边界

- [math-foundations-review.md](math-foundations-review.md)：凸集／凸函数、GCD、最优值等数学定义复核；[math-counterexamples.py](math-counterexamples.py)和[JSON](math-counterexamples.json)保存反例。
- [tiling-review.md](tiling-review.md)：分块的充分条件与 `lb<ub && ub<0` 漏检；[run-tiling-check.py](run-tiling-check.py)和[JSON](tiling-runtime-check.json)保存实际 MLIR 降级、LLVM IR verifier、宿主 Clang 编译和原生输出。源码清单、LLVM IR 与调试日志都在本目录。它复用[第11章导出程序](../ch11/translate.cpp)，不依赖新构建LLVM。

清单1／13为C片段，此处只作目视和语义核对，未另行编译。清单2／3只验证语法和依赖关系，仍需调用方提供在界内、初始化正确的内存。4096维例子没有进行大规模数值执行或并行性能测量。清单9／10为示意阶段，虽然语法可解析，不能称为实际 Pass 中间输出。有限域枚举用于附加一致性检查，完整理论结论还依赖正文给出的代数证明和实现审核。
