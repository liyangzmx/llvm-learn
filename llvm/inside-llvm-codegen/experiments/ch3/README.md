# 第 3 章实验：格与数据流方程

要求 Python 3.12+ 和 LLVM 18.1.8 工具。第2章还使用同版本 mlir-opt / mlir-translate；第6章需要本地源码仓库包含指定提交。runner 不触发构建。

```sh
export LLVM_BUILD="${LLVM_BUILD:-/opt/llvm-project/build}"
export LLVM_SRC="${LLVM_SRC:-/opt/llvm-project}"
export BOOK_ROOT="${BOOK_ROOT:-/opt/coding/mlir-toy/llvm/inside-llvm-codegen}"
python3 "$BOOK_ROOT/experiments/ch3/runner.py"
```

默认创建临时输出目录并打印位置；`--output-dir /tmp/ch3-output` 可指定目录。未传 `--summary` 时摘要写到该目录的 `results.json`；`--summary PATH` 可单独指定摘要路径。各工具stdout/stderr和中间IR/MIR/生成文件留在输出目录。成功退出表示所有断言满足；明确的失败输入由runner核对非零退出和诊断，不能单独当成有效输入。

- `constant.c`：平方条件、常量循环和相关分支；main 检查返回0/11/5/5。
- runner 内完整记录表3-3活跃性、表3-4到达定值和表3-5密集常量传播的CFG、语句与转移。

四元素幂集格共有256个自映射，筛出的36个单调映射以枚举不动点交叉验证极值迭代。活跃性与到达定值各有独立路径搜索参考。SCCP采用明确的mem2reg,sccp,simplifycfg流水线；它删除i++但不直接折叠出口ret11。有限实验不代替一般数学证明。

纯LLVM IR语义测试使用 `lli --force-interpreter -mtriple=bpfel`，不依赖BPF JIT。摘要记录工具版本、大小和修改时间；若执行中工具发生替换，runner会报错，需等构建完成后重跑。结果断言只覆盖列明的输入和性质，不把有限交叉验证当成数学证明或目标性能测试。
