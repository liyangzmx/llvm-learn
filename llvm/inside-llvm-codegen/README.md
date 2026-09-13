# 《深入理解 LLVM：代码生成》原文与 LLVM 18.1.8 校订

原文来自本目录的 [PDF](pdf/inside-llvm-codegen.pdf)。书的前言、第 1 章及版本输出明确使用 **LLVM 15 / 15.0.1**；本次校订以本地 `/opt/llvm-project` 的 **LLVM 18.1.8** 为基准。

这里有两套完整章节：`origin/` 保留原文，根目录的 `inside-llvm-codegen-chN.md` 在原文基础上直接修正错误、旧 API 和代码，并保留源码依据。它们不是原书摘要。每章的 `review/` 记录逐个代码清单的处理方式，以及尚需运行确认的部分。

## 章节索引

| 章节 | 校订稿 | 原文 | 核查记录 |
| --- | --- | --- | --- |
| 1 绪论 | [第 1 章](inside-llvm-codegen-ch1.md) | [原文](origin/inside-llvm-codegen-ch1.md) | [记录](review/ch1.md) |
| 2 IR 基础知识 | [第 2 章](inside-llvm-codegen-ch2.md) | [原文](origin/inside-llvm-codegen-ch2.md) | [记录](review/ch2.md) |
| 3 数据流分析基础知识 | [第 3 章](inside-llvm-codegen-ch3.md) | [原文](origin/inside-llvm-codegen-ch3.md) | [记录](review/ch3.md) |
| 4 支配分析 | [第 4 章](inside-llvm-codegen-ch4.md) | [原文](origin/inside-llvm-codegen-ch4.md) | [记录](review/ch4.md) |
| 5 循环基本知识 | [第 5 章](inside-llvm-codegen-ch5.md) | [原文](origin/inside-llvm-codegen-ch5.md) | [记录](review/ch5.md) |
| 6 TableGen 介绍 | [第 6 章](inside-llvm-codegen-ch6.md) | [原文](origin/inside-llvm-codegen-ch6.md) | [记录](review/ch6.md) |
| 7 指令选择 | [第 7 章](inside-llvm-codegen-ch7.md) | [原文](origin/inside-llvm-codegen-ch7.md) | [记录](review/ch7.md) |
| 8 指令调度 | [第 8 章](inside-llvm-codegen-ch8.md) | [原文](origin/inside-llvm-codegen-ch8.md) | [记录](review/ch8.md) |
| 9 基于 SSA 形式的编译优化 | [第 9 章](inside-llvm-codegen-ch9.md) | [原文](origin/inside-llvm-codegen-ch9.md) | [记录](review/ch9.md) |
| 10 寄存器分配 | [第 10 章](inside-llvm-codegen-ch10.md) | [原文](origin/inside-llvm-codegen-ch10.md) | [记录](review/ch10.md) |
| 11 函数栈帧生成和非 SSA 形式的编译优化 | [第 11 章](inside-llvm-codegen-ch11.md) | [原文](origin/inside-llvm-codegen-ch11.md) | [记录](review/ch11.md) |
| 12 生成机器码 | [第 12 章](inside-llvm-codegen-ch12.md) | [原文](origin/inside-llvm-codegen-ch12.md) | [记录](review/ch12.md) |
| 13 添加一个新后端 | [第 13 章](inside-llvm-codegen-ch13.md) | [原文](origin/inside-llvm-codegen-ch13.md) | [记录](review/ch13.md) |
| A LLVM 的中间表示 | [附录 A](inside-llvm-codegen-appendix-a.md) | [原文](origin/inside-llvm-codegen-appendix-a.md) | [记录](review/appendix-a.md) |
| B BPF 介绍 | [附录 B](inside-llvm-codegen-appendix-b.md) | [原文](origin/inside-llvm-codegen-appendix-b.md) | [记录](review/appendix-b.md) |
| C Pass 的分类与管理 | [附录 C](inside-llvm-codegen-appendix-c.md) | [原文](origin/inside-llvm-codegen-appendix-c.md) | [记录](review/appendix-c.md) |

前言、目录、两部分导言、附录扉页和书后材料也保存在 [原文目录](origin/README.md)。PDF 的全部 435 页均有归属，正文印刷页码与 PDF 页码相差 13。

## 校订方法与范围

- 使用三个 subagent 分工校对章节，并复核交叉章节中重复出现的 IR、调度与寄存器分配概念；根任务负责原文恢复、附录、汇总和完整性检查。
- 核对源码提交：`3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`，标签 `llvmorg-18.1.8`。本地已有 7 个 BPF 文件修改，相关定义同时读取该提交的原版；没有改动 LLVM 工作树。详见 [基线及文件校验值](review/source-baseline.json)。
- `review/` 中的源码路径/行号用于定位核查依据；受本地修改影响的文件，旧行号应结合 `git show HEAD:路径` 阅读，不应把用户的本地改动当成上游版本差异。
- 直接修正文中的错误；历史调试输出、生成文件数值编号和性能数据明确保留为历史记录。省略上下文的片段、通用伪代码、完整 IR 和工具输出分别说明用途。
- 图表、公式和特殊字体以原 PDF 为可追溯底稿；影响结论的错误图在正文中给出修正说明或 Mermaid。原图自身未改写，不能把历史原图当成 LLVM 18 的新执行结果。

主要修正涉及 opaque pointer、Phi 取值及并行复制、数据流方程、支配与循环条件、TableGen 参数、`nsw` 语义、调度队列及公式、寄存器分配与溢出策略、MC 与目标文件的区别，以及 PassManager 的继承关系和接口。

**本轮没有构建 LLVM，没有执行 Clang/opt/llc、LLVM IR/MIR、TableGen 或 BPF 示例。** 数据流集合等少量数学例子用独立 Python 运算复核。后续需固定 triple、CPU/features、优化等级和 Pass 停止点，再验证 IR 的解析、生成结果和程序行为；各章末尾已经列出具体待验证项。旧实验数据及线上工具界面未重新复现。

## 原文转换与检查

PDF 大部分页面含文字层；PDF 第 20、21、120、134、137、224、239 页没有完整文字层，已经读图补录正文、代码续页或图节点，恢复稿保存在 `tools/page-transcriptions/`。

`origin/source-layout.txt` 是 Poppler 的原始全文文本提取；`origin/manifest.json` 记录原 PDF 的 SHA-256、页码归属、代码区域和人工补录页。`origin/assets/figures/` 保存原图裁剪，完整版面直接查阅原 PDF。Markdown 保留页码标记，转换脚本仅在内存中临时渲染页面以裁取图形，不保存整页图片。

转换工具不依赖 LLVM 构建。以下命令需有 `pdfplumber`、`pypdfium2`、Pillow 和 Poppler；请使用有这些依赖的 Python：

```sh
# 重新生成 origin 的文本、原图裁剪及恢复稿；不会改写校订稿。
python3 tools/extract_book.py

# 核对页码覆盖、章节/清单标识、本地链接、图片与 Markdown 围栏。
python3 tools/check_book.py
```

结构检查结果见 [validation.json](review/validation.json)。这类检查证明文件完整性，不等于 LLVM IR 通过 verifier 或程序运行正确。
