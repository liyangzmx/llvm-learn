# LLVM 18.1.8 代码生成：教材、源码与可复现实验

本教材以本地 `/opt/llvm-project` 的 **LLVM 18.1.8** 为准，围绕原书的 13 章主题重新核对和编写。关键结论由源码、完整实验输入和实际运行结果支持；原书 LLVM 15 的历史内容单独保存在 [origin](origin/README.md)，源文件为 [原 PDF](pdf/inside-llvm-codegen.pdf)。

先读 [第 1 章](inside-llvm-codegen-ch1.md) 设置环境，再阅读各章。`experiments/chN/` 提供完整输入和 runner；`review/experiments-chN.json` 保存检查条件与结果；各章的 `review/chN.md` 记录依据和适用范围。附录主要保留前一轮静态校订内容，正文的新实验结论以各章报告为准。

正文代码中的中文注释用于辅助阅读，重点解释数据流、约束和操作目的。LLVM IR 和 MIR 的机器指令 body 使用 `;` 注释，C/C++、MLIR 和 TableGen 使用 `//`，Shell 和 Python 使用 `#`。带阅读注释的输出节选会在附近说明；实际工具输出保存在实验目录中。第一次阅读可先看注释，再对照相邻的输入、输出和验证说明。

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

## 当前基线与构建

- 原书基线为 LLVM 15 / 15.0.1，本地源码提交为 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`，标签 `llvmorg-18.1.8`。
- 初版原文转换、静态校订及移除整页图片后的成果已在开始实验前提交，提交号为 `c5924c6`。
- 沿用 `/opt/llvm-project/build` 的 Ninja、Debug、断言及 `clang;mlir;clang-tools-extra` 配置。为章节实验补齐 BPF、AArch64（Native）、X86、RISCV、Hexagon、PowerPC、ARM，并修复空的默认 target triple。完整配置及按需构建命令见第 1 章，实际配置和构建记录见 [build.json](review/build.json)。
- 现有 BPF 工作树中未定义的 `XOR5W32` 已恢复为对应的 `XORW32`，仅此一处构建修复，见 [补丁](review/build-source-fix.patch)。其他用户源码改动保留。初版校验值见 [历史源码基线](review/source-baseline.json)，当前环境与工具 SHA-256 见 [environment.json](review/environment.json)。

## 运行实验

各章正文已按知识点提供手工复现命令。使用 Bash，先执行该章的环境设置，再按正文顺序操作；`BOOK_INPUT` 指向已提交输入，`CODEGEN_LAB` 是本次临时输出目录。命令需要 LLVM 工具、Python 3，以及用于查找输出的 `rg`（ripgrep）；预期失败的输入会显式检查诊断，不应当作正例使用。

从本仓库运行下列命令；各章输入和工具路径均可定位，不依赖下载实验文件：

```sh
export LLVM_SRC=/opt/llvm-project
export LLVM_BUILD=/opt/llvm-project/build
export BOOK_ROOT=/opt/coding/mlir-toy/llvm/inside-llvm-codegen

# 运行全部 13 章，日志和中间产物默认放入新的临时目录。
python3 "$BOOK_ROOT/tools/run_experiments.py"

# 修改某章输入或工具后，只重跑有关章节。
python3 "$BOOK_ROOT/tools/run_experiments.py" --chapters 2 7 10

# 直接执行正文里的手工实验命令，检查路径、准备步骤和执行顺序。
# 使用已有 LLVM 构建，不重新执行第 1 章的 CMake 配置/构建。
python3 "$BOOK_ROOT/tools/check_manual_commands.py"
```

统一 runner 为所有章节设置相同工具环境，保存完整日志的目录位置，并在运行前后核对工具和实验输入的 SHA-256，检查运行中是否发生变化。结果汇总见 [experiments-summary.json](review/experiments-summary.json)。各章 runner 也可以独立运行，其参数见 `--help`。

正文命令的独立执行结果见 [manual-commands.json](review/manual-commands.json)，其中记录代码块位置、SHA-256、退出码和日志路径。章节 runner 仍保留完整断言；正文则就近说明要观察哪个文件、哪些变化才支持当前结论。

当前保存的完整验收结果：**13/13 章实验通过**，14 个工具及 96 个实验文件在运行前后未变化；补入正文的 **108 个手工命令块按章顺序执行，13/13 章通过**；正文 **18/18 个完整 LLVM IR 代码块**通过解析与 verifier。文档结构检查覆盖 435 页原文归属、62 份 Markdown、760 个本地链接及 211 张被引用的图片，错误和警告均为 0。这些数字对应本次输入与环境，不表示已穷尽所有程序或目标配置。

实验按问题选择不同证据：IR parser/verifier、MachineVerifier、Pass 前后结构、数学模型交叉验证、TableGen 生成、对象字节/重定位、IR 解释执行或本机 JIT。跨目标编译不等于已在该目标机器上运行；本地 BPF 对象没有被装载到 Linux 内核，模型中的调度周期和指令计数也不等于真实硬件性能。具体限制随对应实验写在正文中。

正文保留原章节主题，但不再保留无法重现的旧数字作为 LLVM 18 的结论。简化模型、接口片段和可独立执行文件分别说明，关键例子使用本次输入与实际观察；不以生成工具退出成功代替程序语义证明。

## 原文与文档检查

原 PDF 的全部 435 页按章节和前后材料归档。`origin/source-layout.txt` 保存 Poppler 原始文字层提取，`origin/manifest.json` 记录 PDF 的 SHA-256、页码和补录页。PDF 第 20、21、120、134、137、224、239 页的缺失文字层已人工补录，恢复稿位于 `tools/page-transcriptions/`。

`origin/assets/figures/` 保留原图裁剪，完整版面直接查阅 PDF。转换脚本仅在内存中临时渲染页面，不保存整页图片；没有恢复已删除的页图目录。

```sh
# 需 pdfplumber、pypdfium2、Pillow 和 Poppler；只重新生成原文。
python3 "$BOOK_ROOT/tools/extract_book.py"

# 需 Pillow；检查页码、章节/清单标识、本地链接、图片和 Markdown 围栏。
python3 "$BOOK_ROOT/tools/check_book.py"

# 使用同一 LLVM 构建，解析并验证正文中 llvm/llvm-ir 围栏的完整输入。
python3 "$BOOK_ROOT/tools/check_ir_snippets.py"
```

文档结构结果见 [validation.json](review/validation.json)，正文完整 IR 的解析与验证记录见 [ir-snippets.json](review/ir-snippets.json)。这些检查与章节运行实验分别记录；解析通过不表示已经执行程序或证明优化等价。
