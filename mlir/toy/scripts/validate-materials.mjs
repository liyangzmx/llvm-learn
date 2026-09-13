import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const errors = [];
const stats = { documents: 0, localLinks: 0, sourceExcerpts: 0, mermaidBlocks: 0, bashBlocks: 0, sourceFiles: 0, expandedChapters: 0, testPaths: 0, codeBlocks: { total: 0, verbatim: 0, adapted: 0, illustrative: 0, unclassified: 0 } };
const fail = message => errors.push(message);
const read = p => fs.readFileSync(p, 'utf8');
const fence = String.fromCharCode(96).repeat(3);
const manifest = JSON.parse(read(path.join(root, 'source-manifest.json')));
const docs = ['../../README.md', 'README.md', 'SOURCES.md', 'VALIDATION.md'];
for (const directory of ['official', 'aiversion']) {
  const files = fs.readdirSync(path.join(root, directory)).filter(p => p.endsWith('.md')).sort();
  for (const name of files) docs.push(directory + '/' + name);
  const chapters = files.filter(p => /^\d\d-/.test(p));
  if (chapters.length !== (directory === 'official' ? 7 : 8))
    fail(directory + ': wrong number of chapters');
}
const texts = new Map();
for (const rel of docs) {
  const absolute = path.join(root, rel);
  const content = read(absolute);
  texts.set(rel, content);
  stats.documents++;
  if (!content.startsWith('# ') || content.includes('\ufffd'))
    fail(rel + ': invalid heading or replacement character');
  const lines = content.split('\n');
  let language = null;
  let blockStart = 0;
  const blocks = [];
  const prose = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.startsWith(fence)) {
      if (language === null) {
        language = line.slice(3).trim();
        blockStart = i;
        if (i > 0 && lines[i - 1].trim()) fail(rel + ':' + (i + 1) + ': missing blank line before code fence');
      } else {
        if (line.trim() !== fence) fail(rel + ':' + (i + 1) + ': malformed closing fence');
        blocks.push({ language, start: blockStart, end: i, code: lines.slice(blockStart + 1, i).join('\n') });
        language = null;
      }
      prose.push('');
    } else {
      prose.push(language === null ? line : '');
    }
  }
  if (language !== null) fail(rel + ': unclosed code fence');
  for (const block of blocks) {
    if (block.language === 'bash') {
      stats.bashBlocks++;
      const result = spawnSync('bash', ['-n'], { input: block.code, encoding: 'utf8' });
      if (result.status !== 0) fail(rel + ':' + (block.start + 1) + ': shell syntax check failed: ' + (result.error?.message || result.stderr));
    }
    if (block.language === 'mermaid') {
      stats.mermaidBlocks++;
      if (!/^flowchart (?:TD|LR|TB|RL|BT)\n/.test(block.code))
        fail(rel + ':' + (block.start + 1) + ': expected flowchart declaration');
      if (!block.code.includes('-->')) fail(rel + ': empty Mermaid relationship graph');
    }
    const prefix = lines.slice(0, block.start).join('\n');
    const source = prefix.match(/\[源码：[^\]]+\]\((\/opt\/llvm-project\/[^)]+):(\d+)\)\s*$/);
    if (['c++', 'tablegen', 'mlir'].includes(block.language)) {
      stats.codeBlocks.total++;
      const label = prefix.match(/(?:^|\n)> 代码性质：(逐字源码|译编|示意)（[^\n]*）。\s*(?:\[源码：[^\]]+\]\([^)]+\)\s*)?$/);
      const kinds = { '逐字源码': 'verbatim', '译编': 'adapted', '示意': 'illustrative' };
      if (!label) {
        stats.codeBlocks.unclassified++;
        fail(rel + ':' + (block.start + 1) + ': missing code provenance label');
      } else {
        stats.codeBlocks[kinds[label[1]]]++;
        if (label[1] === '逐字源码' && !source)
          fail(rel + ':' + (block.start + 1) + ': verbatim block requires a source anchor');
        if (label[1] !== '逐字源码' && source)
          fail(rel + ':' + (block.start + 1) + ': source anchor requires verbatim label');
      }
    }
    if (source) {
      stats.sourceExcerpts++;
      try {
        const sourceLines = read(source[1]).split('\n');
        const start = Number(source[2]) - 1;
        const actual = sourceLines.slice(start, start + block.code.split('\n').length).join('\n');
        if (actual !== block.code) fail(rel + ':' + (block.start + 1) + ': source excerpt differs from ' + source[1] + ':' + source[2]);
      } catch (error) {
        fail(rel + ': cannot check excerpt: ' + error.message);
      }
    }
  }
  const linkRE = /!?\[[^\]\n]*\]\((<?[^)\n]+>?)\)/g;
  for (const match of prose.join('\n').matchAll(linkRE)) {
    const raw = match[1].replace(/^<|>$/g, '');
    if (/^(?:https?:|mailto:|#)/.test(raw)) continue;
    const [target] = raw.split('#');
    const lineMatch = target.match(/:(\d+)$/);
    const withoutLine = target.replace(/:\d+$/, '');
    const resolved = path.isAbsolute(withoutLine) ? withoutLine : path.resolve(path.dirname(absolute), withoutLine);
    stats.localLinks++;
    if (!fs.existsSync(resolved)) {
      fail(rel + ': broken local link ' + raw);
    } else if (lineMatch) {
      const n = Number(lineMatch[1]);
      if (!fs.statSync(resolved).isFile() || n < 1 || n > read(resolved).split('\n').length)
        fail(rel + ': invalid source line ' + raw);
    }
  }
  const testRE = /\/opt\/llvm-project\/mlir\/test\/Examples\/Toy\/Ch\d+\/[A-Za-z0-9_.-]+/g;
  for (const match of content.matchAll(testRE)) {
    stats.testPaths++;
    if (!fs.existsSync(match[0])) fail(rel + ': missing test input ' + match[0]);
  }
  for (const stale of ['$' + '{build_root}', '$' + '{mlir_src_root}']) {
    if (content.includes(stale)) fail(rel + ': stale path variable ' + stale);
  }
}
for (let chapter = 1; chapter <= 7; chapter++) {
  const prefix = '0' + chapter + '-';
  const official = docs.find(p => p.startsWith('official/' + prefix));
  const expanded = docs.find(p => p.startsWith('aiversion/' + prefix));
  if (!official || !expanded) { fail('Missing chapter ' + chapter); continue; }
  // Prefix equality proves inclusion only, not English-source coverage or teaching quality.
  const base = texts.get(official).replace(/^(# .*)$/m, '$1（扩充教材）').trimEnd();
  const full = texts.get(expanded);
  if (!full.startsWith(base)) fail(expanded + ': does not fully contain corresponding official chapter');
  const extension = full.slice(base.length);
  // This is only a gross-truncation guard, not a semantic quality metric.
  if ((extension.match(/^## /gm) || []).length < 4 || extension.length < 2500)
    fail(expanded + ': extension unexpectedly small');
  stats.expandedChapters++;
}
for (const entry of manifest.files) {
  const absolute = path.join(manifest.sourceRoot, entry.path);
  try {
    const actual = crypto.createHash('sha256').update(fs.readFileSync(absolute)).digest('hex');
    if (actual !== entry.sha256) fail('Source changed since baseline: ' + entry.path);
    stats.sourceFiles++;
  } catch (error) {
    fail('Missing source: ' + entry.path);
  }
}
if (read(path.join(root, 'LICENSE-LLVM.txt')).trimEnd() !== read(path.join(manifest.sourceRoot, 'LICENSE.TXT')).trimEnd())
  fail('LLVM license copy differs from source');
if (errors.length) {
  console.error(errors.join('\n'));
  console.error('FAILED: ' + errors.length + ' issue(s)');
  process.exitCode = 1;
} else {
  console.log('PASS: ' + JSON.stringify(stats));
  console.log('Static checks only; no semantic-quality or English-coverage guarantee; no LLVM build, MLIR verification, JIT execution, or diagram rendering is implied.');
}
