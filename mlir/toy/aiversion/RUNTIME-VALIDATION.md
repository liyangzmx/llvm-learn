# LLVM 18.1.8 Toy 实际运行验证

验证日期：2026-09-13。结论：教材第 1～7 章的主线与本地 LLVM 18 实现相符，已跑通从 AST、Toy IR、Affine、LLVM 方言、LLVM IR 到 JIT 的流程，没有发现阻碍按教程学习的重大问题。修正了过时的构建说明，并补充了两处错误输入的实测边界。

全程复用已有二进制，没有重新配置、编译或安装 LLVM，也没有修改 `/opt/llvm-project` 的源码和测试。

## 1. 环境确认

| 项目 | 实际值 |
|---|---|
| 源码 | `/opt/llvm-project` |
| 分支、提交 | `release/18.x`，`3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff` |
| 版本 | LLVM 18.1.8，`toyc-ch7 --version` 与源码一致 |
| 构建目录 | `/opt/llvm-project/build` |
| Toy 工具 | `bin/toyc-ch1` 至 `bin/toyc-ch7` 均存在并可执行 |
| 构建模式 | Debug，Assertions ON |
| Projects | `clang;mlir;clang-tools-extra` |
| Examples | `LLVM_INCLUDE_EXAMPLES=ON`、`LLVM_BUILD_EXAMPLES=ON` |
| 后端 | `BPF;Native`；宿主为 Apple arm64 |
| 测试配置 | `LLVM_INCLUDE_TESTS=ON`、`MLIR_INCLUDE_TESTS=ON`，已有 `llvm-lit` |

使用者提供的完整 CMake 命令已与缓存逐项核对，记录在 [仓库 README](../../../README.md#本地-llvm-1818-构建参数)。`Native` 已满足本地 [ExecutionEngine 启用条件](/opt/llvm-project/mlir/CMakeLists.txt:100)，无需补加其他 JIT 开关。

另发现旧 `llvm-config` 的时间戳为 6 月 30 日，`--targets-built` 只输出 BPF、`--host-target` 输出 unknown；9 月 13 日生成的 Toy 工具却能实际完成本机 JIT。该辅助二进制的输出与当前缓存不一致，不能用它单独否定当前 Toy 的 Native 支持。本次没有为更新它而触发构建。

## 2. 运行覆盖与结果

验证脚本记录了 76 个命令检查，全部满足各自预期；其中一次 lit 调用包含下列 56 个上游测试、60 条 RUN 指令。预期失败、预期文本差异与正常成功分别核对，没有把非零退出码一律算成失败。

| 章节 | 官方测试 | 教材实验的实际观察 |
|---|---:|---|
| Ch1 | 2/2 | AST 与 FileCheck 一致；`a + a * b` 的 AST 为外层加法、右侧乘法；声明 shape 与字面量 shape 分开保留 |
| Ch2 | 5/5 | AST、紧凑/通用 Toy IR、往返比较通过；四种 TableGen 生成命令成功 |
| Ch3 | 7/7 | 双重转置与三次 reshape 正常消除；共享结果仍保留；生成 DRR 的 benefit 为 1、2、2 |
| Ch4 | 8/8 | 不加 -opt 保留调用及无秩类型；开启后只剩 main 的具体张量计算；阶段日志显示 cast 的类型传播与消除 |
| Ch5 | 9/9 | Affine 降级与融合通过；alloc 从 3 减到 2，affine.for 从 4 减到 2；活跃 reshape 按预期被拒绝 |
| Ch6 | 11/11 | 四种 IR 输出与 JIT 成功；开启/关闭 -opt 的数值相同 |
| Ch7 | 14/14 | 结构体 AST、IR、OPT FileCheck、嵌套字段折叠和 Affine 降级通过；结构体例子的 JIT 数值正确 |
| 合计 | **56/56** | 无失败、无跳过 |

此外执行了：

- 43 组教材 bash 实验块。跳过环境变量设置和从零配置/构建块；使用已有工具与独立临时输出目录。4 次比较优化前后 IR 的 diff 按预期返回 1。
- 12 个完整 Toy/MLIR 围栏程序：5 个 Toy 程序、7 个 MLIR 程序。Ch1 仅验证 AST；其余按所属章节生成或解析 IR。未注册操作例子按第 3 节说明处理。
- 10 次 JIT 精确输出比较：Ch6/Ch7 的 jit.toy、llvm-lowering.mlir，以及 Ch7 的 struct-codegen.toy，各自开启/关闭 -opt。
- 标量与一维数组打印，确认末尾空格及“不额外换行”的行为。
- 两个新增教学输入、运算符优先级、已知错误传播缺口和形状验证缺口。

Ch6 的 jit.toy 实际输出为两行 `1.000000 2.000000 `、`3.000000 4.000000 `。Ch7 结构体示例实际输出如下；原始输出每个元素后均有空格，下方仅省略行末空格：

```text
1.000000 16.000000
4.000000 25.000000
9.000000 36.000000
```

静态核对也已通过：59 处逐字源码摘录（去重 36 段）、186 个来源文件指纹、7 组 official/aiversion 正文包含关系，以及文件链接和 shell 语法。源码核对关注了 Parser 优先级、MLIRGen、ODS、DRR、形状推断、两个 lowering pass、JIT 和结构体类型/字段实现。

## 3. 发现与修正

### 3.1 过时的环境描述

第 0、6 章及验证说明仍写着“现有 build 未启用 MLIR”，并在各章实验前执行构建命令。现已改为默认 `TOY_BUILD=/opt/llvm-project/build`、检查现有工具；从零构建仅作为可选准备步骤保留。README 和各实验的“未运行”标记已按本次证据更新。

### 3.2 未注册操作的宽松验证

第 2 章那个没有参数、却产生结果的未知 `"toy.print"()`，即使位于没有明确 return 的函数末尾，本地 `mlir-opt -allow-unregistered-dialect` 也会接受。原因是块末检查使用 `mightHaveTrait<IsTerminator>()`，未知操作可能被视为终结操作；这是宽松的未知操作处理，不是 Toy 操作语义验证。已补充本地 [Verifier.cpp](/opt/llvm-project/mlir/lib/IR/Verifier.cpp:153) 依据与实测说明，并同步对应 official 段落。

### 3.3 教学实现的错误路径仍不完备

`def main() { print(missing); }` 交给 Ch2 时，stderr 有 unknown variable 错误，但退出码仍为 0，且输出只包含 return 的函数。教材此前已提到错误传播缺口，本次把抽象描述补成可复现结果。

Ch4 对 2×3 和 3×2 张量相乘的输入也会生成 IR，并把结果类型设为左输入类型；不会自动拒绝两边 shape 不同。该行为与教材关于 Add/Mul 只传播左输入类型的描述一致。这个错误输入仅验证到 Toy IR，未交给 JIT 执行。

这些是上游教学实现已有的限制，不能把“56 个官方测试通过”解释成任意错误输入都得到完善诊断。本次没有改变上游实现。

### 3.4 reshape 失败与历史 CHECK

新增的 [05-live-reshape.toy](examples/05-live-reshape.toy) 能生成 Toy IR；Affine 降级返回 4，并报告 `failed to legalize operation 'toy.reshape' that was explicitly marked illegal`。这是缺少一般 reshape lowering 的预期边界，不是版本不匹配，也不需要重建解决。

Ch6/Ch7 的 llvm-lowering.mlir 最后一个数实测为 36。上游文件中仍有写成 30 的历史 CHECK 注释，但 RUN 没有连接 FileCheck；本次额外通过 JIT 数值比较确认了结果，保留原测试文件。

## 4. lit 跳过 JIT 的原因与可选补建

首次原样加载上游 lit 配置时，Ch1～5 的 31 项通过，Ch6～7 的 25 项被标记为 UNSUPPORTED。原因是 [lit.cfg.py](/opt/llvm-project/mlir/test/lit.cfg.py:220) 依赖 `mlir-cpu-runner --host-supports-jit` 探测宿主，而该二进制尚未构建。

本次先用 Toy 自身的 JIT 精确输出验证能力，再仅在临时 lit 配置中添加 `host-supports-jit`。实际测试仍读取上游原文件及 RUN/检查规则，输出目录位于临时目录；重跑后 56 项全部通过。没有修改上游 lit 文件，也没有伪造 cpu-runner 可执行文件。

若希望直接使用原生 lit 配置，可单独补建已存在的 `mlir-cpu-runner` 目标。2026-09-13 dry-run 只有 15 步：编译 10 个 C++ 文件、链接 4 个静态库和 1 个可执行文件，没有重新配置 CMake 或全量 LLVM/Clang 编译。本次仅预览，实际构建命令见 [README 的可选补建步骤](../../../README.md#可选补齐官方-lit-的-jit-探测工具)。

## 5. 复跑与证据

在知识库根目录执行：

```bash
TOY_BUILD=/opt/llvm-project/build python3 mlir/toy/scripts/verify-existing-build.py
node mlir/toy/scripts/validate-materials.mjs
node mlir/toy/scripts/validate-materials.test.mjs
```

运行脚本只用已有工具，跳过配置和构建块；输出到新建的临时目录。`--output /一个尚不存在的目录` 可指定存档位置。每条命令的退出码、stdout、stderr 都被保存。

- [运行检查记录](evidence/2026-09-13/results.json)：76 个命令检查及预期，包含已知边界。
- [官方测试结果](evidence/2026-09-13/lit-results.json)：56 个测试的状态及实际执行命令。
- [实验命令清单](evidence/2026-09-13/labs.json)：43 组命令和章节位置。
- [完整原始输出压缩包](evidence/2026-09-13/full-logs.tar.gz)：IR、TableGen 产物、JIT stdout、诊断与临时 lit 配置。
- [静态核对输出](evidence/2026-09-13/static-checks.txt)。
- [cpu-runner dry-run 清单](evidence/2026-09-13/mlir-cpu-runner-dry-run.txt)。

示意性 C++/TableGen 片段没有被拼装为独立 C++ 项目编译；未完整的 IR 片段、生产级异常处理、完整动态 shape/运行时结构体 ABI，以及 Mermaid 的视觉渲染不在本次运行保证范围内。
