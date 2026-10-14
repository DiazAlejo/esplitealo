"""Round 5 measurements for the pink / green joint and the pink-green edge contrast.  Writes _src/joint.json and the zoomed crops in png/joint/.

    python3 _src/joint_study.py        (run after build_assets.py; needs Xcode 26 for the ictool part)

1. Seam metric (seam.py) on SVG rasters (cairosvg) of three joint treatments at five sizes: butt, under (the hidden strip, the shipped one), gap.
2. The same metric on real ictool renders (Default and Dark): glass off (isolates the anti-aliasing seam from the Liquid Glass lighting) and glass on.
3. Zoomed pixel crops of the joint: round 4's options a and c, and round 5's treatments.
4. Pink / green edge contrast in both greens: flat (WCAG) and as rendered by ictool (Default and Dark).
"""
import io, json, os, sys, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np, cairosvg
from PIL import Image
import core, layered, treatments as T
from layered import Treatment
from core import ROOT, SCH, GREEN, BASIL, PINK, CREAM, contrast
from untrazo import DP, UNDER_D
from seam import joints, profile_residual
from meas import load_srgb, core as erode, region_med, hexs
from pinks import dE, dE00

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, '_work')
SIZES = [1024, 180, 120, 60, 29]


def raster(v, sch, size):
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=core.icon_svg(v, sch).encode(), output_width=size, output_height=size))).convert('RGB')


def bar_joints():
    """Joint positions from the geometry: the pure butt bar rasterised at 1024 (alpha edge = the joint)."""
    L = DP('butt').layers(dict(body='#000', acc='#000'))
    svg = core.svg_doc(1024, 1024, L['bar'], 'bar')
    return joints(Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(), output_width=1024, output_height=1024))).convert('RGBA'))


_REF = {}


def metric_at(img, jt, size):
    """Joint error at a given raster size.  size 1024 and 180/120: the straight-line residual of seam.py.  Every size (and the only one that
    works at 60 and 29 px, where there are too few clean pixels either side of the joint): the largest difference, along the joint, between
    this raster and the seam-free reference (the 1024 render of the shipped mark, box-averaged down to this size), as a share of the
    distance between the pink and the green."""
    if size not in _REF:
        _REF[size] = np.asarray(raster(DP('under'), SCH['light'], 1024).resize((size, size), Image.BOX), float)
    ref = _REF[size]
    a = np.asarray(img.convert('RGB'), float)
    sc = size / 1024.0
    zone = np.zeros((size, size), bool)
    for y, j in jt.items():
        if j is None:
            continue
        for x in j:
            yy, xx = int(round(y * sc)), int(round(x * sc))
            if 1 <= yy < size - 1 and 1 <= xx < size - 1:
                zone[yy - 1:yy + 2, xx - 1:xx + 2] = True
    if size < 120:      # next to the bar's own top and bottom edge the pixel colours differ for reasons other than the joint
        ys = np.where(zone.any(axis=1))[0]
        k = max(1, int(round(0.04 * size)))
        zone[:ys.min() + k] = False
        zone[ys.max() + 1 - k:] = False
    scale = float(np.linalg.norm(np.array([0xEA, 0x5A, 0x78]) - np.array([0x1F, 0x7A, 0x5A])))
    d = np.linalg.norm(a - ref, axis=2)[zone] / scale
    return float(d.max()), float(d.mean())


def line_metric(img, jt, size):
    """Straight-line residual (seam.py) at size >= 120 px (needs a few clean pixels either side of the joint)."""
    sc = size / 1024.0
    jts = {}
    for y, j in jt.items():
        yy = int(round(y * sc))
        if j is not None and 0 <= yy < size:
            jts.setdefault(yy, (j[0] * sc, j[1] * sc))
    ys = sorted(jts)
    m = max(1, int(round(6 * sc)))
    return profile_residual(img, {y: jts[y] for y in ys[m:len(ys) - m]}, 1.0, half=6, side=5)


def svg_metrics(jt):
    out = {}
    for name, v in (('butt', DP('butt')), ('under', DP('under')), ('under-d1', DP('under', d=1.0)), ('gap', DP('gap', d=0.8))):
        out[name] = {}
        for size in SIZES:
            mx, mean = metric_at(raster(v, SCH['light'], size), jt, size)
            out[name][str(size)] = [round(mx, 3), round(mean, 4)]
        out[name]['line1024'] = [round(x, 4) for x in profile_residual(raster(v, SCH['light'], 1024), jt)]     # straight-line residual (seam.py)
    return out


def ictool_metrics(jt):
    out = {}
    P = dict(body=GREEN, acc=PINK)
    cases = (('butt, pink in front', 'butt', False), ('butt, e in front', 'butt', True), ('under, e in front (shipped)', 'under', True))
    for glass_name, gl in (('glass off', dict(body=False, bar=False, dots=False)), ('glass on', T.GLASS_ALL)):
        for cname, joint, front in cases:
            tr = Treatment(cname, T.LIGHT, T.DARKS['cream-e'], T.TINT_FINAL, glass=gl, e_front=front)
            d = os.path.join(WORK, 'j-%s-%s' % (glass_name.replace(' ', ''), cname.split(',')[0] + ('f' if front else 'p')))
            b = layered.write_bundle(DP(joint), P, tr, d, 't')
            for rend, slug in (('Default', 'default'), ('Dark', 'dark')):
                o = os.path.join(d, slug + '.png')
                ok, rc, msg = layered.render(b, rend, o)
                assert ok, msg
                mx, mean = profile_residual(load_srgb(o).convert('RGB'), jt)
                out.setdefault(glass_name, {}).setdefault(cname, {})[slug] = [round(mx, 3), round(mean, 4)]
    return out


# ---------------------------------------------------------------- crops
def crop(im, box, zoom, label=None):
    return im.convert('RGB').crop(box).resize(((box[2] - box[0]) * zoom, (box[3] - box[1]) * zoom), Image.NEAREST)


def amplify(im, jt_img_ref):
    """Seam map: how far each pixel is from the straight blend of pink and green, x4, as a grey-to-red heat (for the zoomed proof)."""
    return im


def crops():
    d = os.path.join(ROOT, 'png', 'joint')
    os.makedirs(d, exist_ok=True)
    LEFT = (292, 452, 352, 512)      # around the upper-left corner of the bar where it meets the left wall (60 x 60 px)
    RIGHT = (676, 452, 736, 512)
    paths = {}
    # round 4 originals (a: Pared a pared, c: Una pared)
    v4 = os.path.join(ROOT, '_round4_compare')
    for key, fn, L, R in (('r4a', '01-pared-a-pared-icon-1024.png', (140, 420, 220, 500), (810, 420, 890, 500)),
                          ('r4c', '03-una-pared-icon-1024.png', (250, 440, 330, 520), (640, 440, 720, 520))):
        if os.path.exists(v4 + fn):
            im = Image.open(v4 + fn)
            crop(im, L, 8).save(os.path.join(d, key + '-left.png'), optimize=True)
            crop(im, R, 8).save(os.path.join(d, key + '-right.png'), optimize=True)
            paths[key] = True
    for key, v in (('butt', DP('butt')), ('under', DP('under')), ('gap', DP('gap', d=0.8))):
        im = raster(v, SCH['light'], 1024)
        crop(im, (284, 456, 344, 516), 10).save(os.path.join(d, key + '-left.png'), optimize=True)
        crop(im, (684, 456, 744, 516), 10).save(os.path.join(d, key + '-right.png'), optimize=True)
        for s in (60, 29):
            sm = raster(v, SCH['light'], s)
            z = 8 if s == 60 else 14
            sm.resize((s * z, s * z), Image.NEAREST).crop((0, int(s * z * 0.33), s * z, int(s * z * 0.66))).save(os.path.join(d, '%s-%d.png' % (key, s)), optimize=True)
    return paths


# ---------------------------------------------------------------- colour
def edge_contrast():
    """Median colours of the e and the pink bar (eroded masks) on real ictool renders, in the recommended and the basil green."""
    out = {}
    for key, green in (('green', GREEN), ('basil', BASIL)):
        P = dict(body=green, acc=PINK)
        lt = dict(T.LIGHT); lt['body'] = green
        tr = Treatment(key, lt, T.DARKS['cream-e'], T.TINT_FINAL, glass=T.GLASS_ALL, e_front=True)
        d = os.path.join(WORK, 'c-' + key)
        b = layered.write_bundle(DP('under'), P, tr, d, 't')
        L = DP('butt').layers(dict(body='#000', acc='#000'))

        def mask(layer):
            svg = core.svg_doc(1024, 1024, L[layer], 'm')
            a = np.array(Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(), output_width=1024, output_height=1024))).convert('RGBA'))[..., 3] > 250
            return erode(a, 13)
        masks = dict(e=mask('body'), pink=mask('bar') | mask('dots'))
        row = {'flat': dict(green=green, pink=PINK, contrast=round(contrast(green, PINK), 2), dE76=round(dE(green, PINK), 1), dE00=round(dE00(green, PINK), 1),
                            e_on_cream=round(contrast(green, CREAM), 2), pink_on_cream=round(contrast(PINK, CREAM), 2))}
        for rend, slug in (('Default', 'default'), ('Dark', 'dark')):
            o = os.path.join(WORK, 'c-%s-%s.png' % (key, slug))
            ok, rc, msg = layered.render(b, rend, o)
            assert ok, msg
            im = np.array(load_srgb(o).convert('RGB')).astype(int)
            cs = {k: region_med(im, m) for k, m in masks.items()}
            cs['ground'] = hexs(np.median(im[480:540, 40:70].reshape(-1, 3), axis=0)) if slug == 'dark' else hexs(np.median(im[40:80, 300:700].reshape(-1, 3), axis=0))
            cs['contrast_pink_e'] = round(contrast(cs['pink'], cs['e']), 2)
            cs['contrast_pink_ground'] = round(contrast(cs['pink'], cs['ground']), 2)
            row[slug] = cs
        out[key] = row
    return out


def main():
    shutil.rmtree(WORK, ignore_errors=True)
    jt = bar_joints()
    res = {'under_d_units': UNDER_D, 'svg': svg_metrics(jt), 'ictool': ictool_metrics(jt), 'edge': edge_contrast()}
    crops()
    shutil.rmtree(WORK, ignore_errors=True)
    json.dump(res, open(os.path.join(HERE, 'joint.json'), 'w'), indent=1)
    print(json.dumps(res, indent=1))


if __name__ == '__main__':
    main()
