"""Small runner shared by the introductory and backend-integration laboratories."""
from pathlib import Path
import argparse
import datetime
import json
import os
import subprocess
import tempfile

BOOK_ROOT = Path(__file__).resolve().parents[1]


class Lab:
    def __init__(self, chapter):
        parser = argparse.ArgumentParser()
        parser.add_argument('--build-dir', default=os.environ.get('LLVM_BUILD', '/opt/llvm-project/build'))
        parser.add_argument('--output-dir')
        args = parser.parse_args()
        self.chapter = chapter
        self.build = Path(args.build_dir).resolve()
        self.output = Path(args.output_dir or tempfile.mkdtemp(prefix=f'llvm-codegen-{chapter}-')).resolve()
        self.output.mkdir(parents=True, exist_ok=True)
        self.input = BOOK_ROOT / 'experiments' / chapter
        self.cases = []

    def tool(self, name):
        return str(self.build / 'bin' / name)

    def run(self, name, command, expected=0, contains=(), excludes=(), timeout=120):
        command = [str(x) for x in command]
        completed = subprocess.run(command, cwd=self.output, text=True, capture_output=True, timeout=timeout)
        combined = completed.stdout + completed.stderr
        code_ok = completed.returncode == expected if expected is not None else completed.returncode != 0
        passed = code_ok and all(x in combined for x in contains) and all(x not in combined for x in excludes)
        (self.output / f'{name}.stdout').write_text(completed.stdout)
        (self.output / f'{name}.stderr').write_text(completed.stderr)
        self.cases.append({'name': name, 'command': command, 'returncode': completed.returncode,
                           'expected_returncode': expected if expected is not None else 'nonzero',
                           'required_text': list(contains), 'forbidden_text': list(excludes),
                           'passed': passed, 'stdout': completed.stdout[:6000], 'stderr': completed.stderr[:3000]})
        if not passed:
            self.finish()
            raise AssertionError(f'{name}: exit {completed.returncode}\n{combined[:4000]}')
        return completed

    def check(self, name, condition, detail):
        self.cases.append({'name': name, 'passed': bool(condition), 'detail': detail})
        if not condition:
            self.finish()
            raise AssertionError(f'{name}: {detail}')

    def finish(self):
        report = {'chapter': self.chapter, 'llvm_build': str(self.build),
                  'time_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  'output_directory': str(self.output), 'cases': self.cases,
                  'passed': all(c['passed'] for c in self.cases),
                  'checks': len(self.cases)}
        path = BOOK_ROOT / 'review' / f'experiments-{self.chapter}.json'
        path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        (self.output / 'results.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        print(f'{self.chapter}: {len(self.cases)} checks, passed={report["passed"]}; output={self.output}')
        return report
