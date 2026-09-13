#!/usr/bin/env python3
"""Parse and verify the complete LLVM IR fences displayed in the chapter text."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-dir', type=Path,
                        default=Path(os.environ.get('LLVM_BUILD', '/opt/llvm-project/build')))
    args = parser.parse_args()
    tool = args.build_dir.resolve() / 'bin/llvm-as'
    cases = []
    with tempfile.TemporaryDirectory(prefix='llvm-book-ir-snippets-') as output:
        for document in sorted(ROOT.glob('inside-llvm-codegen-ch*.md')):
            text = document.read_text()
            for match in re.finditer(r'^```(?:llvm|llvm-ir)\s*\n(.*?)^```', text, re.M | re.S):
                source = match.group(1)
                line = text[:match.start()].count('\n') + 1
                path = Path(output) / f'{document.stem}-{line}.ll'
                path.write_text(source)
                result = subprocess.run([str(tool), str(path), '-o', os.devnull],
                                        text=True, capture_output=True, timeout=30)
                cases.append({'file': document.name, 'line': line,
                              'ir_sha256': hashlib.sha256(source.encode()).hexdigest(),
                              'returncode': result.returncode, 'diagnostic': result.stderr,
                              'passed': result.returncode == 0})
    report = {'tool': str(tool), 'checks': len(cases), 'cases': cases,
              'passed': bool(cases) and all(case['passed'] for case in cases),
              'scope': 'llvm-as parsing and IR verification of displayed llvm/llvm-ir fences. Does not execute code, validate C++/MIR fragments, or prove transformations equivalent.'}
    (ROOT / 'review/ir-snippets.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
