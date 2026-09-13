#!/usr/bin/env python3
"""Extract the supplied typeset PDF, saving only cropped figures as image assets.

Requires pdfplumber, pypdfium2 and Pillow. Never modifies the PDF or reviewed files.
Run from any directory. The original is intentionally not technically corrected.
"""
from pathlib import Path
import collections
import hashlib
import json
import re
import subprocess

import pdfplumber
import pypdfium2 as pdfium

ROOT = Path(__file__).resolve().parents[1]
PDF = ROOT / 'pdf/inside-llvm-codegen.pdf'
OUT = ROOT / 'origin'
MANUAL_FIGURES = {
    20: [('1-2', (150, 300, 985, 706)), ('1-3', (150, 850, 983, 1343))],
    21: [('1-4', (18, 114, 1070, 392)), ('1-5', (104, 548, 984, 1040))],
    333: [('10-47', (276, 18, 800, 1428))],
}
SECTIONS = [
    ('frontmatter', '封面、版权、前言与目录', 1, 13),
    ('part1', '第一部分 基础知识', 14, 14),
    ('ch1', '第 1 章 绪论', 15, 22),
    ('ch2', '第 2 章 IR 基础知识', 23, 43),
    ('ch3', '第 3 章 数据流分析基础知识', 44, 63),
    ('ch4', '第 4 章 支配分析', 64, 75),
    ('ch5', '第 5 章 循环基本知识', 76, 84),
    ('ch6', '第 6 章 TableGen 介绍', 85, 99),
    ('part2', '第二部分 代码生成', 100, 103),
    ('ch7', '第 7 章 指令选择', 104, 159),
    ('ch8', '第 8 章 指令调度', 160, 216),
    ('ch9', '第 9 章 基于 SSA 形式的编译优化', 217, 244),
    ('ch10', '第 10 章 寄存器分配', 245, 342),
    ('ch11', '第 11 章 函数栈帧生成和非 SSA 形式的编译优化', 343, 385),
    ('ch12', '第 12 章 生成机器码', 386, 394),
    ('ch13', '第 13 章 添加一个新后端', 395, 402),
    ('appendices', '附录扉页', 403, 404),
    ('appendix-a', '附录 A LLVM 的中间表示', 405, 419),
    ('appendix-b', '附录 B BPF 介绍', 420, 425),
    ('appendix-c', '附录 C Pass 的分类与管理', 426, 431),
    ('backmatter', '书后推荐阅读、作者简介与封底', 432, 435),
]


def clean(s):
    # Preserve original punctuation and spelling; expand only presentation ligatures.
    for a, b in [('ﬁ', 'fi'), ('ﬂ', 'fl'), ('ﬀ', 'ff'), ('ﬃ', 'ffi'), ('ﬄ', 'ffl')]:
        s = s.replace(a, b)
    return ''.join(c for c in s if ord(c) >= 32 or c in '\n\t').strip()


def code_regions(page):
    bands = []
    for line in page.lines:
        color = line.get('stroking_color')
        if isinstance(color, (tuple, list)) and len(color) == 4 and abs(color[0] - .1) < .015 and max(color[1:]) < .01 and line['width'] > 180:
            half = line.get('linewidth', 0) / 2
            bands.append((line['x0'], line['top'] - half, line['x1'], line['bottom'] + half))
    groups = []
    for box in sorted(bands, key=lambda b: b[1]):
        if groups and box[1] <= groups[-1][3] + 3 and abs(box[0] - groups[-1][0]) < 4:
            old = groups[-1]
            groups[-1] = (min(old[0], box[0]), old[1], max(old[2], box[2]), max(old[3], box[3]))
        else:
            groups.append(box)
    return groups


def code_text(lines):
    # Courier is 4.8 PDF points wide. Retain indentation and join CJK comments
    # on the same baseline (their PDF font metrics differ by 3.5 points).
    left = min(l['x0'] for l in lines)
    output = []
    prev = None
    for line in lines:
        if prev is not None and line['top'] - prev > 17:
            output.append('')
        chars = sorted(line['chars'], key=lambda c: c['x0'])
        s = ' ' * max(0, round((line['x0'] - left) / 4.8))
        end = line['x0']
        for c in chars:
            gap = c['x0'] - end
            if gap > 2.8:
                s += ' ' * max(1, round(gap / 4.8))
            s += c['text']
            end = c['x1']
        output.append(s.rstrip())
        prev = line['top']
    return '\n'.join(output)


def extract(page, number, key, rendered):
    ordinary = 14 <= number <= 431
    crop = page.crop((190, 204, 632, 789)) if ordinary else page
    lines = crop.extract_text_lines(y_tolerance=5, x_tolerance=1.7)
    boxes = code_regions(crop)
    code_for = {}
    grouped = collections.defaultdict(list)
    for i, line in enumerate(lines):
        mid = (line['top'] + line['bottom']) / 2
        for n, b in enumerate(boxes):
            if b[1] - 1 <= mid <= b[3] + 1:
                code_for[i] = n
                grouped[n].append(line)
                break
    # Do not linearize labels inside an already preserved figure. They read in
    # graph order, not paragraph order, and would otherwise duplicate as gibberish.
    figure_lines = set()
    boundary = 205
    for i, line in enumerate(lines):
        caption = re.match(r'^图\s*[\dABC]+[-－–]\d+(?=\s|$)', clean(line['text']))
        sizes = [c['size'] for c in line['chars'] if not c['text'].isspace()]
        if caption and (not sizes or max(sizes) < 9.8):
            for j in range(i):
                if j not in code_for and lines[j]['top'] > boundary + 2 and lines[j]['bottom'] < line['top']:
                    figure_lines.add(j)
            boundary = line['bottom']
        elif i in code_for or (sizes and max(sizes) >= 9.8):
            boundary = line['bottom']
    output = []
    emitted = set()
    para = []
    figures = []
    def flush():
        if para:
            output.append(''.join(para))
            para.clear()
    left = 204 if number % 2 else 209.7
    last_bottom = 205
    for i, line in enumerate(lines):
        if i in figure_lines:
            continue
        s = clean(line['text'])
        if not s:
            continue
        if i in code_for:
            flush()
            group = code_for[i]
            if group not in emitted:
                output.append('```text\n' + code_text(grouped[group]) + '\n```')
                emitted.add(group)
            last_bottom = line['bottom']
            continue
        heading = re.match(r'^(\d{1,2}|[ABC])\.\d+(?:\.\d+)?(?=\s)', s)
        cap = re.match(r'^(图|表|代码清单)\s*([\dABC]+[-－–]\d+)(?=\s|$)', s)
        sizes = [c['size'] for c in line['chars'] if not c['text'].isspace()]
        if heading and sizes and max(sizes) >= 11:
            flush()
            level = 2 if heading[0].count('.') == 1 else 3
            output.append('#' * level + ' ' + s)
        elif cap:
            flush()
            if cap[1] == '图' and ordinary:
                # Diagram lettering is frequently converted to vector outlines.
                # Bound the figure by the preceding ordinary paragraph, not glyph count.
                top = last_bottom + 3
                bottom = line['top'] - 2
                if bottom - top > 18:
                    name = f'p{number:03d}-{cap[2]}.png'
                    # rendered is cropped to (190, 204, 632, 789), at 2.5 px/pt.
                    area = (0, max(0, round((top - 204) * 2.5)), rendered.width,
                            min(rendered.height, round((bottom - 204) * 2.5)))
                    if area[3] > area[1]:
                        rendered.crop(area).save(OUT / 'assets/figures' / name)
                        output.append(f'![{s}](assets/figures/{name})')
                        figures.append(name)
            output.append('**' + s + '**')
        elif (sizes and max(sizes) >= 18) or re.match(r'^第\s*\d+\s*章', s) or re.match(r'^Chapter\s+\d+', s):
            flush()
            output.append(s)
        else:
            newpara = line['x0'] > left + 12 or re.match(r'^(?:\d+[）)]|[①②③④⑤⑥⑦⑧⑨]|[○◯])', s)
            if newpara or line['top'] - last_bottom > 12:
                flush()
            if para and para[-1][-1:].isascii() and s[:1].isascii():
                para.append(' ')
            para.append(s)
        # Exclude small lettering potentially belonging to diagrams from the
        # preceding-body boundary. Code and captions remain valid boundaries.
        if cap or (sizes and max(sizes) >= 9.8):
            last_bottom = line['bottom']
    flush()
    transcription = ROOT / 'tools/page-transcriptions' / f'page-{number:03d}.md'
    recovered = transcription.exists()
    if recovered:
        output = [transcription.read_text().strip()]
    for figure, _ in MANUAL_FIGURES.get(number, []):
        name = f'p{number:03d}-{figure}.png'
        if name not in '\n'.join(output):
            output.append(f'![图 {figure}](assets/figures/{name})')
        if name not in figures:
            figures.append(name)
    printed = number - 13 if ordinary else None
    text = f'<!-- PDF page {number}; printed page {printed} -->\n\n' + '\n\n'.join(output)
    return text + '\n', {'pdf_page': number, 'printed_page': printed, 'code_regions': len(boxes), 'figures': figures, 'text_characters': sum(len(clean(l['text'])) for l in lines), 'manual_transcription': recovered}


def render_page_image(doc, number):
    """Render transiently for figure extraction; never save whole-page images."""
    page = doc[number - 1]
    page.set_cropbox(*page.get_mediabox())
    bitmap = page.render(scale=2.5 if 14 <= number <= 431 else 1.2)
    image = bitmap.to_pil().copy()
    bitmap.close()
    page.close()
    if 14 <= number <= 431:
        cropped = image.crop((475, 510, 1580, 1973))
        image.close()
        return cropped
    return image


def main():
    (OUT / 'assets/figures').mkdir(parents=True, exist_ok=True)
    subprocess.run(['pdftotext', '-layout', str(PDF), str(OUT / 'source-layout.txt')], check=True)
    doc = pdfium.PdfDocument(PDF)
    manifest = {'source': str(PDF.relative_to(ROOT)), 'sha256': hashlib.sha256(PDF.read_bytes()).hexdigest(), 'page_count': len(doc), 'sections': []}
    with pdfplumber.open(PDF) as book:
        for key, title, start, end in SECTIONS:
            file = f'inside-llvm-codegen-{key}.md'
            parts = [f'# {title}\n\n> 原文转写，未经技术修订。来源：[原 PDF](../pdf/inside-llvm-codegen.pdf)，PDF 第 {start}–{end} 页。书中基线为 LLVM 15（示例 15.0.1）。\n> 保留原文观点、命令及排印错误；代码缩进按 PDF 坐标恢复。保留原图裁剪及页码标记，图表、公式或特殊字体可对照原 PDF 读取。\n']
            pages = []
            for number in range(start, end + 1):
                page = book.pages[number - 1]
                image = render_page_image(doc, number)
                for figure, box in MANUAL_FIGURES.get(number, []):
                    image.crop(box).save(OUT / 'assets/figures' / f'p{number:03d}-{figure}.png')
                content, info = extract(page, number, key, image)
                parts.append(content)
                pages.append(info)
                image.close()
                page.close()
            (OUT / file).write_text('\n'.join(parts))
            manifest['sections'].append({'key': key, 'title': title, 'file': file, 'pdf_start': start, 'pdf_end': end, 'pages': pages})
            print(f'{key}: pages {start}-{end}, {sum(p["code_regions"] for p in pages)} code regions', flush=True)
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    doc.close()
    rows = ['# 原文目录', '', '本文档集由本地 [PDF](../pdf/inside-llvm-codegen.pdf) 提取，未经技术修订。正文为可搜索 Markdown；原图裁剪保留在 `assets/figures/`。`source-layout.txt` 保存 Poppler 全文原始提取，`manifest.json` 记录 PDF 页码、清单区域、图片和文件校验值。完整版面可直接查阅原 PDF。', '', '| 内容 | PDF 页码 |', '| --- | --- |']
    for key, title, start, end in SECTIONS:
        rows.append(f'| [{title}](inside-llvm-codegen-{key}.md) | {start}–{end} |')
    (OUT / 'README.md').write_text('\n'.join(rows) + '\n')


if __name__ == '__main__':
    main()
