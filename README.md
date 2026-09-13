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

## 校验 Toy 教材

在仓库根目录执行，需要 Node.js、Bash，以及 `/opt/llvm-project` 下与 [来源基准](mlir/toy/SOURCES.md) 一致的 LLVM 源码：

```bash
node mlir/toy/scripts/validate-materials.mjs
node mlir/toy/scripts/validate-materials.test.mjs
```

脚本检查本地链接、源码摘录、代码围栏、章节包含关系和文件指纹。构建与实验步骤见 [第 0 章](mlir/toy/aiversion/00-preflight.md)，验证范围见 [验证记录](mlir/toy/VALIDATION.md)。

教材中的 `/opt/llvm-project/...` 是本地源码定位，需在本地阅读器中打开；GitHub 上阅读源码可从 [LLVM 基准提交](https://github.com/llvm/llvm-project/tree/3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff) 查找对应文件。

Toy 教材引用的原文与代码遵循 [Apache License 2.0 with LLVM Exceptions](mlir/toy/LICENSE-LLVM.txt)，详细来源与改动说明随主题保存。
