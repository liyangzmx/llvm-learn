# 第 8 章可复现实验

要求 LLVM 18.1.8 Debug/assertions 构建的 `clang`、`opt`、`llc`、`llvm-tblgen`、`FileCheck`，以及 BPF、RISCV、Hexagon 三个后端。脚本使用 Python 3 标准库，不修改 LLVM 源码或构建配置。

```sh
export LLVM_BUILD=${LLVM_BUILD:-/opt/llvm-project/build}
export LLVM_SRC=${LLVM_SRC:-/opt/llvm-project}
export BOOK_ROOT=/opt/coding/mlir-toy/llvm/inside-llvm-codegen
python3 "$BOOK_ROOT/experiments/ch8/runner.py"
```

默认输出到新临时目录，结束时打印路径。`--output` 指定目录，`--summary` 额外保存 JSON。所有 stdout/stderr、完整 IR/MIR、Hexagon 汇编、解析后的 TableGen JSON 留在输出目录；`--bpf-only` 只运行子集，不代表完整覆盖。

| 输入 | 实际验证 |
|---|---|
| `dependencies.ll` | BPF 的 linearize/fast/list-burr/source/list-hybrid/list-ilp 六种 DAG 调度器；强制 MIR MachineScheduler 的数据、内存和输出依赖及压力 |
| `schedule-model.td` | 可独立解析的教学 Target；itinerary、SchedRW、WriteRes、ReadAdvance 的记录关系 |
| `pressure.c` | 原压力表达式在 RV32IM/E31 下的前后调度；小区域实际关闭 pressure tracking |
| `pressure-large.c` | 四项点积扩大区域，实际启用 pressure tracking |
| `postra.c` | 明确互斥启用 PostRASchedulerList 与 PostMachineScheduler，检查物理寄存器 MIR |
| `swp-bad-sched.ll` | 本地上游 Hexagon 回归输入，保留 RUN/CHECK/属性/TBAA；pipeliner 前后 MIR、实际 II 日志及最终 FileCheck |
| `models.py` | 全部小图拓扑序的压力范围、带边延迟的单发射时刻、RecMII 约束、N=0…64 的软件流水边界 |

RISC-V 前端、后端都指定 `sifive-e31`，ISA 为 RV32IM，ABI 为 ilp32，避免函数 `target-cpu` 属性覆盖命令行而产生误导。Hexagon 为 v60，明确启用 experimental codegen；本例一个循环 II=3 成功，另一个至 II=20 未找到安排，这些是固定输入/配置下的回归预期。

`models.py` 是教学模型，不重写 LLVM 算法。压力模型只计单位权重 SSA 临时值，不计指针和边界 live-in、子寄存器、early-clobber 等。流水例子假设不同迭代没有依赖，两个独立单元且发射宽度至少 2。`schedule-model.td` 仅通过 TableGen 解析及记录检查，并未注册为真实后端或模拟器。

JSON 报告记录版本、源提交、tracked 修改文件、输入哈希、完整命令及观察；占位路径只是为了便于迁移阅读。LLVM scheduler 的 latency/pressure 数字不等同硬件测量。生成机器代码没有在 BPF/RISC-V/Hexagon 设备上运行，FileCheck 和 machine verifier 的覆盖不等于任意输入的语义证明。
