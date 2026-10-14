"""Round 5: the one final mark (DP, Dos paredes, joint 'under': pink cut by the green's outline with a hidden strip under the green).
Round-3 builders: the three-colour scheme, icon / symbol / wordmark / lockup SVGs, PNG rendering.

Built on the round-1/2 generator: art_base.py is round 1's art.py, unmodified (the outlined Unkempt Bold wordmark
and the WCAG contrast helper). Everything drawn here is plain filled paths: no masks, no strokes, no text.

The owner fixed the colours for this round: cream is the ground, green is the main colour (main colour 1) and pink is
the accent. Nothing else is used on the mark.
"""
import io, os
import art_base as A
from art_base import contrast, lum, f
from untrazo import DP, DOT_SETTINGS, DEFAULT_DOT
from geom import union

MARK = DP('under')                   # the final mark: butt joint at the geometry level, pink strip hidden under the green
VARIANTS = [MARK]
BY_ID = {v.id: v for v in VARIANTS}

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

# ---------------------------------------------------------------- the three colours
CREAM = '#FBF7EF'            # the app's paper (docs/DESIGN_GUIDE.md)
GREEN = '#1F7A5A'            # the app's primary, the owner's "main color 1"
BASIL = '#145A42'            # round 1's deeper basil, the alternative when contrast needs it
INK = '#1E2933'

# three candidate pinks (hex values, with the reasoning in the report and the gallery)
PINKS = [
    dict(id='coral', name='Coral pink', es='Rosa coral', hex='#EA5A78',
         note='A warm, flamboyán-flower pink, a little red. The only candidate that clears 3:1 on cream and sits well away from the guide’s Rose person colour.'),
    dict(id='rose', name='Rose', es='Rosa', hex='#E0457B',
         note='A deeper, bluer rose. The best contrast on cream of the three (3.7:1), but the closest to the guide’s Rose person colour #C23D7B.'),
    dict(id='bubble', name='Bubblegum', es='Chicle', hex='#F06A9C',
         note='A light, sweet pink. The best against green (1.8:1) but only 2.7:1 on cream, and the closest to Rose’s dark-mode tint #E67FB0.'),
]
PINK = PINKS[0]['hex']
PINK_LIGHTENED = '#FF8DA4'   # round 3's lightened pink for dark (kept only for the comparison)
GREEN_ON_DARK = '#4CC59A'    # the guide's dark-mode primary (mint)
NIGHT_GROUND = '#0F2A21'     # dark appearance ground: a near-black green

PERSON_ROSE, PERSON_ROSE_DARK, WARN, WARN_DARK = '#C23D7B', '#E67FB0', '#C23A1D', '#FF8466'


class Scheme:
    """A coloured use of the mark: ground, the letter (body) and the accent (÷)."""
    def __init__(self, id, name, ground, body, acc, note=''):
        self.id, self.name, self.ground, self.body, self.acc, self.note = id, name, ground, body, acc, note

    @property
    def P(self):
        return dict(body=self.body, acc=self.acc)

    def c_body(self):
        return contrast(self.body, self.ground)

    def c_acc(self):
        return contrast(self.acc, self.ground)

    def c_between(self):
        return contrast(self.body, self.acc)


SCHEMES = [
    Scheme('light', 'Cream, green, pink', CREAM, GREEN, PINK, 'The default: cream ground, the app’s green e, pink ÷.'),
    Scheme('light-basil', 'Cream, basil, pink', CREAM, BASIL, PINK, 'Same with the deeper basil e: more contrast for the letter and against the pink.'),
    Scheme('inverted', 'Basil, cream, pink', BASIL, CREAM, PINK, 'Inverted on the deeper basil (pink dots keep 2.4:1 there, against 1.6:1 on the lighter green).'),
    Scheme('dark', 'Dark, same pink (recommended)', NIGHT_GROUND, CREAM, PINK, 'Dark appearance: near-black green ground, cream e, the same coral pink as in light mode.'),
    Scheme('dark-mint', 'Dark, same pink, mint e', NIGHT_GROUND, GREEN_ON_DARK, PINK, 'Dark appearance keeping a green e (the guide’s dark-mode green) with the same coral pink.'),
    Scheme('dark-lightened', 'Dark, lightened pink (round 3)', NIGHT_GROUND, GREEN_ON_DARK, PINK_LIGHTENED, 'Round 3: mint e and a pink lightened to #FF8DA4.'),
]
SCH = {s.id: s for s in SCHEMES}
DEFAULT = SCH['light']

# surfaces for symbols / lockups (no ground in the file)
SURF = {
    'light': dict(body=GREEN, acc=PINK, wl=GREEN, wa=PINK),
    'dark': dict(body=CREAM, acc=PINK, wl=CREAM, wa=PINK),
}


def mono_P(ink):
    return dict(body=ink, acc=ink)


# ---------------------------------------------------------------- svg helpers
def svg_doc(w, h, body, title, defs=''):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %s %s" width="%s" height="%s" role="img" aria-label="%s">'
            '<title>%s</title>%s%s</svg>\n') % (f(w), f(h), f(w), f(h), title, title, ('<defs>%s</defs>' % defs) if defs else '', body)


def icon_svg(variant, sch, title=None):
    body = '<rect width="1024" height="1024" fill="%s"/>%s' % (sch.ground, variant.art(sch.P))
    return svg_doc(1024, 1024, body, title or 'Esplitéalo app icon, %s, %s (1024 master, full-bleed, opaque)' % (variant.name, sch.name))


def bounds(variant):
    pcs = variant.pieces(dict(body='#000', acc='#000'))
    allp = union(*[p for _, p, _ in pcs])
    return allp.bounds


def crop_box(variant, pad=24):
    x0, y0, x1, y1 = bounds(variant)
    return (x0 - pad, y0 - pad, x1 - x0 + 2 * pad, y1 - y0 + 2 * pad)


def symbol_svg(variant, P, label):
    x, y, w, h = crop_box(variant)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="%s %s %s %s" width="%s" height="%s" role="img" aria-label="Esplitéalo symbol, %s, %s">'
            '<title>Esplitéalo symbol, %s, %s</title>%s</svg>\n') % (f(x), f(y), f(w), f(h), f(w), f(h), variant.name, label, variant.name, label, variant.art(P))


# ---------------------------------------------------------------- wordmark + lockups
TEXT = 'ESPLITÉALO'
TRACK = 0.03


def wm_cols(surface, ink=None):
    if surface == 'mono':
        return ink or INK, ink or INK
    return SURF[surface]['wl'], SURF[surface]['wa']


def wordmark_svg(surface, ink=None):
    size = 200
    pad = 24
    parts, b = A.WM.run(TEXT, size, TRACK)
    w, h = b[2] - b[0] + 2 * pad, b[3] - b[1] + 2 * pad
    col, acc = wm_cols(surface, ink)
    body = ''.join('<path d="%s" fill="%s" transform="translate(%s %s)"/>' % (d, acc if a else col, f(pad - b[0]), f(pad - b[1])) for d, a in parts)
    return svg_doc(w, h, body, 'ESPLITÉALO wordmark (Unkempt Bold, outlined)')


def lockup_layout(variant, layout):
    """Geometry shared by the standalone SVG files and the gallery's <use>-based inline lockups."""
    x, y, bw, bh = crop_box(variant, pad=0)
    pad = 40
    if layout == 'h':
        H = 300
        k = H / bh
        sw = bw * k
        capH = 0.52 * H
        F = capH * A.WM.upm / A.WM.cap
        parts, b = A.WM.run(TEXT, F, TRACK)
        gap = 0.24 * H
        wm_w = b[2] - b[0]
        W = pad + sw + gap + wm_w + pad
        Hh = H + 2 * pad
        sx, sy = pad, pad
        base_y = pad + H / 2 + capH / 2
        wm_x = pad + sw + gap - b[0]
    else:
        H = 340
        k = H / bh
        sw = bw * k
        parts, b = A.WM.run(TEXT, 100, TRACK)
        F = 100 * (1.9 * H) / (b[2] - b[0])
        parts, b = A.WM.run(TEXT, F, TRACK)
        wm_w = b[2] - b[0]
        capH = F * A.WM.cap / A.WM.upm
        W = pad * 2 + max(wm_w, sw)
        gap = 0.2 * H
        Hh = pad + H + gap + capH + pad
        sx, sy = (W - sw) / 2, pad
        base_y = pad + H + gap + capH
        wm_x = (W - wm_w) / 2 - b[0]
    return dict(W=W, H=Hh, sx=sx, sy=sy, k=k, bx=x, by=y, F=F, wm_x=wm_x, base_y=base_y, parts=parts)


def lockup_svg(variant, surface, layout='h', ink=None, inner=False):
    """surface: light | dark | mono (mono uses ink). Returns (svg, (W, H))."""
    L = lockup_layout(variant, layout)
    if surface == 'mono':
        P = mono_P(ink or INK)
    else:
        P = dict(body=SURF[surface]['body'], acc=SURF[surface]['acc'])
    col, acc = wm_cols(surface, ink)
    sym = '<g transform="translate(%s %s) scale(%s) translate(%s %s)">%s</g>' % (f(L['sx']), f(L['sy']), '%.5f' % L['k'], f(-L['bx']), f(-L['by']), variant.art(P))
    wm = ''.join('<path d="%s" fill="%s" transform="translate(%s %s)"/>' % (d, acc if a else col, f(L['wm_x']), f(L['base_y'])) for d, a in L['parts'])
    title = 'Esplitéalo logo lockup, %s, %s' % ('horizontal' if layout == 'h' else 'stacked', variant.name)
    if inner:
        return sym + wm, (L['W'], L['H'])
    return svg_doc(L['W'], L['H'], sym + wm, title), (L['W'], L['H'])


# ---------------------------------------------------------------- PNG
def png_rgb(svg, size=1024):
    import cairosvg
    from PIL import Image
    data = cairosvg.svg2png(bytestring=svg.encode(), output_width=size, output_height=size)
    return Image.open(io.BytesIO(data)).convert('RGB')


def png_rgba(svg, size=1024):
    import cairosvg
    from PIL import Image
    data = cairosvg.svg2png(bytestring=svg.encode(), output_width=size, output_height=size)
    return Image.open(io.BytesIO(data)).convert('RGBA')


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(text)


def splash_svg(variant, surface, W=390, H=844, width_frac=0.62):
    """A launch-screen composition: the stacked lockup centred a little above the middle on the ground (cream or night)."""
    inner, (lw, lh) = lockup_svg(variant, surface, 'v', inner=True)
    k = W * width_frac / lw
    ground = CREAM if surface == 'light' else NIGHT_GROUND
    x, y = (W - lw * k) / 2, H * 0.46 - lh * k / 2
    body = '<rect width="%s" height="%s" fill="%s"/><g transform="translate(%s %s) scale(%.5f)">%s</g>' % (W, H, ground, f(x), f(y), k, inner)
    return svg_doc(W, H, body, 'Esplitéalo launch screen, %s, %s' % (variant.name, surface))
