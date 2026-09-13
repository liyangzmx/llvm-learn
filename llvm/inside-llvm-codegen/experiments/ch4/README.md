# 第 4 章实验：支配、边界与循环图

要求 Python 3.12+ 和 LLVM 18.1.8 工具。第2章还使用同版本 mlir-opt / mlir-translate；第6章需要本地源码仓库包含指定提交。runner 不触发构建。

```sh
export LLVM_BUILD="${LLVM_BUILD:-/opt/llvm-project/build}"
export LLVM_SRC="${LLVM_SRC:-/opt/llvm-project}"
export BOOK_ROOT="${BOOK_ROOT:-/opt/coding/mlir-toy/llvm/inside-llvm-codegen}"
python3 "$BOOK_ROOT/experiments/ch4/runner.py"
```

默认创建临时输出目录并打印位置；`--output-dir /tmp/ch4-output` 可指定目录。未传 `--summary` 时摘要写到该目录的 `results.json`；`--summary PATH` 可单独指定摘要路径。各工具stdout/stderr和中间IR/MIR/生成文件留在输出目录。成功退出表示所有断言满足；明确的失败输入由runner核对非零退出和诊断，不能单独当成有效输入。

- `graph7.ll`：表4-1七节点CFG，解析LLVM的idom和DF输出逐项比较。
- `join-loop.ll`：mem2reg在分支汇聚和循环头放PHI，展示IDF。
- `postdom-roots.ll`：两个返回出口和一个无限自环，检查LLVM PDT的虚拟根。

runner穷举4096个四节点图，筛出2432个全部入口可达图，对比删点可达性、集合不动点、定义式半支配+NCA，以及DF定义/DJ扫描。另有完整六节点semi!=idom反例和插边后的重新计算。它不冒充LLVM优化过的link/eval或增量API实现。

本章不执行目标程序；只验证上面列出的分析或生成结果。摘要记录工具版本、大小和修改时间；若执行中工具发生替换，runner会报错，需等构建完成后重跑。结果断言只覆盖列明的输入和性质，不把有限交叉验证当成数学证明或目标性能测试。
