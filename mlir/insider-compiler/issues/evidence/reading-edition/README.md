# 校订读本：正文修正与原稿差异

按用户明确的原则，逐章 Markdown 直接提供修正后的内容；`issues/` 保存与原稿的差异及核对依据，原始 OCR 不要求回写。此次按章由 subagent 检查仍保留已知错误的情形，只修改以下四处相关正文。

| 正文 | 调整 | 原稿差异与核验 |
| --- | --- | --- |
| [第1章](../../../insider-compiler-ch1.md) | 清单1-4～1-7改为零初始化矩阵乘归约，完成后再加偏置；同步注释与解释 | [差异](../../ch1.md#ch1-numerics)、[新版代码验证](ch1/README.md) |
| [第10章](../../../insider-compiler-ch10.md) | 直接写出正乘数范围折叠应同时修改下界、上界和步长，本例正确索引为2、4、6 | [原警告与本地错误输出](../../ch10.md#ch10-range-folding) |
| [第15章](../../../insider-compiler-ch15.md) | 保留原不等式规范化，补全整除替换、整数界限和消去存在量词的最终条件 | [原稿未完成的推导](../../ch15.md#ch15-presburger)、[9409组整数核对](example-checks.json) |
| [附录](../../../insider-compiler-appendix.md) | A-1采用本地LLVM18已验证的完整DLTI模块；正文继续解释较新属性的概念及版本范围 | [原较新清单与差异](../../appendix.md#appendix-dlti-original)、[输入一致性检查](example-checks.json) |

第2～6、7～13及14章的有界审查未发现其他必须按本原则改写的明确错例。正确的伪代码、已注明上下文的片段、中间IR状态和较新版本的概念介绍仍有教学作用；没有为了让所有片段独立运行而另行重写整书。

## 当前验证

- 第1章新版四份清单通过本地 parser/verifier；实际执行Linalg/Affine降级、LLVM导出、LLVM verifier与llvm-as，以及宿主Clang编译运行。80组输入、800个输出逐位匹配先归约再加偏置的f32参考，其中39个输出与历史bias-first参考不同。完整参数是明确选定的验证数据，没有声称恢复原书截断的参数，也没有执行PyTorch前端或重建原向量化节选。
- 第15章新增推导对任意整数参数的等价性由正文代数步骤给出；[check_examples.py](check_examples.py)另外在w、z各为−48～48时枚举原不等式限定的全部候选y，核对9409组参数。有限核对用于发现转写错误，不替代一般证明。
- 附录正文A-1逐字等于此前已通过本地解析验证的[dlti-18.mlir](../appendix/dlti-18.mlir)，未重复执行相同工具检查。
- 第15章486个公式已用KaTeX 0.16.22重新渲染，均通过；实际目视检查新增整数界限与最终取整公式。第14章及附录61个公式按各自内容哈希复用原有通过结果，合计[547个当前公式](math-validation.json)。渲染检查与数学正确性分别记录。
- 本次未改Mermaid图代码；[全书63图记录](../mermaid-validation.json)逐图校验代码哈希，并更新当前正文哈希。页标、编号、脚注及链接由全书[结构检查](../../validation.json)确认。

## 历史内容与保留范围

[before-sha256.json](before-sha256.json)是此次调整开始前的859项正文/OCR哈希基线；[preservation-check.json](preservation-check.json)记录实际变化范围与保持不变的文件。[第10章旧正文](before-insider-compiler-ch10.md.txt)、[第15章旧正文](before-insider-compiler-ch15.md.txt)与[附录旧正文](before-insider-compiler-appendix.md.txt)以文本存档，保留原字节与原相对链接；第1章旧节选及原清单见[本章差异](ch1/README.md)。这些旧文本用于追溯，日常阅读使用上方校订正文。

第14章至书末扫描处理批次的749项保留记录、第1章补录批次的719项保留记录，以及旧bias-first代码的运行产物，均是各自完成时的历史快照。当前正文的检查结果单独保存在本目录；没有把旧哈希或旧数值结果冒充当前结果。

在仓库根目录核对新增数学示例与DLTI输入：

```sh
python3 mlir/insider-compiler/issues/evidence/reading-edition/check_examples.py
```

新版第1章复现命令见[本章README](ch1/README.md)。本次检查不改变本地LLVM源码或原始OCR。
