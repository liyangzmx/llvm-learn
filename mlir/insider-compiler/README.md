# 扫描件转写与校订

本目录按扫描件中的实际章节组织内容。原始识别结果保存在 [ocr/](ocr/README.md)，校订正文为逐章 Markdown，技术修正和版本差异保存在 [issues/](issues/README.md)。

Git 保存校订正文、配套图示、差异记录和验证工具。源 PDF、逐页 OCR 文本／JSON、合并文本及渲染缓存仅保存在本地，并由 `.gitignore` 排除；`ocr/` 中只跟踪说明文件和用于页码、来源哈希核对的 `manifest.json`。复现 OCR 时需自行在本地准备对应扫描件。

第 1～15 章、第二至第四部分导读及附录共 **416 个不重复扫描页**，已完成转写和校订，保留 **275 个编号代码清单、64 个编号图、33 个编号表及 88 条原书脚注**。图示包括 **63 个 Mermaid 代码块**（含第二部分未编号概览图）与 **2 幅按坐标重绘的几何图**；第二部分另保留原始关系图，见[验收记录](issues/review-summary.md)。

最后一份 `insider-compiler-ch14-end.pdf` 包含第四部分导读、第 14 章、第 15 章与附录，共 52 页。用户已确认这就是整书最后的扫描内容。处理这份最后扫描件的批次没有修改此前第 1～13 章、第二／第三部分导读正文及原始 OCR，[749 项哈希检查](issues/evidence/ch14-end/preservation-check.json)可追溯。第 1 章此前的来源替换历史仍保留于[文件核验记录](issues/source-files.md)。随后按“Markdown 为主要校订读本”的原则，有针对性地修正第 1、10、15 章及附录，见[本次差异与检查](issues/evidence/reading-edition/README.md)。

| 章节 | 校订正文 | 来源 PDF | PDF 页码 | 原书页码 | 校订记录 |
| --- | --- | --- | --- | --- | --- |
| 1 绪论 | [第 1 章](insider-compiler-ch1.md) | `insider-compiler-ch1.pdf` | 1–14 | 2（推定）–15 | [ch1](issues/ch1.md) |
| 2 MLIR 概述 | [第 2 章](insider-compiler-ch2.md) | `insider-compiler-ch2-ch3.pdf` | 1–9 | 16–24 | [ch2](issues/ch2.md) |
| 3 类型、属性、操作和方言详解 | [第 3 章](insider-compiler-ch3.md) | 同上 | 10–50 | 25–65 | [ch3](issues/ch3.md) |
| 4 谓词、特质和接口 | [第 4 章](insider-compiler-ch4.md) | `insider-compiler-ch4.pdf` | 1–25 | 66–90 | [ch4](issues/ch4.md) |
| 5 Pass 系统的工作流程 | [第 5 章](insider-compiler-ch5.md) | `insider-compiler-ch5-ch6.pdf` | 1–16 | 91–106 | [ch5](issues/ch5.md) |
| 6 操作匹配与重写机制 | [第 6 章](insider-compiler-ch6.md) | 同上 | 17–37 | 107–127 | [ch6](issues/ch6.md) |
| 7 MLIR 中常见的通用优化技术 | [第 7 章](insider-compiler-ch7.md) | `insider-compiler-ch7-ch10.pdf` | 1–17 | 128–144 | [ch7](issues/ch7.md) |
| 第二部分 MLIR 方言详解 | [扉页与导读](insider-compiler-part2.md) | 同上 | 18–20 | 145（推定）–147 | [part2](issues/part2.md) |
| 8 业务接入方言 | [第 8 章](insider-compiler-ch8.md) | 同上 | 21–26 | 148–153 | [ch8](issues/ch8.md) |
| 9 优化方言 | [第 9 章](insider-compiler-ch9.md) | 同上 | 27–80 | 154–207 | [ch9](issues/ch9.md) |
| 10 结构方言与数据方言 | [第 10 章](insider-compiler-ch10.md) | 同上 | 81–108 | 208–235 | [ch10](issues/ch10.md) |
| 11 目标输出方言 | [第 11 章](insider-compiler-ch11.md) | `insider-compiler-ch11-ch13.pdf` | 1–31 | 236（推定）–266 | [ch11](issues/ch11.md) |
| 12 元编程方言 | [第 12 章](insider-compiler-ch12.md) | 同上 | 32–48 | 267（推定）–283 | [ch12](issues/ch12.md) |
| 第三部分 MLIR 实战项目剖析 | [扉页与导读](insider-compiler-part3.md) | 同上 | 49 | 285（推定） | [part3](issues/part3.md) |
| 13 Triton DSL 的设计与编译优化 | [第 13 章](insider-compiler-ch13.md) | 同上 | 50–130 | 286（推定）–366 | [ch13](issues/ch13.md) |
| 第四部分 MLIR 中的数学知识与应用 | [扉页与导读](insider-compiler-part4.md) | `insider-compiler-ch14-end.pdf` | 1 | 367（推定） | [part4](issues/part4.md) |
| 14 多面体编译理论概述 | [第 14 章](insider-compiler-ch14.md) | 同上 | 2–25 | 368（推定）–391 | [ch14](issues/ch14.md) |
| 15 整数规划求解方法 | [第 15 章](insider-compiler-ch15.md) | 同上 | 26–48 | 392（推定）–414 | [ch15](issues/ch15.md) |
| 附录 其他方言 | [附录](insider-compiler-appendix.md) | 同上 | 49–52 | 415（推定）–418 | [appendix](issues/appendix.md) |

## 阅读方式

- **逐章 Markdown 是主要阅读的校订版。** 已确认的识别错误、概念错误、公式错误和代码错误直接在正文中修正；正文应独立给出正确结论、示例和必要前提，读者无需再到 `issues/` 拼合正确答案。
- 保留原书的章节结构、主题、清单与图表编号，完整呈现各节内容；具体表述和示例以校订后的正确性为准。需要替换错误示例时，正文采用修正版，原稿对应内容存入差异记录。
- **`issues/` 用于追溯与原稿的差异。** 其中保存原说法、修正理由、源码依据、验证范围和版本差异，供后续核对；不能只在这里指出错误而让正文继续沿用。正文仅保留理解内容所必需的版本、适用条件和简短提示。
- `<!-- source: ..., PDF p. N -->` 注释标示扫描来源页。跨页代码可能分为同一清单的两个连续片段；原书已有的省略号和依赖外部定义的示意代码会明确标注。
- 可用结构图表达的图示采用 Mermaid；图示的细节以目视扫描页及源码核验为依据。几何图提供 SVG 与 PNG；阅读器需要支持 Mermaid、LaTeX 数学公式和 Markdown 表格、脚注。
- **`ocr/` 是原始识别存档。** 识别错误可以保留，不要求逐项修正或回写；它用于追溯扫描来源，不作为阅读结论的依据。
- OCR 不可靠地保留粗体。章节层次和影响理解的强调在校订阶段恢复；按用户要求，后续优先检查文字稀少的图页、公式及识别异常代码，不要求逐处恢复非关键字体样式。

## 版本与复现

校订基准是 `/opt/llvm-project` 中的 **LLVM 18.1.8**，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。本地 `mlir-opt` 与 `mlir-tblgen` 同样报告 18.1.8。原书参考 LLVM 20；与本地实现不一致不必然代表原书当时有误，版本差异与确定的内容错误分别说明。

第 13 章另以原书指定的 Triton 提交 `47fc046ff29c9ea2ee90e987c39628a540603c8f` 核对项目实现，其锁定的 LLVM 提交与本地不同，见[源码来源](issues/evidence/triton-source.md)。本地源码不足以确认的硬件语义，补查 Arm、NVIDIA 官方资料并在问题记录中列出依据。

识别程序和合并、检查脚本在 [tools/](tools/vision_ocr.swift)。[OCR 说明](ocr/README.md)提供识别命令；[证据说明](issues/evidence/README.md)提供可重复执行的布局与重写检查。各章记录分别说明哪些例子实际运行、哪些仅作语法或源码核验。

```sh
python3 mlir/insider-compiler/tools/assemble_ocr.py
python3 mlir/insider-compiler/tools/check_markdown.py
```

第一条需要本地 PDF 与逐页 OCR，验证原始 TXT 与 JSON 一致、核验源文件和逐页文本哈希并生成合并文本；第二条根据保留的来源清单检查页面归属，以及正文页码覆盖、代码与图表编号、表格列宽、脚注引用、代码围栏与本地链接及锚点。结构检查不能替代图像核对或源码校订。
