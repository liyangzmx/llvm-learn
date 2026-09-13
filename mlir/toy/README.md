# MLIR Toy 中文教材

[返回 LLVM / MLIR 知识库](../../README.md)

以本地 `/opt/llvm-project` 的 `release/18.x` / `3b5b5c1ec4a3` 为代码基准。

- [official：七章官方主线中文译编](official/README.md)
- [aiversion：第 0～7 章扩充教材](aiversion/README.md)
- [构建与实验准备](aiversion/00-preflight.md)
- [版本、来源与校正说明](SOURCES.md)
- [文档验证记录](VALIDATION.md)

扩充版完整包含对应 official 正文，另有基础解释、源码推导、图解和带答案的练习。源码与原文冲突时，以本地代码为准并解释差异。

在仓库根目录运行 `node mlir/toy/scripts/validate-materials.mjs`，或在本目录运行 `node scripts/validate-materials.mjs`，可检查文档链接、代码围栏、源码摘录、版本指纹及两套章节的包含关系。它不是编译器编译或 JIT 测试；构建和执行方法见第 0 章。

教材内部使用相对链接，实验通过 `TOY_ROOT` 定位本主题目录，与仓库检出目录的名称无关。指向 `/opt/llvm-project` 的源码链接仍是本地绝对路径，本地验证也依赖该源码检出；GitHub 上的源码阅读入口见 [知识库首页](../../README.md)。
