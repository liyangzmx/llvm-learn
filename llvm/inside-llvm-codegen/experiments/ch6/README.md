# 第 6 章实验：TableGen 语言与 BPF 生成器

要求 Python 3.12+ 和 LLVM 18.1.8 工具。第2章还使用同版本 mlir-opt / mlir-translate；第6章需要本地源码仓库包含指定提交。runner 不触发构建。

```sh
export LLVM_BUILD="${LLVM_BUILD:-/opt/llvm-project/build}"
export LLVM_SRC="${LLVM_SRC:-/opt/llvm-project}"
export BOOK_ROOT="${BOOK_ROOT:-/opt/coding/mlir-toy/llvm/inside-llvm-codegen}"
python3 "$BOOK_ROOT/experiments/ch6/runner.py"
```

默认创建临时输出目录并打印位置；`--output-dir /tmp/ch6-output` 可指定目录。未传 `--summary` 时摘要写到该目录的 `results.json`；`--summary PATH` 可单独指定摘要路径。各工具stdout/stderr和中间IR/MIR/生成文件留在输出目录。成功退出表示所有断言满足；明确的失败输入由runner核对非零退出和诊断，不能单独当成有效输入。

- `language.td`：整数、位赋值、列表切片、字符串、嵌套dag、multiclass/defm。
- `records.td`：普通def、class继承和保留未赋位的局部编码。
- `bad-field.td` / `bad-bits.td`：未知字段和重复位赋值，预期诊断失败。

BPF完整输入经git archive从固定LLVM18.1.8提交导出，保存于输出目录llvm18-source。生成JSON、BPFGenDAGISel.inc、BPFGenInstrInfo.inc、BPFGenMCCodeEmitter.inc。另对当前工作树执行三个生成后端并记录逐字节比较和SHA-256；不会修改LLVM源文件。匿名记录编号和MatcherTable偏移不当作稳定接口。

本章不执行目标程序；只验证上面列出的分析或生成结果。摘要记录工具版本、大小和修改时间；若执行中工具发生替换，runner会报错，需等构建完成后重跑。结果断言只覆盖列明的输入和性质，不把有限交叉验证当成数学证明或目标性能测试。
