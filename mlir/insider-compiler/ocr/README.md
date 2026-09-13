# Apple Vision 原始 OCR

本目录保存扫描件的原始识别结果，不进行拼写、代码或知识性修正。校订结果见上一级逐章 Markdown，差异见 `../issues/`。

这些原始结果仅保存在本地：Git 只跟踪本说明与 `manifest.json`，逐页 TXT／JSON、合并文本和 PNG 缓存均忽略。相邻 `pdf/` 下的扫描件也不进入 Git 历史；克隆仓库后，需自行准备扫描件才能运行下面的 OCR 命令。

按用户明确的校订原则，OCR 中的错误可以保留；日常阅读以逐章 Markdown 的修正版为准，`issues/` 仅供追溯原稿差异和核对依据。

- 引擎：macOS Apple Vision `VNRecognizeTextRequest`，`.accurate`，语言为 `zh-Hans`、`en-US`；关闭 `usesLanguageCorrection`。
- PDFKit 以 3 倍 PDF 点尺寸渲染，即 216 dpi；第 1～10 章及第 14 章至附录的页面为 1785 × 2526 像素，第 11–13 章合订扫描件为 1782 × 2521 像素。
- `page-NNN.txt`：Vision 返回顺序的逐行文本，保留页眉、页码、断行和识别错误。
- `page-NNN.json`：同一结果的行文本、置信度和归一化边界框；坐标原点在左下角。另存引擎 revision、页码、渲染参数。
- `insider-compiler-*.txt`：对应源 PDF 的合并文本，仅在页间加入换页符 `\f` 和换行，页内文字不变。
- `manifest.json`：源文件 SHA-256、页数、逐页文本 SHA-256、章节页码与源文件替换历史。
- `page-NNN.png`：用于逐页目视的渲染缓存，已被 Git 忽略，可由下列命令重新生成。

**第 1 章来源已更新：**用户于 2026-09-13 提供真实的 14 页《绪论》扫描件。`insider-compiler-ch1/` 保存新扫描件的逐页 OCR，`insider-compiler-ch1.txt` 对应这 14 页。此前同名文件重复包含第 2～3 章；该旧内容及其 OCR 完整保留在 `insider-compiler-ch2-ch3` 对应文件中，[替换前清单](../issues/evidence/ch1/manifest-before-ch1.json)保留历史映射。合并脚本仅允许已记录哈希的这次替换，后续仍核验来源和 OCR 哈希；相同内容不重复写入。

现有 7 个 PDF，共 **416 个源文件页、416 个不重复扫描页**。第 1 章 PDF 第 2～14 页印刷书页为 3～15，章首页书页 2 由此推定。`insider-compiler-ch7-ch10.pdf` 的 108 页中，第 1–17 页为第 7 章，第 18–20 页为第二部分扉页和导读，第 21–26 页为第 8 章，第 27–80 页为第 9 章，第 81–108 页为第 10 章。

`insider-compiler-ch11-ch13.pdf` 共 130 页：第 1–31 页为第 11 章，第 32–48 页为第 12 章，第 49 页为第三部分扉页和导读，第 50–130 页为第 13 章。两份导读分别保存为上一级 `insider-compiler-part2.md`、`insider-compiler-part3.md`，不混入相邻章节；`manifest.json` 的 `supplements` 记录其来源范围。第三部分附近未印页码与推定的页序间隔见 [源文件说明](../issues/source-files.md)。

最后补入的 `insider-compiler-ch14-end.pdf` 共 52 页：第 1 页为第四部分扉页与导读，第 2–25 页为第 14 章，第 26–48 页为第 15 章，第 49–52 页为附录。分别转写为上一级 `insider-compiler-part4.md`、`insider-compiler-ch14.md`、`insider-compiler-ch15.md`、`insider-compiler-appendix.md`。用户已确认这是整书最后一份扫描件，当前全部提供的扫描页均已纳入来源清单。

OCR 不可靠地保留字体粗细。Markdown 的章节结构、关键强调及图表在校订阶段恢复；按用户要求，优先目视文字稀少的图页、公式和识别异常的代码页，不要求逐处复原非关键字体样式。文字字数和置信度只是筛选线索，不代表页面内容已经正确。

## 复现

在项目根目录执行（需要 macOS Apple Vision、PDFKit 和 Swift）：

```sh
swiftc -module-cache-path /private/tmp/insider-swift-cache \
  mlir/insider-compiler/tools/vision_ocr.swift -o /private/tmp/insider-vision-ocr
for name in insider-compiler-ch1 insider-compiler-ch2-ch3 insider-compiler-ch4 insider-compiler-ch5-ch6 insider-compiler-ch7-ch10 insider-compiler-ch11-ch13 insider-compiler-ch14-end; do
  /private/tmp/insider-vision-ocr \
    "mlir/insider-compiler/pdf/$name.pdf" \
    "mlir/insider-compiler/ocr/$name"
done
python3 mlir/insider-compiler/tools/assemble_ocr.py
```

识别程序会跳过已完成（已存在 JSON）的页。若要复验识别，请指定一个新的输出目录，避免覆盖保存的原始结果。OCR 文本中的空白和代码标点仍须结合页面图像校对；置信度不能代替人工核验。
