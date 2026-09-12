# MLIR Toy 中文教材

以本地 `/opt/llvm-project` 的 `release/18.x` / `3b5b5c1ec4a3` 为代码基准。

- [official：七章官方主线中文译编](official/README.md)
- [aiversion：第 0～7 章扩充教材](aiversion/README.md)
- [构建与实验准备](aiversion/00-preflight.md)
- [版本、来源与校正说明](SOURCES.md)
- [文档验证记录](VALIDATION.md)

扩充版完整包含对应 official 正文，另有基础解释、源码推导、图解和带答案的练习。源码与原文冲突时，以本地代码为准并解释差异。

可运行 `node scripts/validate-materials.mjs` 检查文档链接、代码围栏、源码摘录、版本指纹及两套章节的包含关系。它不是编译器编译或 JIT 测试；构建和执行方法见第 0 章。

本教材保留指向 `/opt/llvm-project` 和 `/opt/coding/mlir-toy` 的本地绝对路径。GitHub 上可以阅读章节，但这些源码跳转及本地验证脚本依赖相应的检出路径；它们不是指向 GitHub 仓库文件的网页链接。
