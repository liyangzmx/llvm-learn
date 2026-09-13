# 第 7 章可复现实验

使用 LLVM 18.1.8 Debug/assertions 构建，要求 `clang`、`opt`、`llc`、`llvm-tblgen` 可用，llc 至少包含 BPF 和 AArch64。Python 3 运行脚本；不依赖第三方 Python 包，不需要构建 LLVM，也不会修改 LLVM 源码。

```sh
export LLVM_BUILD=${LLVM_BUILD:-/opt/llvm-project/build}
export LLVM_SRC=${LLVM_SRC:-/opt/llvm-project}
export BOOK_ROOT=/opt/coding/mlir-toy/llvm/inside-llvm-codegen
python3 "$BOOK_ROOT/experiments/ch7/runner.py"
```

默认创建临时输出目录并打印位置。`--output /absolute/path` 保留所有结果到指定目录，`--summary /absolute/path/result.json` 额外保存报告。输出包含每条命令的 stdout/stderr、完整 IR/MIR、两个实际生成的 TableGen inc 和 `results.json`。`--bpf-only` 只运行部分后端环境能支持的子集，报告会明确标成 `bpf-only`。

| 输入 | 验证内容 |
|---|---|
| `callee.c` | Clang 生成 BPF IR；调用约定、栈对象、i32 内存访问 |
| `selection.ll` | 两种 ADD 模式、v1/v3 ALU32 差异、PHI、DAG 日志中的 EntryToken 双结果 |
| `legalization.ll` | i16 signext、i128 拆分及进位、向量标量化 |
| `softfloat.ll` | BPF 对 `__divdf3` 的预期不支持诊断，返回码 1 是本项成功条件 |
| `globalisel.c` | 两个教材 C 函数经 Clang 生成并验证 IR |
| `globalisel.ll` | 固定 IR 经过 AArch64 IRTranslator、Legalizer、RegBankSelect、InstructionSelect，禁止回退 |
| `fastisel.ll` | i32/i64 加法强制 FastISel 且 `-fast-isel-abort=3` |
| LLVM 本地 TableGen 输入 | 实际生成 BPF MatcherTable 和 AArch64 FastISel emitter |
| `models.py` | ANYEXT 低位关系的有限位向量检查，以及明确假设下的 bank 成本演算 |

`results.json` 包含实际 LLVM 版本、源提交、已修改的 tracked LLVM 文件、输入哈希、命令与检查结果。报告中 `${LLVM_BUILD}/${LLVM_SRC}/${BOOK_ROOT}/${OUTPUT}` 是路径归一化占位符。完整输出仍在运行目录中；生成 matcher 的偏移及临时寄存器编号不是稳定接口。

所有 `.ll` 输入均经 verifier；成功的机器选择运行启用 `-verify-machineinstrs`。没有在 BPF/AArch64 硬件上执行输出，也不以这些检查宣称全输入语义等价或性能优越。数学示例不是完整 LLVM poison/undef 解释器，不是 RegBankSelect 搜索器。正文中的源码节选、过程示意和 MIR body 不能替代完整可解析文件。
