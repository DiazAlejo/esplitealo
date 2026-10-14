"""Seam metric (joint_study.metric_at) on Chromium screenshots of the inline SVG (see chromium_page.py). Straight-line residual at 1024, 180 and 120 px (the sizes with clean pixels either side of the joint).  Usage: chromium_measure.py <dir with chromium-<mark>-<size>.png>
Adds a 'chromium' block to joint.json."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
import joint_study as JS
d = sys.argv[1]
jt = JS.bar_joints()
res = {}
for mk, name in (('butt', 'butt'), ('dp', 'under'), ('gap', 'gap')):
    res[name] = {}
    for s in (1024, 180, 120):
        im = Image.open(os.path.join(d, 'chromium-%s-%d.png' % (mk, s))).convert('RGB')
        assert im.size == (s, s), im.size
        mx, mean = JS.line_metric(im, jt, s)
        res[name][str(s)] = [round(mx, 3), round(mean, 4)]
p = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'joint.json')
j = json.load(open(p))
j['chromium'] = res
json.dump(j, open(p, 'w'), indent=1)
print(json.dumps(res))
