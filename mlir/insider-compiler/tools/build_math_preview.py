#!/usr/bin/env python3
"""Build a local browser preview of the new chapters' Markdown math."""
import hashlib
import json
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
output = Path(sys.argv[1] if len(sys.argv) > 1 else '/private/tmp/insider-qa/math.html')
items = []
for name in ['insider-compiler-ch14.md', 'insider-compiler-ch15.md', 'insider-compiler-appendix.md']:
    file = root / name
    if not file.exists():
        continue
    text = file.read_text()
    # Mask code without moving source line locations.
    text = re.sub(r'^```[^\n]*\n.*?^```', lambda m: re.sub(r'[^\n]', ' ', m[0]), text, flags=re.M | re.S)
    text = re.sub(r'`[^`\n]*`', lambda m: ' ' * len(m[0]), text)
    pattern = r'(?<!\\)\$\$(.*?)(?<!\\)\$\$|(?<!\\)\$([^\n$]+?)(?<!\\)\$'
    unmatched = re.search(r'(?<!\\)\$', re.sub(pattern, '', text, flags=re.S))
    if unmatched:
        raise ValueError(f'{name}: unmatched math dollar delimiter')
    for index, m in enumerate(re.finditer(pattern, text, re.S), 1):
        tex = m[1] if m[1] is not None else m[2]
        items.append({'file': name, 'index': index, 'line': text.count('\n', 0, m.start()) + 1,
                      'display': m[1] is not None, 'tex': tex,
                      'sha256': hashlib.sha256(tex.encode()).hexdigest()})
html = '''<!doctype html><meta charset="utf-8"><title>新增章节数学公式校验</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.22/dist/katex.min.css">
<style>body{font:16px system-ui;margin:32px;background:#f7f7f4;color:#17282a}article{background:white;padding:18px;margin:18px 0;border:1px solid #ddd}.math{overflow:auto;padding:12px}.error{color:#b31b1b}h2{font-size:14px}</style>
<h1>新增章节数学公式校验</h1><p id="status">正在加载 KaTeX…</p><main></main>
<script type="module">
const items=__ITEMS__;
try {
 const {default:katex}=await import('https://cdn.jsdelivr.net/npm/katex@0.16.22/dist/katex.mjs');
 let failures=0;
 const chosen=new URLSearchParams(location.search).get('file');
 const selected=items.filter(item=>!chosen||item.file===chosen);
 for(const item of selected){
  const a=document.createElement('article');
  a.dataset.file=item.file;a.dataset.index=item.index;a.dataset.line=item.line;a.dataset.sha256=item.sha256;
  const h=document.createElement('h2');h.textContent=item.file+':'+item.line+' 公式 '+item.index;
  const s=document.createElement('div');s.className='status';
  const g=document.createElement('div');g.className='math';
  a.append(h,s,g);document.querySelector('main').append(a);
  try{katex.render(item.tex,g,{displayMode:item.display,throwOnError:true,strict:'warn'});s.textContent='PASS';}
  catch(e){failures++;s.textContent='FAIL '+e.message;s.classList.add('error');g.textContent=item.tex;}
 }
 document.querySelector('#status').textContent='DONE '+selected.length+' formulas; '+failures+' failures';
}catch(e){document.querySelector('#status').textContent='LOAD ERROR '+e.message;}
</script>'''.replace('__ITEMS__', json.dumps(items, ensure_ascii=False).replace('</', '<\\/'))
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(html)
output.with_suffix('.items.json').write_text(json.dumps(items, ensure_ascii=False, indent=2) + '\n')
print(f'Prepared {len(items)} formulas in {output}')
