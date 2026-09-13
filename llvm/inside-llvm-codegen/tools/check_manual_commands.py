#!/usr/bin/env python3
"""Execute the marked shell blocks directly from each chapter, in reading order."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
PATTERN = re.compile(r'<!-- manual-lab:(ch\d+-[\w-]+) -->\s*\n```sh\s*\n(.*?)^```[ \t]*$', re.M | re.S)


def sha(text):
    return hashlib.sha256(text.encode()).hexdigest()


def blocks(chapter):
    document = ROOT / f'inside-llvm-codegen-ch{chapter}.md'
    text = document.read_text()
    found = list(PATTERN.finditer(text))
    labels = [match[1] for match in found]
    if not labels or len(found) != text.count('<!-- manual-lab:'):
        raise ValueError(f'{document.name}: missing or malformed manual-lab blocks')
    if len(labels) != len(set(labels)) or any(not label.startswith(f'ch{chapter}-') for label in labels):
        raise ValueError(f'{document.name}: duplicate or mismatched block labels')
    return document, [{'label': match[1], 'line': text[:match.start()].count('\n') + 1,
                       'sha256': sha(match[2]), 'code': match[2]} for match in found]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--chapters', nargs='+', type=int, choices=range(1, 14), default=list(range(1, 14)))
    parser.add_argument('--build-dir', type=Path, default=Path(os.environ.get('LLVM_BUILD', '/opt/llvm-project/build')))
    parser.add_argument('--source-dir', type=Path, default=Path(os.environ.get('LLVM_SRC', '/opt/llvm-project')))
    parser.add_argument('--output-dir', type=Path)
    args = parser.parse_args()
    bash = shutil.which('bash')
    if not bash:
        raise RuntimeError('Bash is required for these manual examples')
    output = (args.output_dir or Path(tempfile.mkdtemp(prefix='llvm-book-manual-'))).resolve()
    output.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, LLVM_BUILD=str(args.build_dir.resolve()), LLVM_SRC=str(args.source_dir.resolve()),
               BOOK_ROOT=str(ROOT), PYTHONDONTWRITEBYTECODE='1', PYTHONOPTIMIZE='0')
    env.pop('BASH_ENV', None)
    results = []
    for chapter in args.chapters:
        print(f'Running chapter {chapter} manual commands...', flush=True)
        started = time.monotonic()
        item = {'chapter': chapter, 'passed': False}
        try:
            document, entries = blocks(chapter)
            item.update(file=document.name, blocks=[{k: v for k, v in entry.items() if k != 'code'} for entry in entries])
            script = "set -euo pipefail\nset -x\ntrap 'printf \"manual-lab directory: %s\\n\" \"${CODEGEN_LAB:-unset}\" >&2' EXIT\n"
            script += '\n'.join(f"# {entry['label']}\n{entry['code']}" for entry in entries)
            path = output / f'ch{chapter}.sh'
            path.write_text(script)
            item['script_sha256'] = sha(script)
            syntax = subprocess.run([bash, '-n', str(path)], text=True, capture_output=True)
            if syntax.returncode:
                raise ValueError(syntax.stderr)
            stdout, stderr = output / f'ch{chapter}.stdout', output / f'ch{chapter}.stderr'
            with stdout.open('w') as out, stderr.open('w') as err:
                result = subprocess.run([bash, '--noprofile', '--norc', str(path)], cwd=ROOT, env=env,
                                        stdout=out, stderr=err, timeout=600)
            item.update(returncode=result.returncode, stdout=str(stdout), stderr=str(stderr))
            current = blocks(chapter)[1]
            unchanged = [(e['label'], e['sha256']) for e in entries] == [(e['label'], e['sha256']) for e in current]
            item['commands_unchanged_during_run'] = unchanged
            item['passed'] = result.returncode == 0 and unchanged
            if not item['passed']:
                item['error'] = stderr.read_text()[-4000:]
        except (ValueError, subprocess.TimeoutExpired) as error:
            item['error'] = str(error)
        item['duration_seconds'] = round(time.monotonic() - started, 3)
        results.append(item)
        print(f'chapter {chapter}: {"PASS" if item["passed"] else "FAIL"}', flush=True)
    report = {'time_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'bash': bash, 'llvm_build': env['LLVM_BUILD'], 'llvm_source': env['LLVM_SRC'],
              'output_directory': str(output), 'chapters': results,
              'passed': all(item['passed'] for item in results),
              'scope': 'Execute marked chapter shell blocks in reading order, including explicit checks and expected failures. Uses the existing LLVM build; does not rerun CMake or claim hardware execution.'}
    (ROOT / 'review/manual-commands.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f'Report: {ROOT / "review/manual-commands.json"}', flush=True)
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
