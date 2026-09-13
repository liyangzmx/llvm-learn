#!/usr/bin/env python3
"""Verify the reading edition's zero-initialized, bias-last listings 1-4 to 1-7.

Only writes artifacts beside this script. Original OCR and historical evidence
are read-only. Inputs reuse the explicitly chosen historical validation data;
they do not reconstruct the book's truncated constants.
"""
import argparse
import hashlib
import json
import re
import struct
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OLD = ROOT / 'issues/evidence/ch1'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--llvm-bin', type=Path,
                    default=Path('/opt/llvm-project/build/bin'))
parser.add_argument('--translator', type=Path, required=True)
parser.add_argument('--clang', default='/usr/bin/clang')
args = parser.parse_args()

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

old_hashes = json.loads((HERE / 'old-evidence-sha256.json').read_text())
protected_hashes = {p: sha for p, sha in old_hashes.items()
                    if p != 'issues/evidence/ch1/README.md'}
def verify_historical_evidence():
    # The root reviewer may add a historical-batch notice to the old README.
    # Inputs, outputs, scripts and all other existing evidence stay byte-identical.
    assert all(digest(ROOT / p) == sha for p, sha in protected_hashes.items())
verify_historical_evidence()

markdown = ROOT / 'insider-compiler-ch1.md'
text = markdown.read_text()
heads = list(re.finditer(r'^\*\*代码清单 1-(\d+)\b[^\n]*$', text, re.M))
assert [int(h[1]) for h in heads] == list(range(1, 9))
assert [int(n) for n in re.findall(
    r'<!-- source: insider-compiler-ch1.pdf, PDF p\. (\d+) -->', text)] == list(range(1, 15))
assert re.findall(r'^\*\*图 1-(\d+)\*\*', text, re.M) == ['1', '2', '3', '4']
assert len(re.findall(r'^\[\^ch1-[^\]]+\]:', text, re.M)) == 12

data = json.loads((OLD / 'validation-data.json').read_text())
(HERE / 'validation-data.json').write_bytes((OLD / 'validation-data.json').read_bytes())

def dense_hex(nested):
    return 'dense<"0x' + ''.join(
        struct.pack('<f', v).hex().upper() for row in nested for v in row
    ) + '">'

listings = {}
for n in range(4, 8):
    head = heads[n-1]
    end = heads[n].start()
    code = '\n'.join(re.findall(r'^```mlir\s*\n(.*?)^```\s*$',
                               text[head.end():end], re.S | re.M))
    listings[n] = code
    (HERE / f'listing-1-{n}.mlir').write_text(code)
    complete = code.replace('dense<"0xC44B...">', dense_hex(data['weights_shape_16x10']))
    complete = complete.replace('dense<"0xA270...">', dense_hex(data['bias_shape_1x10']))
    (HERE / f'complete-1-{n}.mlir').write_text(complete)

def tokens_without_comments(code):
    return re.sub(r'//[^\n]*', '', code).split()
assert tokens_without_comments(listings[4]) == tokens_without_comments(listings[5])
assert tokens_without_comments(listings[6]) == tokens_without_comments(listings[7])

def f32_literal(value):
    return float(value).hex() + 'f'
header = '/* Generated from the saved explicit validation-data.json. */\n'
header += 'static const float validationWeights[16][10] = {\n'
header += ',\n'.join('  {' + ', '.join(map(f32_literal, row)) + '}'
                     for row in data['weights_shape_16x10']) + '\n};\n'
header += 'static const float validationBias[10] = {'
header += ', '.join(map(f32_literal, data['bias_shape_1x10'][0])) + '};\n'
(HERE / 'validation-data.h').write_text(header)

commands = []
def run(argv, capture_to=None):
    argv = [str(v) for v in argv]
    result = subprocess.run(argv, text=True, capture_output=True)
    record = {'argv': argv, 'exit': result.returncode, 'stderr': result.stderr,
              'stdout': result.stdout if capture_to is None else '(saved to '+capture_to.name+')'}
    commands.append(record)
    assert result.returncode == 0, record
    if capture_to is not None:
        capture_to.write_text(result.stdout)
    return result.stdout.strip()

opt = args.llvm_bin / 'mlir-opt'
with tempfile.TemporaryDirectory(prefix='ch1-reading-') as tmp:
    tmp = Path(tmp)
    version = run([opt, '--version'])
    for n in range(4, 8):
        run([opt, HERE / f'complete-1-{n}.mlir', '-o', tmp / f'parsed-{n}.mlir'])
    run([opt, HERE / 'complete-1-4.mlir',
         '--one-shot-bufferize=bufferize-function-boundaries',
         '--convert-linalg-to-affine-loops', '--canonicalize',
         '-o', HERE / 'linalg-to-affine.mlir'])
    run([opt, HERE / 'complete-1-6.mlir', '--lower-affine', '--convert-scf-to-cf',
         '--convert-arith-to-llvm', '--finalize-memref-to-llvm',
         '--convert-func-to-llvm', '--convert-cf-to-llvm',
         '--reconcile-unrealized-casts', '-o', HERE / 'affine-to-llvm.mlir'])
    for name in ['linalg-to-affine.mlir', 'affine-to-llvm.mlir']:
        run([opt, HERE / name, '-o', tmp / name])
    run([args.translator, HERE / 'affine-to-llvm.mlir'], capture_to=HERE / 'affine.ll')
    run([args.llvm_bin / 'llvm-as', HERE / 'affine.ll', '-o', tmp / 'affine.bc'])
    run([args.clang, '-O0', '-ffp-contract=off', HERE / 'affine.ll',
         HERE / 'run-forward.c', '-o', tmp / 'forward'])
    native = run([tmp / 'forward'])

verify_historical_evidence()
record = {
    'llvm': version,
    'markdown_sha256': digest(markdown),
    'scope': 'Current reading edition listings 1-4 to 1-7 only',
    'structure': {'pages': 14, 'listings': 8, 'figures': 4, 'footnotes': 12,
                  'annotated_versions_match_unannotated': True},
    'historical_evidence_files_unchanged': len(protected_hashes),
    'historical_readme_exception': 'Old README may gain a current-batch pointer; original hash remains in the snapshot',
    'data': 'Exact copy of historical explicit validation-data.json; not recovered book constants',
    'native': native,
    'boundaries': ['No Python/PyTorch/torch-mlir execution',
                   'No proof across all floating-point inputs or reduction schedules',
                   'No FMA contraction or reassociation was enabled for the host reference',
                   'No reconstruction of the original vectorized listing 1-8'],
    'commands': commands,
}
(HERE / 'verification-results.json').write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n')
print(json.dumps({k: v for k, v in record.items() if k != 'commands'}, ensure_ascii=False, indent=2))
print(f'{len(commands)} commands passed.')
