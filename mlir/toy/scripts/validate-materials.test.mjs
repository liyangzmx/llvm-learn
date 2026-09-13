import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const directory = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(directory, '..');
const script = fs.readFileSync(path.join(directory, 'validate-materials.mjs'), 'utf8');
const reader = "const read = p => fs.readFileSync(p, 'utf8');";
assert.ok(script.includes(reader), 'Update the in-memory test hook if the validator reader changes.');
const target = 'official/02-emitting-basic-mlir.md';
const original = fs.readFileSync(path.join(root, target), 'utf8');
const cases = [
  {
    name: 'missing provenance label',
    from: '> 代码性质：示意（非逐字源码，未编译或运行验证）。\n\n',
    to: '',
    expected: 'missing code provenance label',
  },
  {
    name: 'verbatim label without anchor',
    from: '[源码：Ch2/mlir/Dialect.cpp](/opt/llvm-project/mlir/examples/toy/Ch2/mlir/Dialect.cpp:145)\n\n',
    to: '',
    expected: 'verbatim block requires a source anchor',
  },
  {
    name: 'changed verbatim excerpt',
    from: '  // If the return type of the constant is not an unranked tensor, the shape',
    to: '  // Deliberately changed in memory for the validator regression test.',
    expected: 'source excerpt differs from',
  },
];

function run(program) {
  // stdin evaluation resolves import.meta.url beneath this cwd; the validator's
  // parent-directory root discovery therefore still targets the real workspace.
  return spawnSync(process.execPath, ['--input-type=module', '-'], {
    cwd: directory, input: program, encoding: 'utf8',
  });
}
const baseline = run(script);
assert.equal(baseline.status, 0, baseline.stderr || baseline.error?.message);
console.log('PASS: baseline');

for (const test of cases) {
  assert.ok(original.includes(test.from), 'Fixture changed: ' + test.name);
  // Intercept only the in-memory document read. No document, source, manifest,
  // or temporary file is written; the real validation logic runs unchanged.
  const hook = "const read = p => { const value = fs.readFileSync(p, 'utf8'); " +
    'return path.resolve(p) === path.join(root, ' + JSON.stringify(target) + ') ' +
    '? value.replace(' + JSON.stringify(test.from) + ', ' + JSON.stringify(test.to) + ') : value; };';
  const result = run(script.replace(reader, hook));
  assert.equal(result.status, 1, test.name + ': expected rejection, got ' + result.status);
  assert.ok(result.stderr.includes(test.expected), test.name + ': ' + result.stderr);
  console.log('PASS: rejects ' + test.name);
}
