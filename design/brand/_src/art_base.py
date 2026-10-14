"""Original SVG artwork for the five Esplitéalo logo concepts.

Everything is drawn here as code. The raccoon geometry is a simplified, icon-grade
re-draw of Chavito from data/esplitealo-html-bilingual/_src/mascot.js (same shapes
and palette family), not a copy of any other app's artwork.

The wordmark ESPLITÉALO is converted to outlines from Unkempt Bold (Apache-2.0,
Google Fonts), so the standalone SVGs have no font dependency.
"""
import math, os
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.recordingPen import DecomposingRecordingPen, RecordingPen
from fontTools.pens.boundsPen import BoundsPen

HERE = os.path.dirname(os.path.abspath(__file__))
FONT_PATH = os.path.join(HERE, '..', 'fonts', 'Unkempt-Bold.ttf')


def f(v):
    s = ('%.1f' % v).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


# ---------------------------------------------------------------- palette
PAPER = '#FBF7EF'; INK = '#1E2933'; BASIL = '#1F7A5A'; BASIL_D = '#145A42'
GOLD = '#F2B84B'; GOLD_D = '#C99A2E'; AMBER = '#B87A00'
ICON_GREEN = BASIL_D        # existing deep basil; the grey fur reads at 3.3:1 on it (2.1:1 on basil)
NIGHT = '#0D2A20'           # proposed: dark-appearance icon ground
FUR = '#9AA5B1'; FUR_D = '#5A6470'; MASK = '#2B333D'; CREAM = '#F5EEDF'; PINK = '#F0A9A3'
MINT = '#4CC59A'; GOLD_L = '#F5C766'


def lum(hexc):
    h = hexc.lstrip('#')
    r, g, b = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    r, g, b = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in (r, g, b)]
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = lum(a), lum(b)
    if la < lb:
        la, lb = lb, la
    return (la + 0.05) / (lb + 0.05)


# ---------------------------------------------------------------- font -> outlines
class Wordmark:
    def __init__(self, path=FONT_PATH):
        self.font = TTFont(path)
        self.gs = self.font.getGlyphSet()
        self.cmap = self.font.getBestCmap()
        self.upm = self.font['head'].unitsPerEm
        self.cap = self.font['OS/2'].sCapHeight

    def run(self, text, size, tracking=0.0):
        """Return (parts, bounds). parts = [(pathdata, is_accent)], baseline at y=0, y grows down."""
        s = size / self.upm
        x = 0.0
        parts = []
        bp = BoundsPen(self.gs)
        for ch in text:
            gname = self.cmap[ord(ch)]
            rec = DecomposingRecordingPen(self.gs)
            self.gs[gname].draw(rec)
            contours, cur = [], []
            for op, args in rec.value:
                cur.append((op, args))
                if op in ('closePath', 'endPath'):
                    contours.append(cur)
                    cur = []
            accent_idx = set()
            if gname == 'Eacute':
                ys = []
                for i, c in enumerate(contours):
                    b = BoundsPen(self.gs)
                    r = RecordingPen(); r.value = c; r.replay(b)
                    ys.append((b.bounds[1], i))
                accent_idx = {max(ys)[1]}      # the acute is the contour that sits highest
            groups = {False: [], True: []}
            for i, c in enumerate(contours):
                groups[i in accent_idx].append(c)
            for acc, cs in groups.items():
                if not cs:
                    continue
                sp = SVGPathPen(self.gs, ntos=f)
                tp = TransformPen(sp, (s, 0, 0, -s, x, 0))
                r = RecordingPen(); r.value = [o for c in cs for o in c]; r.replay(tp)
                parts.append((sp.getCommands(), acc))
                r.replay(TransformPen(bp, (s, 0, 0, -s, x, 0)))
            x += self.gs[gname].width * s + tracking * size
        xmin, ymin, xmax, ymax = bp.bounds
        return parts, (xmin, ymin, xmax, ymax)


WM = Wordmark()


# ---------------------------------------------------------------- shared shapes
def zigzag_poly(x0, x1, y, depth, teeth, up=False):
    """Receipt-edge teeth from x0 to x1 along y. Returns list of points."""
    pts = []
    w = (x1 - x0) / teeth
    for i in range(teeth + 1):
        x = x0 + w * i
        pts.append((x, y + (0 if i % 2 == 0 else (-depth if up else depth))))
    return pts


def pts(points):
    return ' '.join('%s,%s' % (f(x), f(y)) for x, y in points)


# raccoon (200-box geometry from the mascot), simplified for icon use
def raccoon(p, zig=False):
    """Chavito's face. p = role->colour. zig=True makes the mask's lower edge a torn-receipt edge."""
    if zig:
        edge = ''.join('L%s %s' % (f(164 - 12.8 * i), 124 + (10 if i % 2 else 0)) for i in range(0, 11))
        mask = 'M36 106 C48 88 80 86 100 99 C120 86 152 88 164 106 ' + edge + ' L36 106Z'
    else:
        mask = 'M36 106 C48 88 80 86 100 99 C120 86 152 88 164 106 C162 130 134 136 117 124 C108 119 92 119 83 124 C66 136 38 130 36 106Z'
    ex, er, pr = (72, 128), 13.5, 7.2
    eyes = ''.join(
        '<circle cx="%s" cy="109" r="%s" fill="%s"/><circle cx="%s" cy="109" r="%s" fill="%s"/>'
        '<circle cx="%s" cy="106" r="2.4" fill="%s"/>' % (c, er, p['sclera'], c + 1, pr, p['pupil'], c + 3, p['sclera'])
        for c in ex)
    return (
        '<circle cx="52" cy="62" r="23" fill="%(fur)s"/><circle cx="54" cy="65" r="12" fill="%(furD)s"/>'
        '<circle cx="148" cy="62" r="23" fill="%(fur)s"/><circle cx="146" cy="65" r="12" fill="%(furD)s"/>'
        '<path d="M34 112 L12 130 L38 142Z" fill="%(fur)s"/><path d="M166 112 L188 130 L162 142Z" fill="%(fur)s"/>'
        '<path d="M28 116 C28 72 62 48 100 48 C138 48 172 72 172 116 C172 152 142 174 100 174 C58 174 28 152 28 116Z" fill="%(fur)s"/>'
        '<path d="M91 50 L109 50 L106 84 L94 84Z" fill="%(furD)s"/>'
        '<ellipse cx="72" cy="87" rx="15" ry="8" fill="%(cream)s"/><ellipse cx="128" cy="87" rx="15" ry="8" fill="%(cream)s"/>'
        '<ellipse cx="100" cy="146" rx="35" ry="26" fill="%(cream)s"/>'
        '<path d="' % p + mask + '" fill="%(mask)s"/>' % p + eyes +
        '<path d="M89 130 C89 124 111 124 111 130 C111 136 105 140 100 141 C95 140 89 136 89 130Z" fill="%(nose)s"/>'
        '<path d="M100 141 L100 151" stroke="%(nose)s" stroke-width="3.6" stroke-linecap="round"/>'
        '<path d="M87 151 Q100 164 113 151" fill="none" stroke="%(nose)s" stroke-width="4.4" stroke-linecap="round"/>' % p
    )


def rpal(fur, furD, mask, cream, sclera, pupil, nose=None):
    return dict(fur=fur, furD=furD, mask=mask, cream=cream, sclera=sclera, pupil=pupil, nose=nose or mask)


RP_LIGHT = rpal(FUR, FUR_D, MASK, CREAM, '#FFFFFF', MASK)
RP_DARK = rpal('#8F9AA6', '#566069', '#161C22', '#E6DCC6', '#F4F1EA', '#161C22')
RP_TINT = rpal('#D6D6D6', '#8A8A8A', '#262626', '#FFFFFF', '#FFFFFF', '#262626')
RP_MONO = rpal('#fff', '#000', '#000', '#fff', '#fff', '#000')
RP_COIN = rpal('#B9791B', '#8A5610', '#4A2E05', '#FFE6A6', '#FFF3CF', '#4A2E05')
RP_COIN_D = rpal('#A06A18', '#6E450D', '#2E1C03', '#F1D38A', '#FFF0C6', '#2E1C03')
RP_COIN_T = rpal('#9A9A9A', '#6B6B6B', '#1F1F1F', '#FFFFFF', '#FFFFFF', '#1F1F1F')
RP_COIN_MONO = rpal('#fff', '#000', '#000', '#000', '#fff', '#000')


# ---------------------------------------------------------------- concepts
# Each concept exposes:
#   icon(variant, uid)        -> 1024x1024 body incl. full-bleed background  (variant: light|dark|tinted)
#   art(surface, uid)         -> bare symbol in 1024 coords (surface: light|dark|mono)
#   box                       -> (x, y, w, h) crop of the bare symbol
# 'mono' art is drawn in #fff (solid) / #000 (cut) for use inside an SVG mask.

class Concept:
    id = ''; slug = ''; name = ''; box = (0, 0, 1024, 1024)


# ---- 1. Chavito cara (raccoon face, mask = torn receipt edge)
class C1(Concept):
    id = 'c1'; slug = '01-chavito-cara'; name = 'Chavito, cara'
    box = (116, 218, 792, 594)

    def _head(self, p):
        return '<g transform="translate(512 515) scale(4.4) translate(-100 -106.5)">' + raccoon(p, zig=True) + '</g>'

    def icon(self, v, uid):
        bg, p = {'light': (ICON_GREEN, RP_LIGHT), 'dark': (NIGHT, RP_DARK), 'tinted': ('#121212', RP_TINT)}[v]
        return '<rect width="1024" height="1024" fill="%s"/>' % bg + self._head(p)

    def art(self, surface, uid):
        p = {'light': RP_LIGHT, 'dark': RP_DARK, 'mono': RP_MONO}[surface]
        return self._head(p)


# ---- 2. Recibo partido (receipt torn in two)
class C2(Concept):
    id = 'c2'; slug = '02-recibo-partido'; name = 'Recibo partido'
    box = (180, 120, 664, 790)
    X0, X1, Y0, Y1 = 292, 732, 196, 828
    TEAR = [(512, 150), (534, 262), (494, 330), (532, 402), (492, 470), (530, 540), (496, 608), (530, 678), (494, 746), (512, 900)]

    def _receipt_pts(self):
        top = zigzag_poly(self.X0, self.X1, self.Y0, 26, 11)
        bot = zigzag_poly(self.X1, self.X0, self.Y1, 26, 11)
        return top + bot

    def _half(self, side, uid, p, idx):
        T = self.TEAR
        if side == 'L':
            poly = [(0, 0)] + T + [(0, 1024)]
            tf = 'translate(-34 20) rotate(-4 512 512)'
            barc = p['bar']
        else:
            poly = [(1024, 0)] + T + [(1024, 1024)]
            tf = 'translate(34 -20) rotate(4 512 512)'
            barc = p['bar2']
        cid = '%s-clip%s' % (uid, side)
        rows = ''
        for i, y in enumerate((300, 366, 432, 498)):
            w = (236, 200, 252, 168)[i]
            rows += '<rect x="334" y="%d" width="%d" height="22" rx="11" fill="%s"/>' % (y, w, p['line'])
            rows += '<rect x="628" y="%d" width="64" height="22" rx="11" fill="%s"/>' % (y, p['line'])
        head = '<rect x="334" y="246" width="190" height="26" rx="13" fill="%s"/>' % p['head'] + '<rect x="574" y="246" width="118" height="26" rx="13" fill="%s"/>' % p['head']
        total = '<rect x="334" y="600" width="358" height="76" rx="16" fill="%s"/>' % barc
        edge = ('<g clip-path="url(#%s-rc)"><polyline points="%s" fill="none" stroke="%s" stroke-width="12" stroke-linejoin="round"/></g>' % (uid + side, pts(T), p['edge'])) if p['edge'] else ''
        stroke = ' stroke="%s" stroke-width="14" stroke-linejoin="round"' % p['outline'] if p['outline'] else ''
        return ('<clipPath id="%s"><polygon points="%s"/></clipPath><clipPath id="%s-rc"><polygon points="%s"/></clipPath>' % (cid, pts(poly), uid + side, pts(self._receipt_pts())) +
                '<g transform="%s"><g clip-path="url(#%s)">' % (tf, cid) +
                '<polygon points="%s" fill="%s"%s/>' % (pts(self._receipt_pts()), p['paper'], stroke) +
                head + rows + total + edge + '</g></g>')

    def _art(self, p, uid):
        return '<g transform="translate(512 512) scale(1.1) translate(-512 -512)">' + self._half('L', uid, p, 0) + self._half('R', uid, p, 1) + '</g>'

    PAL = {
        'light': dict(paper='#FFFFFF', line='#CFC6B2', head='#2B333D', bar=BASIL, bar2=GOLD, edge='#D9D0BC', outline='#1E2933'),
        'icon': dict(paper=PAPER, line='#CFC6B2', head='#2B333D', bar=BASIL, bar2=GOLD, edge='#D9D0BC', outline=None),
        'dark': dict(paper='#EDE6D6', line='#B7AE9A', head='#3A444E', bar=MINT, bar2=GOLD_L, edge='#C9C0AB', outline=None),
        'tinted': dict(paper='#F2F2F2', line='#BDBDBD', head='#6E6E6E', bar='#8A8A8A', bar2='#FFFFFF', edge='#CFCFCF', outline=None),
        'mono': dict(paper='#fff', line='#000', head='#000', bar='#000', bar2='#000', edge=None, outline=None),
    }

    def icon(self, v, uid):
        bg = {'light': INK, 'dark': '#0A0E12', 'tinted': '#121212'}[v]
        return '<rect width="1024" height="1024" fill="%s"/>' % bg + self._art(self.PAL['icon' if v == 'light' else v], uid)

    def art(self, surface, uid):
        return self._art(self.PAL[surface], uid)


# ---- 3. Centavo (coin with Chavito)
class C3(Concept):
    id = 'c3'; slug = '03-centavo'; name = 'Centavo'
    box = (176, 176, 672, 700)

    def _coin(self, v, uid):
        c = {
            'light': dict(edge=GOLD_D, face=GOLD, ring='#C99A2E', rp=RP_COIN),
            'dark': dict(edge='#9C7420', face='#E5AA3A', ring='#9C7420', rp=RP_COIN_D),
            'tinted': dict(edge='#6B6B6B', face='#E8E8E8', ring='#8A8A8A', rp=RP_COIN_T),
            'mono': dict(edge='#fff', face='#fff', ring='#000', rp=RP_COIN_MONO),
        }[v]
        out = ''
        if v != 'mono':
            out += '<circle cx="512" cy="544" r="330" fill="%s"/>' % c['edge']
        else:
            out += '<circle cx="512" cy="512" r="330" fill="#fff"/>'
        if v != 'mono':
            out += '<circle cx="512" cy="512" r="330" fill="%s"/>' % c['face']
        out += '<circle cx="512" cy="512" r="288" fill="none" stroke="%s" stroke-width="12" stroke-dasharray="3 22.6" stroke-linecap="round"/>' % c['ring']
        out += '<g transform="translate(512 526) scale(2.5) translate(-100 -106.5)">' + raccoon(c['rp'], zig=False) + '</g>'
        return out

    def icon(self, v, uid):
        bg = {'light': ICON_GREEN, 'dark': NIGHT, 'tinted': '#121212'}[v]
        return '<rect width="1024" height="1024" fill="%s"/>' % bg + self._coin(v, uid)

    def art(self, surface, uid):
        return self._coin(surface, uid)


# ---- 4. e dividida (an "e" whose crossbar is a divide sign)
class C4(Concept):
    id = 'c4'; slug = '04-e-dividida'; name = 'e dividida'
    box = (150, 150, 724, 724)
    R, SW = 288, 124

    def _e(self, col, dots, uid):
        R, SW, cx, cy = self.R, self.SW, 512, 506
        a = math.radians(42)
        tx, ty = cx + R * math.cos(a), cy + R * math.sin(a)
        d = 'M%s %s H%s A%s %s 0 1 0 %s %s' % (f(cx - R), f(cy), f(cx + R), R, R, f(tx), f(ty))
        out = '<path d="%s" fill="none" stroke="%s" stroke-width="%d" stroke-linecap="round" stroke-linejoin="round"/>' % (d, col, SW)
        for dy in (-148, 148):
            out += '<circle cx="%d" cy="%d" r="50" fill="%s"/>' % (cx, cy + dy, dots)
        return out

    def icon(self, v, uid):
        bg, col, dots = {'light': (GOLD, BASIL_D, BASIL_D), 'dark': ('#12171B', GOLD_L, MINT), 'tinted': ('#121212', '#F0F0F0', '#9A9A9A')}[v]
        return '<rect width="1024" height="1024" fill="%s"/>' % bg + self._e(col, dots, uid)

    def art(self, surface, uid):
        col, dots = {'light': (BASIL, GOLD), 'dark': (GOLD_L, MINT), 'mono': ('#fff', '#fff')}[surface]
        return self._e(col, dots, uid)


# ---- 5. É (wordmark-led: the first letter of the wordmark, accent in gold, torn-receipt edge)
class C5(Concept):
    id = 'c5'; slug = '05-e-acento'; name = 'É de Esplitéalo'; wordmark_led = True

    def __init__(self):
        parts, b = WM.run('É', 860)
        self.parts, self.b = parts, b
        w, h = b[2] - b[0], b[3] - b[1]
        self.gw, self.gh = w, h
        # place glyph block centred horizontally, in the space above the receipt edge
        self.gx = 512 - (b[0] + w / 2)
        self.gy = 410 - (b[1] + h / 2)       # baseline y so the block is centred on y=410
        sx0 = 512 - w * 0.62
        self.box = (sx0, self.gy + b[1] - 20, w * 1.24, h + 20 + 150)

    def _glyph(self, col, acc):
        out = ''
        for d, is_acc in self.parts:
            out += '<path d="%s" fill="%s" transform="translate(%s %s)"/>' % (d, acc if is_acc else col, f(self.gx), f(self.gy))
        return out

    def _edge(self, col, full):
        y = self.gy + self.b[3] + 70
        if full:
            x0, x1, bottom = -10, 1034, 1034
        else:
            half = self.box[2] / 2
            x0, x1, bottom = 512 - half, 512 + half, y + 90
        n = 14 if full else 10
        top = zigzag_poly(x0, x1, y, 0, n)
        w = (x1 - x0) / n
        poly = [(x0, bottom)] + [(x0 + w * i, y + (40 if i % 2 else 0)) for i in range(n + 1)] + [(x1, bottom)]
        if not full:
            poly = [(x0 + w * i, y + (30 if i % 2 else 0)) for i in range(n + 1)] + [(x1, y + 60)]
            poly = [(x0, y + 60)] + poly[:-1] + [(x1, y + 60)]
            # slim torn strip: teeth on top, flat bottom edge
            strip = [(x0 + w * i, y + (30 if i % 2 else 0)) for i in range(n + 1)] + [(x1, y + 96), (x0, y + 96)]
            return '<polygon points="%s" fill="%s"/>' % (pts(strip), col)
        return '<polygon points="%s" fill="%s"/>' % (pts(poly), col)

    def icon(self, v, uid):
        bg, col, acc, edge = {
            'light': (PAPER, BASIL, AMBER, BASIL),
            'dark': ('#14181C', MINT, GOLD_L, '#2E9C77'),
            'tinted': ('#121212', '#F2F2F2', '#B0B0B0', '#6A6A6A'),
        }[v]
        return '<rect width="1024" height="1024" fill="%s"/>' % bg + self._glyph(col, acc) + self._edge(edge, True)

    def art(self, surface, uid):
        col, acc, edge = {'light': (BASIL, AMBER, BASIL), 'dark': (MINT, GOLD_L, '#2E9C77'), 'mono': ('#fff', '#fff', '#fff')}[surface]
        return self._glyph(col, acc) + self._edge(edge, False)


CONCEPTS = [C1(), C2(), C3(), C4(), C5()]


# ---------------------------------------------------------------- assembly helpers
SQUIRCLE_PATH = None


def squircle_d(n=5.0, N=240):
    out = []
    for k in range(N):
        t = 2 * math.pi * k / N
        c, s = math.cos(t), math.sin(t)
        x = 0.5 + 0.5 * math.copysign(abs(c) ** (2 / n), c)
        y = 0.5 + 0.5 * math.copysign(abs(s) ** (2 / n), s)
        out.append('%s%.4f %.4f' % ('M' if k == 0 else 'L', x, y))
    return ''.join(out) + 'Z'


def svg_doc(w, h, body, title, defs='', extra=''):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %s %s" width="%s" height="%s" role="img" aria-label="%s">'
            '<title>%s</title>%s%s</svg>\n') % (f(w), f(h), f(w), f(h), title, title, ('<defs>%s</defs>' % defs) if defs else '', body)


def icon_svg(c, v):
    uid = '%s-%s' % (c.id, v)
    return svg_doc(1024, 1024, c.icon(v, uid), 'Esplitéalo app icon, %s, concept %s (1024 master, full-bleed, no transparency)' % (v, c.name))


def symbol_svg(c, surface, ink=None):
    uid = '%s-sym-%s' % (c.id, surface)
    x, y, w, h = c.box
    if surface == 'mono':
        ink = ink or INK
        mid = uid + '-m'
        body = ('<mask id="%s" maskUnits="userSpaceOnUse" x="%s" y="%s" width="%s" height="%s">%s</mask>'
                '<rect x="%s" y="%s" width="%s" height="%s" fill="%s" mask="url(#%s)"/>') % (
            mid, f(x), f(y), f(w), f(h), c.art('mono', uid), f(x), f(y), f(w), f(h), ink, mid)
        return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="%s %s %s %s" width="%s" height="%s" role="img" aria-label="Esplitéalo symbol, one colour, %s">'
                '<title>Esplitéalo symbol, one colour, %s</title>%s</svg>\n') % (f(x), f(y), f(w), f(h), f(w), f(h), c.name, c.name, body)
    body = c.art(surface, uid)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="%s %s %s %s" width="%s" height="%s" role="img" aria-label="Esplitéalo symbol, %s">'
            '<title>Esplitéalo symbol, %s</title>%s</svg>\n') % (f(x), f(y), f(w), f(h), f(w), f(h), c.name, c.name, body)


WM_COL = {'light': (BASIL_D, AMBER), 'dark': (PAPER, GOLD_L), 'mono': ('#fff', '#fff')}
TEXT = 'ESPLITÉALO'
TRACK = 0.03


def wordmark_parts(size, surface, ox=0, oy=0):
    parts, b = WM.run(TEXT, size, TRACK)
    col, acc = WM_COL[surface]
    out = ''.join('<path d="%s" fill="%s" transform="translate(%s %s)"/>' % (d, acc if a else col, f(ox), f(oy)) for d, a in parts)
    return out, b


def wordmark_svg(surface, ink=None, uid='wm'):
    size = 200
    parts, b = WM.run(TEXT, size, TRACK)
    pad = 24
    w, h = b[2] - b[0] + 2 * pad, b[3] - b[1] + 2 * pad
    ox, oy = pad - b[0], pad - b[1]
    body, _ = wordmark_parts(size, surface, ox, oy)
    title = 'ESPLITÉALO wordmark (Unkempt Bold, outlined)'
    if surface == 'mono':
        ink = ink or INK
        mid = uid + '-m'
        body = ('<mask id="%s" maskUnits="userSpaceOnUse" x="0" y="0" width="%s" height="%s">%s</mask>'
                '<rect width="%s" height="%s" fill="%s" mask="url(#%s)"/>') % (mid, f(w), f(h), body, f(w), f(h), ink, mid)
    return svg_doc(w, h, body, title)


def lockup_svg(c, surface, layout='h', ink=None, uid=None):
    uid = uid or ('%s-lk%s-%s' % (c.id, layout, surface))
    if getattr(c, 'wordmark_led', False) and layout == 'h':
        return wordmark_led_lockup(c, surface, ink, uid)
    x, y, bw, bh = c.box
    pad = 40
    if layout == 'h':
        H = 300
        k = H / bh
        sw = bw * k
        capH = 0.52 * H
        F = capH * WM.upm / WM.cap
        parts, b = WM.run(TEXT, F, TRACK)
        gap = 0.22 * H
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
        # wordmark width ≈ 1.9 x symbol height
        parts, b = WM.run(TEXT, 100, TRACK)
        F = 100 * (1.9 * H) / (b[2] - b[0])
        parts, b = WM.run(TEXT, F, TRACK)
        wm_w = b[2] - b[0]
        capH = F * WM.cap / WM.upm
        W = pad * 2 + max(wm_w, sw)
        gap = 0.2 * H
        Hh = pad + H + gap + capH + pad
        sx, sy = (W - sw) / 2, pad
        base_y = pad + H + gap + capH
        wm_x = (W - wm_w) / 2 - b[0]
    sym = '<g transform="translate(%s %s) scale(%s) translate(%s %s)">%s</g>' % (f(sx), f(sy), f(k), f(-x), f(-y), c.art(surface, uid))
    col, acc = WM_COL[surface]
    wm = ''.join('<path d="%s" fill="%s" transform="translate(%s %s)"/>' % (d, acc if a else col, f(wm_x), f(base_y)) for d, a in parts)
    title = 'Esplitéalo logo lockup, %s, %s' % ('horizontal' if layout == 'h' else 'stacked', c.name)
    if surface == 'mono':
        ink = ink or INK
        mid = uid + '-m'
        body = ('<mask id="%s" maskUnits="userSpaceOnUse" x="0" y="0" width="%s" height="%s">%s%s</mask>'
                '<rect width="%s" height="%s" fill="%s" mask="url(#%s)"/>') % (mid, f(W), f(Hh), sym, wm, f(W), f(Hh), ink, mid)
    else:
        body = sym + wm
    return svg_doc(W, Hh, body, title), (W, Hh)


def wordmark_led_lockup(c, surface, ink, uid):
    """Concept 5: the wordmark is the mark; a torn-receipt strip underlines it."""
    F = 260
    parts, b = WM.run(TEXT, F, TRACK)
    pad = 44
    wm_w = b[2] - b[0]
    capH = F * WM.cap / WM.upm
    W = wm_w + 2 * pad
    base = pad - b[1]
    n = 22
    y = base + 0.16 * F
    x0, x1 = pad, pad + wm_w
    w = (x1 - x0) / n
    strip = [(x0 + w * i, y + (26 if i % 2 else 0)) for i in range(n + 1)] + [(x1, y + 74), (x0, y + 74)]
    Hh = y + 74 + pad
    col, acc = WM_COL[surface]
    edge = {'light': BASIL, 'dark': '#2E9C77', 'mono': '#fff'}[surface]
    wm = ''.join('<path d="%s" fill="%s" transform="translate(%s %s)"/>' % (d, acc if a else col, f(pad - b[0]), f(base)) for d, a in parts)
    wm += '<polygon points="%s" fill="%s"/>' % (pts(strip), edge)
    title = 'Esplitéalo logo lockup, wordmark with torn-receipt underline, %s' % c.name
    if surface == 'mono':
        ink = ink or INK
        mid = uid + '-m'
        body = ('<mask id="%s" maskUnits="userSpaceOnUse" x="0" y="0" width="%s" height="%s">%s</mask>'
                '<rect width="%s" height="%s" fill="%s" mask="url(#%s)"/>') % (mid, f(W), f(Hh), wm, f(W), f(Hh), ink, mid)
    else:
        body = wm
    return svg_doc(W, Hh, body, title), (W, Hh)


if __name__ == '__main__':
    print('ok', [c.id for c in CONCEPTS])
