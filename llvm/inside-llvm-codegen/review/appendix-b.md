# 附录 B 核查记录

LLVM 18.1.8 静态核查；未构建、未运行示例。

| 清单/位置 | 核查依据 | 结论与修正 |
| --- | --- | --- |
| B.1/B.1.1/表B-1 | LLVM BPFInstrFormats.td（HEAD）；Linux ISA官方文档 | 基本64位和宽128位区分；8种class编码保留，具体指令能力取决于CPU/features |
| B.1.2 | BPFISelLowering.cpp:402,436；BPFRegisterInfo.cpp:43 | 参数超限报错，非自动走栈；R10只读；LLVM伪寄存器与ISA区分 |
| B.2 | Linux 6.6 verifier/kfunc官方文档 | verifier为静态抽象分析；不是绝对安全保证；helper之外可有kfunc/BPF子程序 |
| 示例代码 | 本附录无编号代码清单 | 只做流程/概念校对，不运行Linux程序 |

待后续：实际 IR/工具命令输出；BPF 内核加载与运行需要单独的 Linux 环境验证。
