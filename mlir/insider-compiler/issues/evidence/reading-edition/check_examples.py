"""Check the newly completed integer projection and the published DLTI input."""
from pathlib import Path
import json, re, hashlib
root = Path(__file__).resolve().parents[3]
here = Path(__file__).resolve().parent
cases = 0
for w in range(-48, 49):
    for z in range(-48, 49):
        # The original inequalities imply ceil(w/3) <= y <= floor((z+5)/2).
        # Enumerate that entire finite range, including negative values.
        ymin = -((-w) // 3)
        ymax = (z + 5) // 2
        original = any(3*y-2*w+1 > -w and 2*y-6 < z and (5*y+1) % 4 == 0
                       for y in range(ymin, ymax+1))
        projected = -((-(w+3)) // 12) <= (z+7) // 8
        assert original == projected, (w, z)
        cases += 1
text = (root / 'insider-compiler-appendix.md').read_text()
section = text.split('**代码清单 A-1', 1)[1]
code = re.search(r'```mlir\n(.*?)^```', section, re.S|re.M)[1]
assert code == (root / 'issues/evidence/appendix/dlti-18.mlir').read_text()
result = {
    'status': 'PASS', 'integer_projection_cases': cases,
    'parameter_range': {'w': [-48, 48], 'z': [-48, 48]},
    'scope': 'Finite-grid check for transcription errors; the general equivalence proof is in chapter 15.',
    'appendix_A1': 'Identical to the previously parser/verifier-checked dlti-18.mlir input.',
    'appendix_A1_sha256': hashlib.sha256(code.encode()).hexdigest(),
    'previous_dlti_validation': '../appendix/results.json'
}
(here / 'example-checks.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
print(json.dumps(result, ensure_ascii=False))
