# LLVM / MLIR 学习知识库

记录 LLVM 与 MLIR 的学习资料、源码阅读、实验和问题总结，按技术领域与具体主题组织。

## 学习入口

| 主题 | 内容 | 入口 |
|---|---|---|
| MLIR / Toy | 官方教程中文译编、扩充讲解与实验 | [Toy 教材](mlir/toy/README.md) |

目前已整理 MLIR Toy 教程；后续 LLVM 主题放入 `llvm/<主题>/`，其他 MLIR 主题放入 `mlir/<主题>/`，并在此补充导航。

## 目录约定

```text
mlir/
└── toy/
    ├── README.md              教材入口
    ├── official/              官方教程中文译编
    ├── aiversion/             扩充教材
    │   └── examples/          独立实验输入
    ├── scripts/               本主题的文档校验脚本
    ├── SOURCES.md             来源与版本说明
    ├── VALIDATION.md          验证记录与限制
    ├── source-manifest.json   上游源码指纹
    └── LICENSE-LLVM.txt       引用材料的 LLVM 许可证
```

每个主题集中保存正文、示例、来源与验证说明；仓库内文档使用相对链接，便于目录整体迁移和 GitHub 阅读。

## 本地 LLVM 18.1.8 构建参数

以下是本机已有构建的配置命令，由使用者提供，并于 2026-09-13 与 `/opt/llvm-project/build/CMakeCache.txt` 逐项核对一致。已将聊天文本中的转义下划线和不规则空白还原为可复制的 shell 语法。此处只记录配置；本次教程验证没有重新执行 CMake 配置或构建。

```bash
export TOY_BUILD=/opt/llvm-project/build

cmake -G Ninja \
  -S /opt/llvm-project/llvm \
  -B "$TOY_BUILD" \
  -DLLVM_ENABLE_PROJECTS="clang;mlir;clang-tools-extra" \
  -DLLVM_INCLUDE_EXAMPLES=ON \
  -DLLVM_BUILD_EXAMPLES=ON \
  -DLLVM_TARGETS_TO_BUILD="BPF;Native" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_PARALLEL_COMPILE_JOBS=12 \
  -DLLVM_PARALLEL_LINK_JOBS=1 \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DCMAKE_C_COMPILER=/usr/bin/cc \
  -DCMAKE_CXX_COMPILER=/usr/bin/c++ \
  -DCMAKE_INSTALL_PREFIX=/opt/llvm-project/install
```

`LLVM_ENABLE_PROJECTS` 启用 MLIR，两个 Examples 选项启用示例目标与构建，`Native` 包含宿主后端。本地 LLVM 18 根据宿主目标是否可用启用 MLIR ExecutionEngine；现有 `toyc-ch6`、`toyc-ch7` 的 JIT 已实际运行成功，不需要补加 JIT 参数。学习时直接复用已有二进制，见 [环境准备](mlir/toy/aiversion/00-preflight.md) 和 [运行验证报告](mlir/toy/aiversion/RUNTIME-VALIDATION.md)。

### 可选：补齐官方 lit 的 JIT 探测工具

`build/bin/llvm-lit` 已存在，缓存中的 `LLVM_INCLUDE_TESTS=ON`、`MLIR_INCLUDE_TESTS=ON` 也已开启，无需新增 CMake 配置参数。当前缺少的是 `mlir-cpu-runner` 二进制；官方 MLIR lit 通过它的 `--host-supports-jit` 探测 JIT，因此会跳过 Toy 第 6、7 章。该构建目标已经存在，可直接补建。

先预览工作量：

```bash
ninja -C /opt/llvm-project/build -n mlir-cpu-runner
```

2026-09-13 的 dry-run 只有 15 步：编译 10 个 C++ 文件、链接 4 个静态库和 1 个可执行文件，没有 CMake 重新配置或全量 LLVM/Clang 重编。清单见 [dry-run 日志](mlir/toy/aiversion/evidence/2026-09-13/mlir-cpu-runner-dry-run.txt)；后续源码或配置变化后，以新的预览结果为准。

需要补齐时执行：

```bash
cmake --build /opt/llvm-project/build --target mlir-cpu-runner --parallel 12
/opt/llvm-project/build/bin/mlir-cpu-runner --host-supports-jit
python3 /opt/llvm-project/build/bin/llvm-lit -v -j 2 \
  /opt/llvm-project/mlir/test/Examples/Toy
```

这里的 `cmake --build` 调用已有构建系统，不是重新执行配置；仅补建指定目标及过期或缺失的依赖。上面的实际构建命令留给使用者执行，本次只运行了 dry-run。即使不补建，也可使用下节的验证脚本：它在 Toy 自身 JIT 数值测试成功后，为临时 lit 配置补上能力标记。

## 校验 Toy 教材

在仓库根目录执行，需要 Node.js、Bash，以及 `/opt/llvm-project` 下与 [来源基准](mlir/toy/SOURCES.md) 一致的 LLVM 源码：

```bash
node mlir/toy/scripts/validate-materials.mjs
node mlir/toy/scripts/validate-materials.test.mjs
```

脚本检查本地链接、源码摘录、代码围栏、章节包含关系和文件指纹。构建与实验步骤见 [第 0 章](mlir/toy/aiversion/00-preflight.md)，验证范围见 [验证记录](mlir/toy/VALIDATION.md)。

复跑已有二进制的逐章实验、官方 Toy 测试和数值检查：

```bash
TOY_BUILD=/opt/llvm-project/build python3 mlir/toy/scripts/verify-existing-build.py
```

该脚本跳过配置和构建命令，将运行输出放在新建的临时目录，结束时打印证据路径。

教材中的 `/opt/llvm-project/...` 是本地源码定位，需在本地阅读器中打开；GitHub 上阅读源码可从 [LLVM 基准提交](https://github.com/llvm/llvm-project/tree/3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff) 查找对应文件。

Toy 教材引用的原文与代码遵循 [Apache License 2.0 with LLVM Exceptions](mlir/toy/LICENSE-LLVM.txt)，详细来源与改动说明随主题保存。
