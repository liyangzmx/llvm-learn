#!/usr/bin/env python3
"""Run chapter laboratories with one toolchain and retain a reproducible audit."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import platform
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ['clang', 'opt', 'llc', 'lli', 'llvm-as', 'llvm-dis', 'llvm-tblgen',
         'FileCheck', 'llvm-mc', 'llvm-objdump', 'llvm-readobj', 'llvm-config', 'mlir-opt', 'mlir-translate']


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def capture(args):
    return subprocess.check_output([str(x) for x in args], text=True).strip()


def input_digests():
    return {str(path.relative_to(ROOT)): digest(path)
            for path in sorted((ROOT / 'experiments').rglob('*'))
            if path.is_file() and '__pycache__' not in path.parts and path.suffix not in {'.pyc', '.pyo'}}


def environment(build, source):
    names = ['CMAKE_BUILD_TYPE', 'CMAKE_C_COMPILER', 'CMAKE_CXX_COMPILER', 'CMAKE_GENERATOR',
             'CMAKE_INSTALL_PREFIX', 'LLVM_ENABLE_PROJECTS', 'LLVM_TARGETS_TO_BUILD',
             'LLVM_ENABLE_ASSERTIONS', 'LLVM_DEFAULT_TARGET_TRIPLE', 'LLVM_HOST_TRIPLE',
             'LLVM_PARALLEL_COMPILE_JOBS', 'LLVM_PARALLEL_LINK_JOBS',
             'LLVM_INCLUDE_EXAMPLES', 'LLVM_BUILD_EXAMPLES', 'CMAKE_EXPORT_COMPILE_COMMANDS']
    cache = {}
    for line in (build / 'CMakeCache.txt').read_text().splitlines():
        if ':' in line and '=' in line:
            key = line.split(':', 1)[0]
            if key in names:
                cache[key] = line.split('=', 1)[1]
    changed = capture(['git', '-C', source, 'diff', '--name-only']).splitlines()
    return {'time_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'platform': platform.platform(), 'machine': platform.machine(), 'python_version': sys.version,
            'source_root': str(source), 'build_root': str(build),
            'source_commit': capture(['git', '-C', source, 'rev-parse', 'HEAD']),
            'source_tag': capture(['git', '-C', source, 'describe', '--tags', '--exact-match']),
            'previous_documentation_commit': 'c5924c6', 'cmake_cache': cache,
            'modified_source_sha256': {name: digest(source / name) for name in changed},
            'build_fix': 'review/build-source-fix.patch: undefined XOR5W32 corrected to XORW32',
            'tool_sha256': {name: digest(build / 'bin' / name) for name in TOOLS},
            'experiment_input_sha256': input_digests(),
            'coordinator_sha256': digest(Path(__file__).resolve()),
            'llc_version': capture([build / 'bin/llc', '--version']),
            'clang_version': capture([build / 'bin/clang', '--version']),
            'targets_built': capture([build / 'bin/llvm-config', '--targets-built'])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-dir', type=Path, default=Path(os.environ.get('LLVM_BUILD', '/opt/llvm-project/build')))
    parser.add_argument('--source-dir', type=Path, default=Path(os.environ.get('LLVM_SRC', '/opt/llvm-project')))
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--chapters', type=int, nargs='+', default=list(range(1, 14)), choices=range(1, 14))
    args = parser.parse_args()
    build, source = args.build_dir.resolve(), args.source_dir.resolve()
    out = (args.output_dir or Path(tempfile.mkdtemp(prefix='inside-llvm-experiments-'))).resolve()
    out.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, LLVM_BUILD=str(build), LLVM_SRC=str(source), BOOK_ROOT=str(ROOT),
               PYTHONDONTWRITEBYTECODE='1', PYTHONOPTIMIZE='0')
    before = environment(build, source)
    (ROOT / 'review/environment.json').write_text(json.dumps(before, ensure_ascii=False, indent=2) + '\n')
    results = []
    for chapter in args.chapters:
        name = f'ch{chapter}'
        flag = '--output-dir' if chapter <= 6 or chapter == 13 else '--output' if chapter <= 8 else '--out'
        command = [sys.executable, '-B', str(ROOT / 'experiments' / name / 'runner.py'), flag, str(out / name)]
        print(f'Running {name}...', flush=True)
        try:
            run = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=600)
            (out / f'{name}.stdout').write_text(run.stdout)
            (out / f'{name}.stderr').write_text(run.stderr)
            report = out / name / 'results.json'
            passed = run.returncode == 0 and report.exists()
            if passed:
                payload = json.loads(report.read_text())
                passed = payload.get('passed', True) is not False
                (ROOT / 'review' / f'experiments-{name}.json').write_text(report.read_text())
            item = {'chapter': chapter, 'command': command, 'returncode': run.returncode,
                    'passed': passed, 'report': f'review/experiments-{name}.json'}
            if not passed:
                item['error'] = run.stderr[-3000:] or run.stdout[-3000:] or 'Missing results.json'
        except subprocess.TimeoutExpired:
            item = {'chapter': chapter, 'command': command, 'passed': False, 'error': 'Timed out after 600 seconds'}
        results.append(item)
        print(f'{name}: {"PASS" if item["passed"] else "FAIL"}', flush=True)
    # Detect a concurrent build changing any tool while the suite was running.
    unchanged = all(digest(build / 'bin' / name) == value for name, value in before['tool_sha256'].items())
    inputs_unchanged = input_digests() == before['experiment_input_sha256']
    summary = {'time_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'output_directory': str(out), 'chapters': results, 'tools_unchanged_during_run': unchanged,
               'inputs_unchanged_during_run': inputs_unchanged,
               'passed': unchanged and inputs_unchanged and all(item['passed'] for item in results),
               'scope': 'Chapter-specific checks; foreign-target objects are not executed by the host. See each report for exact coverage.'}
    (ROOT / 'review/experiments-summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0 if summary['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
