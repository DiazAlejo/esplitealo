"""Writes _chromium-test.html: the butt and the shipped mark inline at 1024, 180, 120, 60 and 29 px, for measuring the seam in a real browser
(screenshots by Playwright, analysed by chromium_measure.py).  Not part of the deliverable."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_gallery as G
from core import SCH
out = ['<!doctype html><meta charset=utf-8><body style="margin:0;background:#fff"><svg width=0 height=0 style="position:absolute"><defs>%s</defs></svg>' % G.mark_defs()]
for mk in ('butt', 'dp', 'gap'):
    for s in (1024, 180, 120, 60, 29):
        out.append('<div id="t-%s-%d" style="width:%dpx;height:%dpx;display:block;margin:0 0 8px 0">%s</div>' % (mk, s, s, s, G.raw_icon(SCH['light'], s, mk).replace('outline:1px dashed #0004;', '')))
open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '_chromium-test.html'), 'w').write(''.join(out))
