# 第 5 章实验：循环识别与规范化

要求 Python 3.12+ 和 LLVM 18.1.8 工具。第2章还使用同版本 mlir-opt / mlir-translate；第6章需要本地源码仓库包含指定提交。runner 不触发构建。

```sh
export LLVM_BUILD="${LLVM_BUILD:-/opt/llvm-project/build}"
export LLVM_SRC="${LLVM_SRC:-/opt/llvm-project}"
export BOOK_ROOT="${BOOK_ROOT:-/opt/coding/mlir-toy/llvm/inside-llvm-codegen}"
python3 "$BOOK_ROOT/experiments/ch5/runner.py"
```

默认创建临时输出目录并打印位置；`--output-dir /tmp/ch5-output` 可指定目录。未传 `--summary` 时摘要写到该目录的 `results.json`；`--summary PATH` 可单独指定摘要路径。各工具stdout/stderr和中间IR/MIR/生成文件留在输出目录。成功退出表示所有断言满足；明确的失败输入由runner核对非零退出和诊断，不能单独当成有效输入。

- `multi-latch.ll`：两入口、两回边、非专用出口，经LoopSimplify检查三项结构性质与四个运行条件。
- `book-loop.c`：正文清单5-1，验证LoopRotate的入口guard、latch退出与dedicated exit。
- `lcssa.ll`：正文清单5-2及三个调用，验证新出口PHI和零/一/多次迭代。
- `nested.ll` / `irreducible.ll`：区分嵌套自然循环与LoopInfo未表示的不可归约环。

结构判断从CFG/支配关系导出，不仅匹配块名；开启IR、LoopInfo、DomTree验证。所有数值测试使用有界输入，未越过C有符号整数范围。

纯LLVM IR语义测试使用 `lli --force-interpreter -mtriple=bpfel`，不依赖BPF JIT。摘要记录工具版本、大小和修改时间；若执行中工具发生替换，runner会报错，需等构建完成后重跑。结果断言只覆盖列明的输入和性质，不把有限交叉验证当成数学证明或目标性能测试。
