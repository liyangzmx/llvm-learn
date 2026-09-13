# 第 1 章背景与数学表述独立复核

复核基准：本地 LLVM 18.1.8，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。原始文字位于第 1 章 PDF 第 1、13、14 页。以下是校订证据，不替代原书正文或原始 OCR。

## Presburger、除法与取模

原书将“引入 mod、div 后仍能保证可计算性”与半仿射概念相连，并称“目前尚无相关论文”。该说法混淆了不同表达式范围，不能保留为技术事实。

本地 [Affine 方言说明](/opt/llvm-project/mlir/docs/Dialects/Affine.md:84)明确区分两类表达式：通常的 affine 表达式允许乘整数常量，以及对**正整数常量**取 `floordiv`、`ceildiv`、`mod`；[semi-affine](/opt/llvm-project/mlir/docs/Dialects/Affine.md:199)进一步允许符号作为乘数或除数。不能把后一种语法的全部表达能力直接等同于 Presburger 线性整数约束的可判定片段。

对固定正整数常量 `c`，引入整数局部变量 `q`，可直接将

```text
q = floor(a / c)
```

编码为两条线性不等式：

```text
c*q <= a
a <= c*q + c - 1
```

再以 `r = a - c*q` 得到余数，满足 `0 <= r < c`。由于 `c` 固定，这些仍是线性整数约束；并非加入任意变量乘除法。此处“可判定性”也比原书笼统的“可计算性”准确。

这不是仅有概念解释：[IntegerRelation.h](/opt/llvm-project/mlir/include/mlir/Analysis/Presburger/IntegerRelation.h:441)直接写出上述等价式；[addLocalFloorDiv 实现](/opt/llvm-project/mlir/lib/Analysis/Presburger/IntegerRelation.cpp:1510)检查正除数、追加局部变量并加入上下界。本地 [FlatLinearValueConstraints.cpp](/opt/llvm-project/mlir/lib/Analysis/FlatLinearValueConstraints.cpp:71)还明确记录相关 flattening 对 semi-affine 的限制。因此正文应解释常量除数的约束编码和半仿射的边界，而不是把它描述为尚无依据的结论。本次没有开展论文穷尽性检索，也不声称检查了所有 Presburger API 的完备性。

## TensorFlow 2.0 与 StableHLO

TensorFlow 2.0 正式版发布于 2019-09-30，默认 eager execution，并提供图执行与多种部署方式；不能把所有 TensorFlow 2.0 执行概括为“图 → StableHLO → XLA”。依据：[TensorFlow 团队发布说明](https://blog.tensorflow.org/2019/09/tensorflow-20-is-now-available.html)。

StableHLO 的项目定位是机器学习框架与编译器之间的可移植操作集；TensorFlow、JAX、PyTorch 与 XLA、IREE 属于其互通场景。依据：[OpenXLA 官方项目说明](https://openxla.org/stablehlo)。项目维护者在 2022 年 8–9 月的[MLIR-HLO 讨论 #44](https://github.com/tensorflow/mlir-hlo/issues/44)中讨论了 StableHLO 的初期互通定位与转换。这些资料支持将原文改为“TensorFlow/XLA 等体系可借助 MLIR 表示、转换和优化计算图，StableHLO 可作为框架间交换表示”，并保留具体版本与流水线配置的边界；本次不从讨论日期推断精确的首次发布时间。

## Verona 与企业贡献趋势

[Verona 项目问题 #107](https://github.com/microsoft/verona/issues/107)能确认该项目在 2020 年规划并实现过向 Verona MLIR 方言的转换。但本次取得的项目资料未能直接确认原书关于“2021 年因 MLIR 不稳定而放弃”的完整时间、负责人解释及因果关系。正文可保留原书对此事的叙述，并明确待核，不将推测改写为已证事实。

“从 2024 年起各大公司对 MLIR 框架的贡献日益减少”没有给出公司范围、贡献指标、时间窗口或数据来源。本地单一历史提交也不足以验证该趋势。应保留为原作者当时的观察并标注未核实；不能用下游项目增多推导上游贡献减少，更不能据此替作者归因于绩效压力。本次没有创建企业贡献排名或以提交邮箱推断雇主。

## 偏置加入顺序的浮点反例

清单 1-2 的结构是先做矩阵乘法再加偏置；清单 1-4/1-5 以偏置作为归约初值，清单 1-6/1-7 在循环前把偏置拷入输出。它们在实数代数下对应同一公式，浮点求值次序却可能不同。

[bias-order.py](bias-order.py)逐次舍入到 binary32：输入为 16 个 `1`；权重每列前两项为 `2^24`、`-2^24`，其余为 `0`；偏置为 `1`。对相同的顺序归约，零初值求和后加偏置得到 `1`，偏置初值归约得到 `0`。结果保存于 [bias-order.json](bias-order.json)。这表明不能无条件宣称二者逐位等价；它不声称某个 TOSA/PyTorch 后端一定采用该归约次序，也不据此认定编译器 Pass 存在错误。

在项目根目录复现：

```sh
python3 mlir/insider-compiler/issues/evidence/ch1/bias-order.py
```
