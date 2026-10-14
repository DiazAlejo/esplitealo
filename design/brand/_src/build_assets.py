"""Write every standalone file of round 5 (svg/, png/, layers/, appicon/).  Run from anywhere:

    python3 _src/build_assets.py        (needs fonttools, brotli, cairosvg, pillow, skia-pathops, numpy; Xcode 26 for the layered renders)
    (on macOS: DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib)

The gallery is built separately by build_gallery.py, the measurements by joint_study.py (before the gallery).
"""
import os, sys, io, json, shutil, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import core, layered
import treatments as T
from layered import Treatment
from core import MARK, SCH, SURF, mono_P, write, ROOT, Scheme, CREAM, GREEN, BASIL, INK, PINK, NIGHT_GROUND
from untrazo import DP
from PIL import Image, ImageDraw

TINTED = Scheme('tinted', 'Tinted (grey source)', T.TINT_FINAL['ground'], T.TINT_FINAL['body'], T.TINT_FINAL['bar'], 'The greys the Tinted appearance starts from; the system tints them.')
ONE_INK = Scheme('one-ink', 'One colour, ink on cream', CREAM, INK, INK, 'The whole mark in one ink on the cream ground.')
ONE_WHITE = Scheme('one-white', 'One colour, white on green', GREEN, '#FFFFFF', '#FFFFFF', 'The whole mark in white on the brand green.')
BASIL_LIGHT = Scheme('light-basil', 'Cream, basil, pink', CREAM, BASIL, PINK, 'The documented alternative: basil e (more separation from the pink).')
TREATMENT = Treatment('recommended', T.LIGHT, T.DARKS['cream-e'], T.TINT_FINAL, glass=T.GLASS_ALL, e_front=True)
LADDER = [1024, 512, 256, 180, 167, 152, 120, 87, 80, 76, 60, 58, 40, 29, 20]
FAVICON = [16, 32, 48, 64, 96, 192, 512]


def png_from_svg(svg, size, supersample=4):
    """RGB PNG at size x size: rendered at supersample x and reduced with Lanczos (so the small sizes are clean averages)."""
    import cairosvg
    big = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(), output_width=size * supersample, output_height=size * supersample))).convert('RGBA')
    return big.resize((size, size), Image.LANCZOS) if supersample > 1 else big


def save_rgb(im, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.convert('RGB').save(path, optimize=True)


def build_icons():
    d = os.path.join(ROOT, 'svg', 'icon')
    for sch, nm in ((SCH['light'], 'icon-light'), (SCH['dark'], 'icon-dark'), (SCH['inverted'], 'icon-inverted'), (TINTED, 'icon-tinted-source'),
                    (ONE_INK, 'icon-one-colour-ink'), (ONE_WHITE, 'icon-one-colour-white'), (BASIL_LIGHT, 'icon-light-basil')):
        svg = core.icon_svg(MARK, sch)
        write(os.path.join(d, nm + '.svg'), svg)
        save_rgb(core.png_rgb(svg), os.path.join(ROOT, 'png', 'icon', nm + '-1024.png'))
    # the App Store marketing icon: 1024 x 1024, sRGB, no alpha channel, no rounded corners
    im = core.png_rgb(core.icon_svg(MARK, SCH['light']))
    p = os.path.join(ROOT, 'png', 'icon', 'appstore-marketing-1024.png')
    im.convert('RGB').save(p, optimize=True)
    assert Image.open(p).mode == 'RGB'


def build_symbols():
    d = os.path.join(ROOT, 'svg', 'symbol')
    write(os.path.join(d, 'symbol.svg'), core.symbol_svg(MARK, dict(body=SURF['light']['body'], acc=SURF['light']['acc']), 'colour on light'))
    write(os.path.join(d, 'symbol-on-dark.svg'), core.symbol_svg(MARK, dict(body=SURF['dark']['body'], acc=SURF['dark']['acc']), 'colour on dark'))
    write(os.path.join(d, 'symbol-mono-ink.svg'), core.symbol_svg(MARK, mono_P(INK), 'one colour, ink'))
    write(os.path.join(d, 'symbol-mono-white.svg'), core.symbol_svg(MARK, mono_P('#FFFFFF'), 'one colour, white'))


def build_lockups():
    d = os.path.join(ROOT, 'svg', 'lockups')
    for layout, ln in (('h', 'horizontal'), ('v', 'stacked')):
        for surf, suffix, ink in (('light', '', None), ('dark', '-on-dark', None), ('mono', '-mono-ink', None), ('mono', '-mono-white', '#FFFFFF')):
            s, _ = core.lockup_svg(MARK, surf, layout, ink=ink)
            write(os.path.join(d, 'lockup-%s%s.svg' % (ln, suffix)), s)
    for nm, surf, ink in (('wordmark.svg', 'light', None), ('wordmark-on-dark.svg', 'dark', None), ('wordmark-mono-ink.svg', 'mono', None), ('wordmark-mono-white.svg', 'mono', '#FFFFFF')):
        write(os.path.join(ROOT, 'svg', 'wordmark', nm), core.wordmark_svg(surf, ink=ink))


def build_splash():
    import cairosvg
    for surf in ('light', 'dark'):
        s = core.splash_svg(MARK, surf)
        write(os.path.join(ROOT, 'svg', 'splash', 'splash-%s.svg' % surf), s)
        p = os.path.join(ROOT, 'png', 'splash', 'splash-%s-1170x2532.png' % surf)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        cairosvg.svg2png(bytestring=s.encode(), write_to=p, output_width=1170, output_height=2532)


def rounded(im, frac=0.2237):
    """Transparent corners (iOS's rounded square, a circular-corner approximation) for the favicon-style exports."""
    n = im.size[0]
    k = 4
    m = Image.new('L', (n * k, n * k), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, n * k - 1, n * k - 1), radius=int(n * k * frac), fill=255)
    out = im.convert('RGBA')
    out.putalpha(m.resize((n, n), Image.LANCZOS))
    return out


def build_ladders():
    for sch, tag in ((SCH['light'], 'light'), (SCH['dark'], 'dark')):
        svg = core.icon_svg(MARK, sch)
        big = png_from_svg(svg, 2048, 1)
        for n in LADDER:
            im = big if n == 2048 else big.resize((n, n), Image.LANCZOS)
            save_rgb(im, os.path.join(ROOT, 'png', 'ladder', 'icon-%s-%d.png' % (tag, n)))
    svg = core.icon_svg(MARK, SCH['light'])
    big = png_from_svg(svg, 2048, 1)
    os.makedirs(os.path.join(ROOT, 'png', 'favicon'), exist_ok=True)
    for n in FAVICON:
        rounded(big.resize((n, n), Image.LANCZOS)).save(os.path.join(ROOT, 'png', 'favicon', 'favicon-%d.png' % n), optimize=True)
    # apple-touch-icon: opaque full-bleed (iOS rounds it)
    save_rgb(big.resize((180, 180), Image.LANCZOS), os.path.join(ROOT, 'png', 'favicon', 'apple-touch-icon-180.png'))
    ico_src = rounded(big.resize((256, 256), Image.LANCZOS))
    ico_src.save(os.path.join(ROOT, 'png', 'favicon', 'favicon.ico'), sizes=[(16, 16), (32, 32), (48, 48)])
    # a rounded vector favicon, handy for <link rel="icon" type="image/svg+xml">
    body = '<rect width="1024" height="1024" rx="229" ry="229" fill="%s"/>%s' % (CREAM, MARK.art(SCH['light'].P))
    write(os.path.join(ROOT, 'svg', 'icon', 'favicon-rounded.svg'), core.svg_doc(1024, 1024, body, 'Esplitéalo favicon (rounded square)'))


def build_appicon(layers_dir):
    """AppIcon.appiconset (single 1024 size: light, dark, tinted) for an asset catalog, plus an Xcode 26 .icon copy."""
    d = os.path.join(ROOT, 'appicon', 'AppIcon.appiconset')
    if os.path.isdir(d):
        shutil.rmtree(d)
    os.makedirs(d)
    for sch, nm in ((SCH['light'], 'AppIcon-1024.png'), (SCH['dark'], 'AppIcon-dark-1024.png'), (TINTED, 'AppIcon-tinted-1024.png')):
        save_rgb(core.png_rgb(core.icon_svg(MARK, sch)), os.path.join(d, nm))
    contents = {'images': [
        {'filename': 'AppIcon-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'},
        {'appearances': [{'appearance': 'luminosity', 'value': 'dark'}], 'filename': 'AppIcon-dark-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'},
        {'appearances': [{'appearance': 'luminosity', 'value': 'tinted'}], 'filename': 'AppIcon-tinted-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
        'info': {'author': 'xcode', 'version': 1}}
    with open(os.path.join(d, 'Contents.json'), 'w') as fh:
        json.dump(contents, fh, indent=2)
        fh.write('\n')
    bundle = os.path.join(layers_dir, 'Esplitealo.icon')
    dst = os.path.join(ROOT, 'appicon', 'Esplitealo.icon')
    if os.path.isdir(dst):
        shutil.rmtree(dst)
    shutil.copytree(bundle, dst)


def build_layers():
    P = dict(body=GREEN, acc=PINK)
    out = os.path.join(ROOT, 'layers')
    facts = layered.build(MARK, P, TREATMENT, out, 'Esplitealo')
    # the documented alternative: the same icon with the basil e
    tr_b = Treatment('basil', T.LIGHT_BASIL, T.DARKS['cream-e'], T.TINT_FINAL, glass=T.GLASS_ALL, e_front=True)
    facts_b = layered.build(MARK, dict(body=BASIL, acc=PINK), tr_b, os.path.join(ROOT, 'layers', 'alt-basil'), 'Esplitealo-basil')
    return facts, facts_b


if __name__ == '__main__':
    build_icons()
    build_symbols()
    build_lockups()
    build_splash()
    build_ladders()
    facts, facts_b = build_layers()
    build_appicon(os.path.join(ROOT, 'layers'))
    print(json.dumps({'main': [facts.get('ictool'), facts.get('ictool_log')], 'basil': [facts_b.get('ictool'), facts_b.get('ictool_log')]}, indent=1))
    print('assets built')
