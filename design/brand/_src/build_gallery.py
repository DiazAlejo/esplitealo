"""Build ../index.html and ../splash.html: self-contained, offline pages (inline SVG, base64 font and images, no network, no script).

    python3 _src/build_gallery.py       (run build_assets.py and joint_study.py first: the renders and joint.json come from them)
"""
import base64, io, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_base as A
import core, cairosvg
from core import MARK, SCH, SURF, mono_P, ROOT, contrast, Scheme, CREAM, GREEN, BASIL, INK, PINK, NIGHT_GROUND
from gallery_css import CSS as BASE_CSS
from untrazo import DP, DOT_SETTINGS, UNDER_D, START
import treatments as T
from PIL import Image

FONT_B64 = base64.b64encode(open(os.path.join(ROOT, 'fonts', 'Unkempt-Bold-latin.woff2'), 'rb').read()).decode()
HERE = os.path.dirname(os.path.abspath(__file__))
J = json.load(open(os.path.join(HERE, 'joint.json')))
VARS = dict(body='var(--b)', acc='var(--a)')
TINTED = Scheme('tinted', 'Tinted', T.TINT_FINAL['ground'], T.TINT_FINAL['body'], T.TINT_FINAL['bar'])
ONE_INK = Scheme('one-ink', 'One colour', CREAM, INK, INK)
ONE_WHITE = Scheme('one-white', 'One colour', GREEN, '#FFFFFF', '#FFFFFF')
BASIL_S = Scheme('basil', 'Basil', CREAM, BASIL, PINK)
MARKS = {'dp': MARK, 'butt': DP('butt'), 'gap': DP('gap', d=0.8), 'cap': DP('butt', start=-4)}     # cap: the round-4 start cap, for the "why the wall moved" figure


def mark_defs():
    out = ''
    for k, vv in MARKS.items():
        body = re.sub(r'fill="var\((--\w)\)"', r'style="fill:var(\1)"', vv.art(VARS))
        out += '<g id="m-%s">%s</g>' % (k, body)
    for lay in ('h', 'v'):
        L = core.lockup_layout(MARK, lay)
        out += '<g id="wm-%s">%s</g>' % (lay, ''.join('<path class="%s" d="%s"/>' % ('wa' if a else 'wl', d) for d, a in L['parts']))
    out += '<clipPath id="squircle" clipPathUnits="objectBoundingBox"><path d="%s"/></clipPath>' % A.squircle_d()
    return out


def colvars(P):
    return '--b:%s;--a:%s' % (P['body'], P['acc'])


def ico(sch, size=None, cls='', mark='dp', squircle=True):
    st = ('width:%spx;height:%spx;' % (size, size)) if size else ''
    return ('<span class="icow %s" style="%s"><span class="ico%s"><svg viewBox="0 0 1024 1024" width="100%%" height="100%%" style="%s" aria-hidden="true">'
            '<rect width="1024" height="1024" fill="%s"/><use href="#m-%s"/></svg></span></span>') % (cls, st, '' if squircle else ' sq', colvars(sch.P), sch.ground, mark)


def raw_icon(sch, size, mark='dp'):
    return ('<span class="raw" style="width:%spx;height:%spx"><svg viewBox="0 0 1024 1024" width="100%%" height="100%%" style="%s" aria-hidden="true">'
            '<rect width="1024" height="1024" fill="%s"/><use href="#m-%s"/></svg></span>') % (size, size, colvars(sch.P), sch.ground, mark)


def symbol_inline(P, label, cls='symimg', mark='dp'):
    x, y, w, h = core.crop_box(MARKS[mark])
    return ('<svg class="%s" viewBox="%s %s %s %s" style="%s" role="img" aria-label="%s"><use href="#m-%s" width="1024" height="1024"/></svg>' %
            (cls, A.f(x), A.f(y), A.f(w), A.f(h), colvars(P), label, mark))


def lockup_inline(surface, layout, ink=None):
    L = core.lockup_layout(MARK, layout)
    P = mono_P(ink or core.INK) if surface == 'mono' else dict(body=SURF[surface]['body'], acc=SURF[surface]['acc'])
    wl, wa = core.wm_cols(surface, ink)
    st = colvars(P) + ';--wl:%s;--wa:%s' % (wl, wa)
    return ('<svg class="lockimg" viewBox="0 0 %s %s" style="%s" role="img" aria-label="Esplitéalo lockup, %s">'
            '<g transform="translate(%s %s) scale(%.5f) translate(%s %s)"><use href="#m-dp" width="1024" height="1024"/></g>'
            '<use href="#wm-%s" transform="translate(%s %s)"/></svg>') % (
        A.f(L['W']), A.f(L['H']), st, 'horizontal' if layout == 'h' else 'stacked',
        A.f(L['sx']), A.f(L['sy']), L['k'], A.f(-L['bx']), A.f(-L['by']), layout, A.f(L['wm_x']), A.f(L['base_y']))


def wordmark_inline(surface):
    col, acc = core.wm_cols(surface)
    parts, b = A.WM.run(core.TEXT, 200, core.TRACK)
    pad = 24
    w, h = b[2] - b[0] + 2 * pad, b[3] - b[1] + 2 * pad
    return ('<svg class="lockimg" viewBox="0 0 %s %s" style="--wl:%s;--wa:%s" role="img" aria-label="ESPLITÉALO wordmark"><g transform="translate(%s %s)">%s</g></svg>' % (
        A.f(w), A.f(h), col, acc, A.f(pad - b[0]), A.f(pad - b[1]), ''.join('<path class="%s" d="%s"/>' % ('wa' if a else 'wl', d) for d, a in parts)))


# ------------------------------------------------------------------ images
def b64png(path, size=None):
    im = Image.open(path).convert('RGBA')
    if size:
        im = im.resize((size, size), Image.LANCZOS)
    return img_data(im)


def img_data(im):
    b = io.BytesIO()
    im.save(b, 'PNG', optimize=True)
    return 'data:image/png;base64,' + base64.b64encode(b.getvalue()).decode()


def jimg(name, alt, cls='zoom'):
    p = os.path.join(ROOT, 'png', 'joint', name + '.png')
    im = Image.open(p)
    return '<img class="%s" src="%s" alt="%s" width="%d" height="%d">' % (cls, img_data(im), alt, im.width, im.height)


def layer_inline(fn, label):
    s = open(os.path.join(ROOT, 'layers', 'svg', fn)).read()
    s = re.sub(r'^<svg[^>]*?>', '<svg viewBox="0 0 1024 1024" role="img" aria-label="%s">' % label, s.strip(), count=1)
    return re.sub(r'<title>.*?</title>', '', s)


def render_img(path, size, alt, cls=''):
    return '<img class="%s" src="%s" alt="%s" width="%d" height="%d">' % (cls, b64png(path, size), alt, size, size)


def peek(sch, px, zoom, mark='dp'):
    png = cairosvg.svg2png(bytestring=core.icon_svg(MARKS[mark], sch).encode(), output_width=px, output_height=px)
    im = Image.open(io.BytesIO(png)).convert('RGB')
    return img_data(im.resize((px * zoom, px * zoom), Image.NEAREST))


# ------------------------------------------------------------------ home screen
PH_LIGHT = ['#D9DEE6', '#E6DFD2', '#D0DAD4', '#E0D6DE', '#D6DCEA', '#E4E0D6', '#CFD9DF', '#DCD6E6']
PH_DARK = ['#2C323A', '#35322C', '#2B3531', '#352F36', '#2D3340', '#34342E', '#2B3439', '#312D3A']
PH_NAMES = ['Agenda', 'Clima', 'Notas', 'Mapas', 'Fotos', 'Reloj', 'Música', 'Salud', 'Tareas', 'Libros', 'Ajustes', 'Cámara',
            'Correo', 'Radio', 'Archivos', 'Brújula', 'Juegos', 'Podcasts', 'Tienda', 'Recetas', 'Billetera', 'Cuentas', 'Viajes']
GLYPHS = ['<circle cx="12" cy="12" r="6"/>', '<rect x="6" y="6" width="12" height="12" rx="3"/>', '<path d="M12 5 L19 18 H5Z"/>',
          '<path d="M5 8h14M5 12h14M5 16h9" stroke-width="2.2" stroke-linecap="round" fill="none"/>',
          '<circle cx="12" cy="12" r="6.5" fill="none" stroke-width="2.4"/>', '<circle cx="8" cy="12" r="2.4"/><circle cx="16" cy="12" r="2.4"/>']


def glyph_defs():
    return ''.join('<symbol id="gl%d" viewBox="0 0 24 24">%s</symbol>' % (i, g) for i, g in enumerate(GLYPHS))


def placeholder(i, mode):
    bg = PH_LIGHT[i % 8] if mode == 'light' else PH_DARK[i % 8]
    fg = 'rgba(255,255,255,.85)' if mode == 'light' else 'rgba(255,255,255,.38)'
    return ('<span class="icow"><span class="ico ph" style="background:%s"><svg viewBox="0 0 24 24" width="58%%" height="58%%" fill="%s" stroke="%s" aria-hidden="true"><use href="#gl%d" width="24" height="24"/></svg></span></span>'
            % (bg, fg, fg, i % len(GLYPHS)))


def real_icon(mode):
    src = b64png(os.path.join(ROOT, 'layers', 'preview', '%s.png' % ('default' if mode == 'light' else 'dark')), 156)
    return '<span class="icow"><img class="real" src="%s" alt="Esplitéalo icon rendered by Icon Composer" width="52" height="52"></span>' % src


def phone(mode):
    cells, pi = '', 0
    for r in range(5):
        for col in range(4):
            if r == 1 and col == 2:
                cells += '<div class="cell me">%s<span class="lbl">Esplitéalo</span></div>' % real_icon(mode)
            else:
                cells += '<div class="cell">%s<span class="lbl">%s</span></div>' % (placeholder(pi, mode), PH_NAMES[pi % len(PH_NAMES)])
                pi += 1
    dock = ''.join(placeholder(pi + i, mode) for i in range(4))
    return ('<div class="phone %s" id="home-%s" role="img" aria-label="Mock iPhone home screen, %s wallpaper, with the Esplitéalo icon as rendered by Icon Composer">'
            '<div class="notch"></div><div class="stat"><b>9:41</b><i></i></div><div class="grid">%s</div><div class="dock">%s</div><div class="hind"></div></div>') % (mode, mode, mode, cells, dock)


def splash_phone(mode):
    return ('<div class="phone splash %s" role="img" aria-label="Launch screen, %s"><div class="notch"></div>'
            '<div class="splashmark">%s</div><div class="hind"></div></div>') % (mode, mode, lockup_inline(mode, 'v'))


def ladder(sch, bgcls, label, sizes=((180, 'home @3x'), (120, 'home @2x'), (60, 'home pt'), (40, 'spotlight'), (29, 'Settings'))):
    out = '<div class="sizes %s"><span class="lad">%s</span>' % (bgcls, label)
    out += '<figure class="big">%s<figcaption>1024<br><small>scaled</small></figcaption></figure>' % ico(sch, None, cls='bigi')
    for s, note in sizes:
        out += '<figure>%s<figcaption>%d<br><small>%s</small></figcaption></figure>' % (ico(sch, s), s, note)
    return out + '</div>'


CSS_EXTRA = r'''
.peeks{display:flex;gap:14px;flex-wrap:wrap;align-items:flex-start}.peeks figure{max-width:200px}
.zoom{image-rendering:pixelated;display:block;border:1px solid var(--line);max-width:100%;height:auto}
.zgrid{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:14px}
.zc{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:12px;min-width:0}
.zc.rec{border-color:#1F7A5A;box-shadow:0 0 0 2px #1F7A5A33}
.zc h4{margin:0 0 8px}.zc p{font-size:13px;color:var(--ink2);margin:.5em 0 0}
.zpair{display:flex;gap:8px;flex-wrap:wrap}
.nums td:nth-child(n+2){text-align:right;font-variant-numeric:tabular-nums;white-space:nowrap}
.nums th:nth-child(n+2){text-align:right}
.rend{background:linear-gradient(160deg,#6F86A6,#9FB3CE)}.rend figure{width:170px}.rend img{width:170px;height:170px}
.real{display:block;width:100%;height:100%}
.cell .icow:has(.real){filter:none}
.phone.splash.light{background:#FBF7EF}.phone.splash.dark{background:#0F2A21}
.splashmark{position:absolute;left:0;right:0;top:46%;transform:translateY(-50%);padding:0 40px}
.splashmark svg{width:100%;height:auto;display:block}
.phone.splash.light .hind{background:#0007}
.lkp.night{background:#0F2A21}
.cmp3{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:14px}
.tag2{display:inline-block;font-size:12px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;padding:2px 8px;border-radius:10px;background:var(--primary);color:#fff;margin-left:6px;vertical-align:middle}
.tag2.no{background:#8a5a1e}
.sw2{display:inline-block;width:18px;height:18px;border-radius:5px;border:1px solid #0003;vertical-align:-4px;margin-right:6px}
.fl{list-style:none;padding:0;margin:0}.fl li{padding:7px 0;border-bottom:1px solid var(--line);font-size:14px}.fl code{margin-right:6px}
@media (max-width:640px){.rend figure{width:calc(50% - 10px)}.rend img{width:100%;height:auto}}
'''


def f2(v):
    return '%.2f' % v


def build():
    svgm, ij, ed = J['svg'], J['ictool'], J['edge']
    css = (BASE_CSS + CSS_EXTRA).replace('%FONT%', FONT_B64)
    fav = base64.b64encode(core.icon_svg(MARK, SCH['light']).encode()).decode()
    L = lambda a: a.lower()
    nav = ('<nav class="top"><a href="#glance">At a glance</a><a href="#joint">The joint</a><a href="#wall">Right wall</a><a href="#appearances">Appearances</a>'
           '<a href="#sizes">Sizes</a><a href="#colour">Colour</a><a href="#symbols">Symbols</a><a href="#lockups">Lockups</a><a href="#splash">Splash</a>'
           '<a href="#home">Home screen</a><a href="#layers">Layered icon</a><a href="#files">Files</a></nav>')

    def seamrow(label, key):
        m = svgm[key]
        return '<tr><td>%s</td>%s</tr>' % (label, ''.join('<td>%s</td>' % f2(m[str(s)][0]) for s in (1024, 180, 120, 60, 29)))

    def ictool_row(label, gl, case):
        a = ij[gl][case]
        return '<tr><td>%s</td><td>%s</td><td>%s</td></tr>' % (label, f2(a['default'][0]), f2(a['dark'][0]))

    exploded = ''.join('<figure><div class="chk">%s</div><figcaption>%s</figcaption></figure>' % (layer_inline(fn, lbl), cap) for fn, lbl, cap in (
        ('0-background.svg', 'Background layer', '0 · background, cream'),
        ('1-e-body.svg', 'E layer', '1 · the green e (front of the pink)'),
        ('2-division-bar.svg', 'Bar layer', '2 · the pink bar. It runs %s drawing units under the e on each wall; the e hides it' % ('%g' % UNDER_D)),
        ('3-dots.svg', 'Dots layer', '3 · the two dots')))
    names = [('default', 'Default'), ('dark', 'Dark'), ('tinted-light', 'Tinted light'), ('tinted-dark', 'Tinted dark'), ('clear-light', 'Clear light'), ('clear-dark', 'Clear dark')]
    renders = ''.join('<figure>%s<figcaption>%s</figcaption></figure>' % (render_img(os.path.join(ROOT, 'layers', 'preview', n + '.png'), 340, 'ictool render, ' + t), t) for n, t in names)
    renders_b = ''.join('<figure>%s<figcaption>%s, basil</figcaption></figure>' % (render_img(os.path.join(ROOT, 'layers', 'alt-basil', 'preview', n + '.png'), 340, 'ictool render, basil, ' + t), t) for n, t in names[:2])

    lk = lambda surf, lay, cls, lab, ink=None: '<div class="lkp %s">%s<span>%s</span></div>' % (cls, lockup_inline(surf, lay, ink), lab)
    lockups = ''
    for lay, nm in (('h', 'Horizontal'), ('v', 'Stacked')):
        lockups += '<h3 class="lkh">%s</h3><div class="lk">%s%s%s%s</div>' % (
            nm, lk('light', lay, 'paper', 'Colour, on cream'), lk('dark', lay, 'night', 'On dark (#0F2A21): same pink, cream e'),
            lk('mono', lay, 'mono', 'One colour, ink'), lk('mono', lay, 'primary', 'One colour, white (on green)', '#FFFFFF'))

    es_green, es_basil = ed['green'], ed['basil']
    html = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Esplitéalo final logo</title><link rel="icon" href="data:image/svg+xml;base64,{fav}"><style>{css}</style></head><body>
<svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs>{mark_defs()}{glyph_defs()}</defs></svg>
<div class="wrap">
<h1>Esplitéalo · the final logo</h1>
<p class="lead">Round 5. The owner chose <b>Una pared, made into two paredes</b>, with the pink meeting the green cleanly. This page holds the final mark, the proof that the join is clean, and every file to adopt.</p>
{nav}

<section id="glance"><h2>At a glance</h2>
<div class="hero"><div>{raw_icon(SCH['light'], 300)}</div><div>
<p class="what"><b>Dos paredes.</b> The hand-drawn <i>Un trazo</i> e in green, the pink bar running from the inner face of the left wall to the inner face of the right wall, the two dots tucked in (round 4 setting S2).</p>
<ul>
<li><b>What the owner asked for:</b> the pink must <i>end</i> where the green starts. Round 4’s Pared a pared laid the pink over the whole wall (so it covered the green and stuck out past the outline); Una pared began 14 units inside the left wall, on top of the green. Both put pink over green.</li>
<li><b>What is built:</b> the bar is a band minus the e’s own outline, so each colour owns its region and they meet on one line that follows the wall’s real inner curve, wobble included. Cut in code with skia-pathops booleans, not drawn by eye.</li>
<li><b>Anti-aliasing seam:</b> a plain butt of two anti-aliased shapes shows a faint light hair-line (measured: up to {f2(svgm['butt']['1024'][0])} of the way to the ground colour; section “The joint”). I hide it with a {UNDER_D:g}-unit strip of pink <i>under</i> the green (never visible, never over it). That is the only overlap, and it is behind the green.</li>
<li><b>One more change:</b> the e’s stroke now starts {START + 4}° lower, so the right wall exists at the bar’s height (see “Right wall”).</li>
<li>Colours: cream <code>#FBF7EF</code>, green <code>#1F7A5A</code>, coral pink <code>#EA5A78</code>. Dark: same pink, cream e, ground <code>#0F2A21</code>. Liquid Glass on. Basil <code>#145A42</code> only as the documented alternative.</li>
</ul></div></div></section>

<section id="joint"><h2>The joint: pink ends where green starts</h2>
<p class="lead">Zoomed pixels of the upper-left corner of the bar, where it meets the left wall (and the right wall beside it). Round 4’s two candidates on the left, then three treatments of the new bar.</p>
<div class="zgrid">
<div class="zc"><h4>Round 4 · Pared a pared <span class="tag2 no">old</span></h4>{jimg('r4a-left', 'Round 4 option a, joint at the left wall, 8x')}<p>The pink is the whole wall: it has replaced the green across its full thickness and the pink corner sits on the outside edge (8×, 1024 px master).</p></div>
<div class="zc"><h4>Round 4 · Una pared <span class="tag2 no">old</span></h4>{jimg('r4c-left', 'Round 4 option c, joint at the left wall, 8x')}<p>The pink starts 14 units inside the wall with a straight vertical cut: pink on top of the green (8×).</p></div>
<div class="zc"><h4>Butt joint <span class="tag2 no">seam</span></h4>{jimg('butt-left', 'Pure butt joint, 10x')}<p>Exact geometry, but the two anti-aliased edges leave a light hair-line (10×). Worst pixel: {f2(svgm['butt']['1024'][0])} of the way to cream.</p></div>
<div class="zc rec"><h4>Butt + hidden strip <span class="tag2">shipped</span></h4>{jimg('under-left', 'Butt joint with the pink strip hidden under the green, 10x')}<p>Same visible line; the pink runs {UNDER_D:g} units under the green, which is drawn on top. No seam: worst pixel {f2(svgm['under']['1024'][0])}.</p></div>
<div class="zc"><h4>Hair-line gap <span class="tag2 no">rejected</span></h4>{jimg('gap-left', 'Cream hair-line gap, 10x')}<p>A 0.8-unit cream gap. The owner asked for no gap, and it shows a light line up to {f2(svgm['gap']['1024'][0])}. Shown only for the record.</p></div>
</div>
<h3>Right wall (same treatments)</h3>
<div class="zgrid">
<div class="zc">{jimg('butt-right', 'Butt, right wall')}<p>Butt</p></div><div class="zc rec">{jimg('under-right', 'Hidden strip, right wall')}<p>Shipped</p></div><div class="zc">{jimg('gap-right', 'Gap, right wall')}<p>Gap</p></div></div>
<h3>Small sizes (enlarged with nearest-neighbour; the strip of the bar and both joints)</h3>
<div class="zgrid">
<div class="zc"><h4>60 px, butt</h4>{jimg('butt-60', 'Butt at 60 px')}</div><div class="zc rec"><h4>60 px, shipped</h4>{jimg('under-60', 'Shipped at 60 px')}</div>
<div class="zc"><h4>29 px, butt</h4>{jimg('butt-29', 'Butt at 29 px')}</div><div class="zc rec"><h4>29 px, shipped</h4>{jimg('under-29', 'Shipped at 29 px')}</div></div>
<h3>Measured</h3>
<p class="note">Largest deviation, anywhere along the joint, from a seam-free blend of the two colours, as a share of the distance between pink and green (0 = identical to the seam-free reference; a plain butt of two anti-aliased edges leaves about a quarter to a third). SVG rendered by cairosvg at each size.</p>
<div class="tablewrap"><table class="nums"><thead><tr><th>Treatment</th><th>1024</th><th>180</th><th>120</th><th>60</th><th>29</th></tr></thead><tbody>
{seamrow('Butt (pure)', 'butt')}{seamrow('<b>Butt + hidden strip ({:g} u), shipped</b>'.format(UNDER_D), 'under')}{seamrow('Hidden strip 1 u (about 1 px at 1024)', 'under-d1')}{seamrow('Hair-line gap', 'gap')}
</tbody></table></div>
<p class="note">Why {UNDER_D:g}: the strip must be at least a pixel wide at the size being drawn, and it costs nothing because it is under a 131-unit-thick wall. 1 unit is enough at 1024 but not at 180 and below.</p>
<h3>Real browser (Chromium 155, Playwright)</h3>
<p class="note">The same marks drawn inline in Chromium and screenshotted at 1024, 180 and 120 px: the plain butt shows <b>no</b> seam there ({f2(J['chromium']['butt']['1024'][0])} at 1024, same as the shipped {f2(J['chromium']['under']['1024'][0])}), because Chromium resolves coincident edges without leaking the ground colour; the hair-line gap shows ({f2(J['chromium']['gap']['1024'][0])}). So the seam is a property of the rasteriser: cairo (cairosvg) and Apple’s Icon Composer renderer show it, Chromium does not. The hidden strip is therefore insurance that costs nothing, and it never changes how the mark looks anywhere.</p>
<h3>Real Icon Composer renders (ictool 26.3)</h3>
<p class="note">Same metric on the Default and Dark renders. Liquid Glass lights the edges, which adds its own light and dark rim, so the table also shows Liquid Glass off to isolate the anti-aliasing seam.</p>
<div class="tablewrap"><table class="nums"><thead><tr><th>Layout</th><th>Default</th><th>Dark</th></tr></thead><tbody>
<tr><td colspan="3"><b>Liquid Glass off (seam only)</b></td></tr>
{ictool_row('Butt, pink in front', 'glass off', 'butt, pink in front')}{ictool_row('Butt, e in front', 'glass off', 'butt, e in front')}{ictool_row('<b>Hidden strip, e in front (shipped)</b>', 'glass off', 'under, e in front (shipped)')}
<tr><td colspan="3"><b>Liquid Glass on (as shipped; includes the glass rim)</b></td></tr>
{ictool_row('Butt, pink in front', 'glass on', 'butt, pink in front')}{ictool_row('Butt, e in front', 'glass on', 'butt, e in front')}{ictool_row('<b>Hidden strip, e in front (shipped)</b>', 'glass on', 'under, e in front (shipped)')}
</tbody></table></div>
<p class="note">With Liquid Glass off, a butt leaves a seam of 0.30 to 0.41 on the real renders; the hidden strip with the e in front takes it to 0.02. On Dark with glass on the old layout (pink in front, plain butt) shows a dark hair-line between pink and cream (1.19); the shipped one measures 0.05. The 0.36 left on the Default glass render is the glass’s own light rim on the green, not a gap (it is the same with or without the strip). <b>One consequence:</b> in the layered icon the e group is in <i>front</i> of the pink group, so the pink is the one underneath. With the pink in front the glass puts a raised rim round the bar, which makes it look laid on top of the green, the very thing the owner objected to.</p>
</section>

<section id="wall"><h2>Right wall: why the e’s start moved 10°</h2>
<p class="lead">For a bar that meets <i>both</i> walls, the right wall has to be there. In round 4 the stroke started 4° above 3 o’clock and its rounded start ended just above the bar’s lower edge. A bar cut by that outline leaks out of the e’s open mouth (left), or has to stop short with a sliver. Starting the stroke at {START}° below 3 o’clock (a move of {START + 4}° of arc, about 50 units at 1024) puts the wall’s rounded end under the bar, so the bar meets a wall along its whole right end.</p>
<div class="zgrid"><div class="zc"><h4>Round 4 start (−4°)</h4>{raw_icon(SCH['light'], 220, 'cap')}<p>The bar’s lower right corner has no wall to meet: the pink spills out of the mouth and ends on a straight cut.</p></div>
<div class="zc rec"><h4>Final start (+{START}°)</h4>{raw_icon(SCH['light'], 220)}<p>The wall continues under the bar and ends in its round cap. The mouth is still open (flick unchanged).</p></div></div>
</section>

<section id="appearances"><h2>Appearances</h2>
<p class="lead">The 1024 masters (flat SVG renders): light, dark, tinted source and inverted. Real Icon Composer renders are in “Layered icon”.</p>
<div class="row3">
<figure>{ico(SCH['light'], 200)}<figcaption>Light: cream, green, pink</figcaption></figure>
<figure>{ico(SCH['dark'], 200)}<figcaption>Dark: same pink, cream e, #0F2A21</figcaption></figure>
<figure>{ico(TINTED, 200)}<figcaption>Tinted: the greys the system tints (the pink bar and dots are the lighter-than-ground grey)</figcaption></figure>
<figure>{ico(SCH['inverted'], 200)}<figcaption>Inverted: basil ground, cream e, pink</figcaption></figure>
<figure>{ico(ONE_INK, 200)}<figcaption>One colour: ink on cream</figcaption></figure>
<figure>{ico(ONE_WHITE, 200)}<figcaption>One colour: white on green</figcaption></figure>
</div></section>

<section id="sizes"><h2>Small-size ladder</h2>
<p class="note">Drawn live from the SVG in your browser at CSS px = pt. PNGs for every size are in <code>png/ladder/</code>.</p>
{ladder(SCH['light'], 'onlight', 'on light')}{ladder(SCH['dark'], 'ondark', 'on dark')}
<h4>Pixel views (nearest-neighbour)</h4>
<div class="peeks"><figure><img class="zoom" src="{peek(SCH['light'], 29, 6)}" alt="29 px icon enlarged 6 times"><figcaption>29 px ×6</figcaption></figure>
<figure><img class="zoom" src="{peek(SCH['light'], 58, 3)}" alt="58 px icon enlarged 3 times"><figcaption>58 px ×3 (Settings @2×)</figcaption></figure>
<figure><img class="zoom" src="{peek(SCH['light'], 60, 3)}" alt="60 px icon enlarged 3 times"><figcaption>60 px ×3</figcaption></figure></div>
<h4>Favicon-style exports</h4>
<div class="sizes onlight">{''.join('<figure><img class="real" style="width:%dpx;height:%dpx" src="%s" alt="favicon %d"><figcaption>%d</figcaption></figure>' % (n, n, b64png(os.path.join(ROOT, 'png', 'favicon', 'favicon-%d.png' % n)), n, n) for n in (16, 32, 48, 64, 96, 192))}</div>
<p class="note">Also <code>favicon-512.png</code>, <code>favicon.ico</code> (16, 32, 48), <code>apple-touch-icon-180.png</code> (opaque, iOS rounds it) and <code>svg/icon/favicon-rounded.svg</code>.</p>
</section>

<section id="colour"><h2>Colour and the pink-green edge</h2>
<div class="tablewrap"><table class="nums"><thead><tr><th>Green</th><th>Flat contrast pink / green</th><th>Rendered (Default) pink / e</th><th>e on cream</th></tr></thead><tbody>
<tr><td><span class="sw2" style="background:{GREEN}"></span><b>Green #1F7A5A</b> (recommended)</td><td>{es_green['flat']['contrast']}:1</td><td>{es_green['default']['pink']} / {es_green['default']['e']} = {es_green['default']['contrast_pink_e']}:1</td><td>{es_green['flat']['e_on_cream']}:1</td></tr>
<tr><td><span class="sw2" style="background:{BASIL}"></span>Basil #145A42 (alternative)</td><td>{es_basil['flat']['contrast']}:1</td><td>{es_basil['default']['pink']} / {es_basil['default']['e']} = {es_basil['default']['contrast_pink_e']}:1</td><td>{es_basil['flat']['e_on_cream']}:1</td></tr>
</tbody></table></div>
<p>The pink and the green have almost the same lightness (the edge is a hue edge: CIEDE2000 {es_green['flat']['dE00']}). With a clean butt joint that is fine, because the shapes meet on a line instead of overlapping, but if the edge ever needs more separation, basil takes it from {es_green['flat']['contrast']}:1 to {es_basil['flat']['contrast']}:1. On dark the pink against the cream e is {es_green['dark']['contrast_pink_e']}:1 and against the ground {es_green['dark']['contrast_pink_ground']}:1 (real renders); the pink renders {es_green['default']['pink']} in both appearances (Liquid Glass lifts <code>#EA5A78</code> a touch; the lightened <code>#FF8DA4</code> is dropped).</p>
<div class="row3"><figure>{ico(SCH['light'], 160)}<figcaption>Green #1F7A5A</figcaption></figure><figure>{ico(BASIL_S, 160)}<figcaption>Basil #145A42 (alternative)</figcaption></figure></div>
</section>

<section id="symbols"><h2>Symbol only</h2>
<div class="row3">
<figure><div class="monobox">{symbol_inline(dict(body=GREEN, acc=PINK), 'colour')}</div><figcaption>Colour</figcaption></figure>
<figure><div class="monobox dk" style="background:{NIGHT_GROUND}">{symbol_inline(dict(body=CREAM, acc=PINK), 'on dark')}</div><figcaption>On dark</figcaption></figure>
<figure><div class="monobox">{symbol_inline(mono_P(INK), 'mono ink')}</div><figcaption>Mono ink</figcaption></figure>
<figure><div class="monobox dk">{symbol_inline(mono_P('#FFFFFF'), 'mono white')}</div><figcaption>Mono white</figcaption></figure></div>
<p class="note">In one colour the bar fuses into the walls, so the mark is an e with a crossbar and two dots.</p></section>

<section id="lockups"><h2>Lockups</h2>
<p>ESPLITÉALO in Unkempt Bold capitals, accent on the É and the division sign in pink. Outlined paths: no text, no font needed.</p>
{lockups}
<h3 class="lkh">Wordmark</h3><div class="lk"><div class="lkp paper">{wordmark_inline('light')}</div><div class="lkp night">{wordmark_inline('dark')}</div></div></section>

<section id="splash"><h2>Splash</h2><p>Stacked lockup on cream and on the dark ground. Also on its own page: <a href="splash.html">splash.html</a>.</p>
<div class="phones"><div class="pwrap"><div class="plabel">Light</div>{splash_phone('light')}</div><div class="pwrap"><div class="plabel">Dark</div>{splash_phone('dark')}</div></div></section>

<section id="home"><h2>Home screen</h2><p>Mock iPhone home screens (CSS) with the <b>real Icon Composer renders</b> (Default for light, Dark for dark). The other icons are placeholders.</p>
<div class="phones"><div class="pwrap"><div class="plabel">Light</div>{phone('light')}</div><div class="pwrap"><div class="plabel">Dark appearance</div>{phone('dark')}</div></div></section>

<section id="layers"><h2>Layered icon</h2>
<p>Four layers: cream background, green e, pink bar, pink dots. Groups, front to back: <b>E</b> (the e), <b>Division</b> (bar, dots), <b>Background</b>. Liquid Glass on for the e, the bar and the dots, specular automatic, translucency off, neutral shadow 50%.</p>
<div class="expl">{exploded}</div>
<h3>Real renders: Icon Composer 26.3 (<code>ictool</code>), all six appearances, every call exited 0</h3>
<div class="rend">{renders}</div>
<h3>Alternative green (basil), the same bundle</h3><div class="rend">{renders_b}</div>
<p class="note"><b>actool:</b> compiling the .icon into an asset catalog failed in this environment (<i>No simulator runtime version … available to use with iphonesimulator SDK version 23C57</i>; the macOS-platform run crashed in dyld), so no <code>Assets.car</code> was produced. The files are fine for Xcode 26: add <code>Esplitealo.icon</code> to the project and set it as the app icon, or use <code>AppIcon.appiconset</code> (single 1024 size: light, dark, tinted). The Icon Composer window was not opened.</p></section>

<section id="files"><h2>Files to adopt</h2>
<p>Suggested location in the repo: <code>design/brand/</code>.</p>
<ul class="fl">
<li><code>appicon/Esplitealo.icon</code> the Icon Composer bundle (Xcode 26 app icon) · <code>appicon/AppIcon.appiconset</code> the single-size asset catalog set</li>
<li><code>png/icon/appstore-marketing-1024.png</code> App Store icon, 1024, sRGB, no alpha · <code>png/icon/icon-{{light,dark,inverted,tinted-source,one-colour-ink,one-colour-white}}-1024.png</code></li>
<li><code>svg/icon/*.svg</code> masters · <code>svg/symbol/*.svg</code> · <code>svg/lockups/*.svg</code> · <code>svg/wordmark/*.svg</code> · <code>svg/splash/*.svg</code></li>
<li><code>png/ladder/</code> sizes 20 to 1024, light and dark · <code>png/favicon/</code> · <code>png/splash/</code></li>
<li><code>layers/</code> separated layers (svg, png), <code>Esplitealo.icon</code>, six ictool renders, alt-basil · <code>fonts/</code> Unkempt (Apache 2.0)</li>
<li><code>_src/</code> the generator (regenerates everything). See <code>README.md</code> and <code>report.md</code>.</li></ul></section>
</div></body></html>'''
    out = os.path.join(ROOT, 'index.html')
    with open(out, 'w', encoding='utf-8') as fh:
        fh.write(html)
    print('wrote %s (%.0f KB)' % (out, len(html) / 1024))
    build_splash_page()


def build_splash_page():
    css = ('body{margin:0;background:#E9E4D8;font:16px/1.4 -apple-system,system-ui,sans-serif;color:#1E2933}.w{max-width:900px;margin:0 auto;padding:24px 16px 60px}'
           'h1{font-size:22px}.row{display:flex;gap:28px;flex-wrap:wrap;justify-content:center}.wl{fill:var(--wl)}.wa{fill:var(--wa)}'
           '.s{width:300px;height:650px;border-radius:44px;border:7px solid #1b1d20;position:relative;overflow:hidden}.s.light{background:#FBF7EF}.s.dark{background:#0F2A21}'
           '.s .m{position:absolute;left:0;right:0;top:46%;transform:translateY(-50%);padding:0 44px}.s svg{width:100%;height:auto;display:block}'
           '.n{position:absolute;top:9px;left:50%;width:84px;height:24px;margin-left:-42px;background:#000;border-radius:14px}p{text-align:center;color:#5B6670;font-size:13px}')
    html = ('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Esplitéalo splash preview</title><style>%s</style></head><body>'
            '<svg width="0" height="0" style="position:absolute"><defs>%s</defs></svg><div class="w"><h1>Esplitéalo, launch screen preview (stacked lockup)</h1>'
            '<div class="row"><div class="s light"><div class="n"></div><div class="m">%s</div></div><div class="s dark"><div class="n"></div><div class="m">%s</div></div></div>'
            '<p>Light on cream, dark on #0F2A21. The pink is the same coral pink #EA5A78 in both. Files: svg/splash/, png/splash/.</p></div></body></html>') % (
        css, mark_defs(), lockup_inline('light', 'v'), lockup_inline('dark', 'v'))
    with open(os.path.join(ROOT, 'splash.html'), 'w', encoding='utf-8') as fh:
        fh.write(html)


if __name__ == '__main__':
    build()
