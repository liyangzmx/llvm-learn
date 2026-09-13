#!/usr/bin/env python3
"""Check complete MLIR listings transcribed into chapter 9's first three sections.

This checks the delivered Markdown, independently of the transformation evidence.
Syntax skeletons, C examples and dependency-requiring operation fragments are
deliberately excluded. Cross-page fenced continuations are joined in page order.
"""
import json
from pathlib import Path
import re
import subprocess

evidence = Path(__file__).resolve().parent
chapter = evidence.parents[1] / "insider-compiler-ch9.md"
text = chapter.read_text()
headers = list(re.finditer(r"^\*\*代码清单 9-(\d+) [^\n]+\*\*", text, re.M))
selected = list(range(1, 9)) + [12, 13] + list(range(15, 27)) + [31, 32, 33]
destination = evidence / "ch9-front-verified"
destination.mkdir(exist_ok=True)
records = []
for index, header in enumerate(headers):
    number = int(header.group(1))
    if number not in selected:
        continue
    end = headers[index + 1].start() if index + 1 < len(headers) else len(text)
    section = text[header.end():end]
    blocks = re.findall(r"^```mlir\n(.*?)\n```", section, re.M | re.S)
    if not blocks:
        raise SystemExit(f"No MLIR found for listing {number}")
    source = destination / f"listing-9-{number}.mlir"
    source.write_text("\n".join(blocks) + "\n")
    command = ["/opt/llvm-project/build/bin/mlir-opt", str(source), "-o", "/dev/null"]
    result = subprocess.run(command, capture_output=True, text=True)
    records.append({"listing": number, "command": command,
                    "returncode": result.returncode, "stderr": result.stderr})
    print(f"listing {number}: exit {result.returncode}")
    if result.returncode:
        print(result.stderr)
(destination / "results.json").write_text(
    json.dumps(records, ensure_ascii=False, indent=2) + "\n")
raise SystemExit(any(record["returncode"] for record in records))
