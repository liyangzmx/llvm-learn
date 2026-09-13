# 源扫描件与版本基准

## 第 1 章扫描件已补齐，旧重复文件关系保留追溯

用户于 2026-09-13 更新 `pdf/insider-compiler-ch1.pdf`，现为《第 1 章 绪论》，14 页、12,543,816 字节，SHA-256 为：

```text
40e24cbf10d5f9303bdcfe8ca43dd7305105900c04a844e3dfd3baf1c7ff227c
```

PDF 第 2～14 页的印刷书页为 3～15，章首页未印页码，因此书页 2 为推定值。全部 14 页已保存独立的 Apple Vision OCR，并转写为[第 1 章正文](../insider-compiler-ch1.md)。这份扫描件中没有独立的第一部分扉页，不能由此推断章内正文缺失。

**此前的文件问题：**旧 `pdf/insider-compiler-ch1.pdf` 和 `pdf/insider-compiler-ch2-ch3.pdf` 大小均为 40,866,071 字节、50 页，SHA-256 均为：

```text
4951c568a1ff637c6e05dfde1b50b9a24e35aece1d8d63aaa8a0621159dc7661
```

旧文件中 PDF 第 1～9 页是第 2 章，第 10～50 页是第 3 章。旧内容继续完整保存在 `insider-compiler-ch2-ch3.pdf` 及对应 OCR 中；[替换前 manifest](evidence/ch1/manifest-before-ch1.json)保留原始映射。新 manifest 记录了这次明确授权的源文件替换，不将其误报成旧 OCR 被修改。[保留检查](evidence/ch1/preservation-check.json)核对本轮开始前的 719 项正文及 OCR 文件哈希。

## 新增第 7–10 章合订扫描件

`insider-compiler-ch7-ch10.pdf` 为 108 页、81,457,697 字节的无文本层扫描件，SHA-256 为：

```text
6eacb37393316badda018ac814bf7c535f93e87701ded7a2eb76f46f5db64c2c
```

| 内容 | PDF 页码 | 原书页码 |
| --- | --- | --- |
| 第 7 章 MLIR 中常见的通用优化技术 | 1–17 | 128–144 |
| 第二部分 MLIR 方言详解：扉页与导读 | 18–20 | 145（推定）–147 |
| 第 8 章 业务接入方言 | 21–26 | 148–153 |
| 第 9 章 优化方言 | 27–80 | 154–207 |
| 第 10 章 结构方言与数据方言 | 81–108 | 208–235 |

第 18 页没有印刷页码，145 由前后页序推定。该合订文件没有第 1 章，第 11、12 章后来随下一份合订文件补入，第 1 章后来单独补齐。

## 新增第 11–13 章合订扫描件

`insider-compiler-ch11-ch13.pdf` 为 130 页、112,274,409 字节的无文本层扫描件，SHA-256 为：

```text
a9d59cbec6dafbb95b1352f96cdca56d327c09ffc3bdb62f9e63089325082458
```

| 内容 | PDF 页码 | 原书页码 |
| --- | --- | --- |
| 第 11 章 目标输出方言 | 1–31 | 236（推定）–266 |
| 第 12 章 元编程方言 | 32–48 | 267（推定）–283 |
| 第三部分 MLIR 实战项目剖析：扉页与导读 | 49 | 285（推定） |
| 第 13 章 Triton DSL 的设计与编译优化 | 50–130 | 286（推定）–366 |

章节首页与第三部分扉页未印页码，按相邻印刷页序推定。PDF 第 48 页印有 283，第 51 页印有 287；向前推定第 50 页为 286、第 49 页为 285。在这一推定下，原书 284 页没有对应扫描页，不能仅凭此确认它是空白页或正文缺页。没有补造该页内容，实际提供的 130 页均保存 OCR。

第 1 章替换完成时，六个文件共 364 个源文件页，均为不同扫描页。替换前曾为 400 个源文件页、350 个不同扫描页；新文件补入 14 个独立页，同时替换了旧重复文件的 50 页。第 13 章涉及外部 Triton 项目，其实际源码已按扉页指定提交获取，见 [Triton 来源记录](evidence/triton-source.md)。本地 LLVM 源码不能代替该项目自身的版本依据。

## 第 14 章至书末合订扫描件

`insider-compiler-ch14-end.pdf` 为 52 页、41,356,173 字节的扫描件，SHA-256 为：

```text
fc51b66bce20a574106efca042b7e1a15b816e3ad75a0db875bcd4fe1e309faa
```

| 内容 | PDF 页码 | 原书页码 |
| --- | --- | --- |
| 第四部分 MLIR 中的数学知识与应用：扉页与导读 | 1 | 367（推定） |
| 第 14 章 多面体编译理论概述 | 2–25 | 368（推定）–391 |
| 第 15 章 整数规划求解方法 | 26–48 | 392（推定）–414 |
| 附录 其他方言 | 49–52 | 415（推定）–418 |

扉页与各章／附录首页未印书页码，按后续相邻印刷页码推定。用户确认这是整书剩余内容，当前 **7 份 PDF 共 416 页**均有原始 OCR 与明确的正文归属，最后一页为附录 Quant 方言与结束语。没有再把附录列为未提供内容。

本轮只新增第 14、15 章、第四部分导读与附录的正文及校订材料，并更新共同目录和检查工具。此前 15 份章节／导读 Markdown、6 份合并 OCR、728 份逐页 TXT／JSON 共 749 项的原哈希已保留在[本轮基线](evidence/ch14-end/preexisting-content-sha256.json)，最终结果见[保留检查](evidence/ch14-end/preservation-check.json)。此前来源映射见[新增前 manifest](evidence/ch14-end/manifest-before-ch14-end.json)。

## LLVM 校订基准

- 本地源码：`/opt/llvm-project`。
- Git HEAD：`3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。
- [`llvm/CMakeLists.txt`](/opt/llvm-project/llvm/CMakeLists.txt:18) 定义版本为 **18.1.8**，本次采用这个实际检出的版本作为基准。
- `/opt/llvm-project/build/bin/mlir-opt --version` 同样报告 LLVM 18.1.8、DEBUG build with assertions。
- 校订开始时 `mlir/` 与 `llvm/CMakeLists.txt` 没有工作树修改；没有修改本地 LLVM 源码。

原书参考 LLVM 20。正文以当前本地实现为准；明显排印/OCR 错误直接修正；原书概念错误与版本差异在各章 `issues/chN.md` 中区别记录。未核对 LLVM 20 对应版本源码的差异，仅称为“与本地 18.1.8 不一致”，不推断该 API 在 20 中一定正确或错误。
