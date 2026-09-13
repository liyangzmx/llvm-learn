#!/usr/bin/env python3
"""Parse complete numbered chapter-11 examples extracted from the final Markdown."""
from pathlib import Path
import json
import re
import subprocess

D = Path(__file__).resolve().parent
chapter = D.parents[2] / 'insider-compiler-ch11.md'
content = chapter.read_text()
records = []
for number in range(3, 15):
    start = re.search(r'^\*\*代码清单 11-' + str(number) + r'\*\*[^\n]*', content, re.M)
    assert start, number
    next_listing = re.search(r'^\*\*代码清单 11-\d+\*\*', content[start.end():], re.M)
    end = start.end() + next_listing.start() if next_listing else len(content)
    section = content[start.end():end]
    language = 'llvm' if number == 4 else 'mlir'
    blocks = re.findall(r'^```' + language + r'\n(.*?)\n```', section, re.M | re.S)
    assert len(blocks) == (3 if number == 8 else 1), (number, len(blocks))
    source = '\n'.join(blocks) + '\n'
    path = D / ('markdown-listing-11-' + str(number) + ('.ll' if number == 4 else '.mlir'))
    path.write_text(source)
    command = ['/opt/llvm-project/build/bin/' + ('llvm-as' if number == 4 else 'mlir-opt'), str(path), '-o', '/dev/null']
    if number in (5, 6):
        command.append('--allow-unregistered-dialect')
    result = subprocess.run(command, capture_output=True, text=True)
    records.append({'listing': number, 'command': command, 'returncode': result.returncode, 'stderr': result.stderr})
    print(f'listing 11-{number}: exit {result.returncode}')
    if result.returncode:
        print(result.stderr)
(D / 'verify-markdown.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n')
raise SystemExit(any(record['returncode'] for record in records))
