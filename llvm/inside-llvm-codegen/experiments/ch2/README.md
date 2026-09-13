# 第 2 章实验：IR、SSA 与 MLIR 块参数

要求 Python 3.12+ 和 LLVM 18.1.8 工具。第2章还使用同版本 mlir-opt / mlir-translate；第6章需要本地源码仓库包含指定提交。runner 不触发构建。

```sh
export LLVM_BUILD="${LLVM_BUILD:-/opt/llvm-project/build}"
export LLVM_SRC="${LLVM_SRC:-/opt/llvm-project}"
export BOOK_ROOT="${BOOK_ROOT:-/opt/coding/mlir-toy/llvm/inside-llvm-codegen}"
python3 "$BOOK_ROOT/experiments/ch2/runner.py"
```

默认创建临时输出目录并打印位置；`--output-dir /tmp/ch2-output` 可指定目录。未传 `--summary` 时摘要写到该目录的 `results.json`；`--summary PATH` 可单独指定摘要路径。各工具stdout/stderr和中间IR/MIR/生成文件留在输出目录。成功退出表示所有断言满足；明确的失败输入由runner核对非零退出和诊断，不能单独当成有效输入。

- `examples.c`：加法、阶乘、分支、求和、Lost Copy、有界交换、死变量；main 有15项返回值断言。
- `add.ll`：正文完整手写 IR；`machine-phi.ll`：BPF机器PHI消除的最小循环。
- `bad-*.ll`：预期失败的支配/PHI验证反例；`edge-selection.ll`：显式 select 的合法修复。
- `edge-values.mlir`：两条条件边指向同一块、携带不同块参数；经LLVM方言导出时拆边，运行两种条件。

runner 另用288种并行复制映射对照同时读取旧值的语义，并比较Lost Copy的正确/错误边放置。原始C与mem2reg输出均解释执行；机器实验开启MachineVerifier，并停在PHIElimination前后。

纯LLVM IR语义测试使用 `lli --force-interpreter -mtriple=bpfel`，不依赖BPF JIT。摘要记录工具版本、大小和修改时间；若执行中工具发生替换，runner会报错，需等构建完成后重跑。结果断言只覆盖列明的输入和性质，不把有限交叉验证当成数学证明或目标性能测试。
