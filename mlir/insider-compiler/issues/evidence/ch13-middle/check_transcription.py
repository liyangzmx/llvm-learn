#!/usr/bin/env python3
"""Text integrity checks only; this is not a Triton parser or semantic verifier."""
from pathlib import Path
import re,json
r=Path(__file__).resolve().parent
reports=[]
for n in (39,41,42,45,46,47):
 s=(r/f'listing-13-{n}.mlir').read_text()
 defs=re.findall(r'(%[A-Za-z0-9_.$-]+)(?::\d+)?\s*=',s)
 first_op=re.search(r'^    %[A-Za-z0-9_.$-]+(?::\d+)?\s*=',s,re.M)
 header=s[:first_op.start()]
 defs+=re.findall(r'(%[A-Za-z0-9_.$-]+)\s*:',header)
 assert len(defs)==len(set(defs)),(n,'duplicate SSA definition')
 uses=set(re.findall(r'%[A-Za-z0-9_.$-]+',s))
 missing=sorted(uses-set(defs));assert not missing,(n,missing)
 actual={int(x[1:]) for x in re.findall(r'(%\d+)(?::\d+)?\s*=',s)}
 if n!=39:
  maximum={41:19,42:35,45:36,46:79,47:64}[n]
  assert actual==set(range(maximum+1)),(n,sorted(set(range(maximum+1))-actual))
 c=re.sub(r'//[^\n]*','',s).replace('->','')
 c=re.sub(r'"(?:\\.|[^"\\])*"','""',c)
 pairs={')':'(',']':'[','}':'{','>':'<'};stack=[]
 for ch in c:
  if ch in '([{<':stack.append(ch)
  elif ch in pairs:
   assert stack and stack.pop()==pairs[ch],(n,ch,stack[-5:])
 assert not stack,(n,stack)
 reports.append({'listing':n,'ssa_names':len(uses),'numeric_definitions':len(actual),'all_names_defined_somewhere':True,'brackets_balanced':True})
formal=r.parents[2]/'insider-compiler-ch13.md'
full=formal.read_text() if formal.exists() else ''
start=re.search(r'^#{2,6} 7\. Pipeline 优化\s*$',full,re.M)
end=re.search(r'^#{2,6} 8\. .*OptimizeDotOperands.*$',full,re.M)
if start and end and start.start()<end.start():
 s=full[start.start():end.start()]
 document_source=formal
else:
 document_source=Path('/private/tmp/insider-ch13-middle.md')
 s=document_source.read_text()
assert [int(x) for x in re.findall(r'PDF p\. (\d+) -->',s)]==list(range(93,119))
assert [int(x) for x in re.findall(r'^\*\*代码清单 13-(\d+)\*\*',s,re.M)]==list(range(37,48))
assert len(re.findall(r'^```',s,re.M))%2==0
# Compare the actual merged code, joining fences separated by page markers.
# Keep quoted text and token boundaries exact; ignore whitespace and comments
# only outside strings. This is a transcription check, not a language parser.
token_pattern=re.compile(
 r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/|'
 r'[%@#]?[A-Za-z_$][A-Za-z0-9_$.-]*|\d+|->|[^\s]')
def normalized_tokens(code):
 return [m.group(0) for m in token_pattern.finditer(code)
         if not m.group(0).startswith(('//','/*'))]

captions=list(re.finditer(r'^\*\*代码清单 13-(\d+)\*\*[^\n]*$',s,re.M))
merged_checks=[]
for index,caption in enumerate(captions):
 number=int(caption.group(1))
 stop=captions[index+1].start() if index+1<len(captions) else len(s)
 section=s[caption.end():stop]
 fragments=re.findall(r'^```(mlir|text)\s*\n(.*?)^```[ \t]*$',section,re.M|re.S)
 expected_language='text' if number in (37,38,40,43,44) else 'mlir'
 assert fragments and all(lang==expected_language for lang,_ in fragments),(
     number,'missing code or unexpected fence language')
 extension='txt' if expected_language=='text' else 'mlir'
 evidence_file=r/f'listing-13-{number}.{extension}'
 expected=normalized_tokens(evidence_file.read_text())
 actual=normalized_tokens('\n'.join(code for _,code in fragments))
 if actual!=expected:
  mismatch=next((i for i,(a,b) in enumerate(zip(actual,expected)) if a!=b),
                min(len(actual),len(expected)))
  raise AssertionError((number,'merged listing differs from evidence',
                        'token',mismatch,'actual',actual[mismatch:mismatch+12],
                        'expected',expected[mismatch:mismatch+12]))
 merged_checks.append({'listing':number,'code_fragments':len(fragments),
                       'tokens':len(actual),'matches_evidence':True})
report={'scope':'Text integrity, not Triton parsing/execution or SSA dominance/type verification','document_source':str(document_source),'pages_with_markers':list(range(93,119)),'starts_in_page_92':True,'listings':reports,'merged_listing_checks':merged_checks,'visually_inspected_pdf_pages':[93,94,95,99,101,105,110,111,116,117,118]}
(r/'transcription-checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('PASS: all 11 merged listings match evidence; 26 continuation page markers; SSA name coverage/numeric inventory and bracket balance for six IR listings')
