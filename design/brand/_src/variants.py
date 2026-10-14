"""Round 3: nine variations of the e whose ÷ is genuinely part of the letter. Coordinates are in a 1024 box.

Every mark is plain filled outlines (skia-pathops booleans, see geom.py and strokes.py): no strokes, masks or clip paths.
A variant exposes

    pieces(P) -> [(layer, Path, colour)] in draw order (back to front). P maps roles to colours:
                 body = the letter (main colour, green), acc = the ÷ (accent, pink), glint = the cut-out colour of
                 the face variant's eyes (the ground colour).
    art(P)    -> svg fragment (one <path> per piece)
    layers(P) -> {layer: svg fragment}: the layers for the Icon Composer bundle (body, bar, dots, ...)

The pieces are fitted to the same box (FIT x FIT, centred), so the variants compare fairly at every size.
For the one-colour version pass a P whose colours are all the same: the bar then fuses into the e, the dots stay
real holes' worth of air (they sit in the counters).
"""
import math
from pathops import Path
from fontTools.pens.transformPen import TransformPen
from shapes import capsule, circle, band, f, rpoly, poly
from geom import P as parse, union, diff, inter, grow, rect, to_d
from strokes import stroke, blob, ring_pts, disc

CX = CY = 512
FIT = 780          # the mark is fitted into a FIT x FIT box in the middle of the 1024 canvas


def xf(p, sx, sy, tx, ty):
    out = Path()
    p.draw(TransformPen(out.getPen(), (sx, 0, 0, sy, tx, ty)))
    return out


def fit(pieces, box=FIT, ox=0.0, oy=0.0):
    """Scale and centre the union of all pieces into box x box about (512 + ox, 512 + oy)."""
    allp = union(*[p for _, p, _ in pieces])
    x0, y0, x1, y1 = allp.bounds
    k = min(box / (x1 - x0), box / (y1 - y0))
    tx = 512 + ox - k * (x0 + x1) / 2
    ty = 512 + oy - k * (y0 + y1) / 2
    return [(n, xf(p, k, k, tx, ty), c) for n, p, c in pieces]


def piece_svg(d, colour):
    return '<path d="%s" fill="%s"/>' % (d, colour)


class V:
    id = ''; slug = ''; name = ''; family = ''
    fit_box = FIT
    fit_off = (0.0, 0.0)

    def raw(self, P):
        raise NotImplementedError

    def pieces(self, P):
        return fit(self.raw(P), self.fit_box, *self.fit_off)

    def art(self, P):
        return ''.join(piece_svg(to_d(p), c) for _, p, c in self.pieces(P))

    def layers(self, P):
        out = {}
        for name, p, c in self.pieces(P):
            out.setdefault(name, []).append((p, c))
        return {n: ''.join(piece_svg(to_d(p), c) for p, c in lst) for n, lst in out.items()}


def dot(x, y, r):
    return parse(circle(x, y, r))


def outer(cx, cy, rx, ry):
    """The e's outer silhouette ellipse as a filled shape: the bar is cut to it, so a flush bar ends on the letter's own edge."""
    return stroke(ring_pts(cx, cy, rx, ry, 0, 360, n=120), 4, smooth=False, caps=(False, False)) if False else _ellipse(cx, cy, rx, ry)


def _ellipse(cx, cy, rx, ry, n=120):
    p = Path()
    pen = p.getPen()
    for i in range(n):
        a = 2 * math.pi * i / n
        q = (cx + rx * math.cos(a), cy + ry * math.sin(a))
        pen.moveTo(q) if i == 0 else pen.lineTo(q)
    pen.closePath()
    return p


def e_ring(cx, cy, R, W, term):
    """Geometric ring of an e: starts at 3 o'clock (flat), runs anticlockwise over the top and round the bottom, round terminal."""
    return parse(band(cx, cy, R, W, 0, -(360 - term), round_end=True, round_start=False))


# ================================================================ 1. Travesaño (geometric, one monoline stroke)
class Travesano(V):
    id = 'v1'; slug = '01-travesano'; name = 'Travesaño'; family = 'e redonda · geométrica'

    def raw(self, P):
        R, W, bt, term = 266, 118, 98, 56
        body = union(e_ring(CX, CY, R, W, term), parse(capsule(CX - R, CY, CX + R, CY, bt)), dot(CX + R, CY, W / 2.0))
        c = (R - W / 2.0 + bt / 2.0) / 2.0
        dots = union(dot(CX, CY - c, 54), dot(CX + 8, CY + c, 54))
        return [('body', body, P['body']), ('dots', dots, P['acc'])]


# ================================================================ 2. Franja (geometric, pink bar flush to the outer edge)
class Franja(V):
    id = 'v2'; slug = '02-franja'; name = 'Franja'; family = 'e redonda · geométrica'

    def raw(self, P):
        R, W, bt, term = 266, 122, 100, 56
        Ro = R + W / 2.0
        ring = e_ring(CX, CY, R, W, term)
        bar = inter(rect(CX - Ro - 4, CY - bt / 2, 2 * Ro + 8, bt), outer(CX, CY, Ro, Ro))
        c = (R - W / 2.0 + bt / 2.0) / 2.0
        dots = union(dot(CX, CY - c, 54), dot(CX + 8, CY + c, 54))
        return [('body', ring, P['body']), ('bar', bar, P['acc']), ('dots', dots, P['acc'])]


# ================================================================ 3. Cola (geometric, the bar runs on past the bowl)
class Cola(V):
    id = 'v3'; slug = '03-cola'; name = 'Cola'; family = 'e redonda · geométrica'

    def raw(self, P):
        R, W, bt, term, ext = 262, 120, 100, 58, 130
        Ro = R + W / 2.0
        ring = e_ring(CX, CY, R, W, term)
        r = bt / 2.0
        x0, x1 = CX - Ro + 1, CX + Ro + ext
        bar = parse('M%s %sH%sA%s %s 0 0 1 %s %sH%sZ' % (f(x0 - 6), f(CY - r), f(x1 - r), f(r), f(r), f(x1 - r), f(CY + r), f(x0 - 6)))
        bar = inter(bar, union(outer(CX, CY, Ro, Ro), rect(CX, CY - 200, 1024, 400)))
        c = (R - W / 2.0 + bt / 2.0) / 2.0
        dx = 46
        dots = union(dot(CX + dx, CY - c, 52), dot(CX + dx + 6, CY + c, 52))
        return [('body', ring, P['body']), ('bar', bar, P['acc']), ('dots', dots, P['acc'])]


# ================================================================ 4. Un trazo (hand-drawn, the reference with the bar joined)
def hand_ring(cx, cy, rx, ry, W, term=44, seed=3, wob=3, flick=30, start=-4):
    """Hand-drawn e ring: starts at 3 o'clock going anticlockwise (up and over), ends lower right with a lifted flick."""
    def w(t):
        return W * (0.92 + 0.16 * math.sin(math.pi * (t * 1.2 + 0.1)))
    lift = lambda t: 1 + flick / 260.0 * max(0.0, (t - 0.84) / 0.16) ** 2      # the terminal drifts outwards, a hand-drawn flick
    pts = ring_pts(cx, cy, rx, ry, start, -(360 - term), n=34, warp=lift)
    return stroke(pts, w, wobble=wob, wseed=seed, taper=(1.0, 0.92), wwob=0.04)


class UnTrazo(V):
    id = 'v4'; slug = '04-un-trazo'; name = 'Un trazo'; family = 'e dibujada a mano'

    def raw(self, P):
        rx, ry, W = 232, 280, 112
        ring = hand_ring(CX, CY, rx, ry, W, term=44, seed=3)
        bar = stroke([(CX - rx - 6, CY + 4), (CX - rx * 0.4, CY - 2), (CX + rx * 0.4, CY - 7), (CX + rx + 2, CY - 4)], 96, wobble=1.0, wseed=11)
        dots = union(blob(CX + 4, CY - 138, 56, 0.07, 5, 0.95, -10), blob(CX - 2, CY + 146, 58, 0.07, 7, 0.93, 12))
        return [('body', union(ring, bar), P['body']), ('dots', dots, P['acc'])]


# ================================================================ 5. Pincel (hand-drawn, pink bar that sweeps on out of the bowl)
class Pincel(V):
    id = 'v5'; slug = '05-pincel'; name = 'Pincel'; family = 'e dibujada a mano'

    def raw(self, P):
        rx, ry, W = 236, 272, 112
        ring = hand_ring(CX, CY, rx, ry, W, term=46, seed=8, wob=3)
        xl = CX - rx - W / 2 + 40
        bar = stroke([(xl, CY + 6), (CX - rx * 0.3, CY - 1), (CX + rx * 0.5, CY - 8), (CX + rx + 80, CY - 16), (CX + rx + 170, CY - 44)],
                     lambda t: 100 - 12 * t, wobble=1.5, wseed=21, taper=(1, 0.62))
        dots = union(blob(CX + 28, CY - 138, 54, 0.07, 15, 0.95, -8), blob(CX + 24, CY + 142, 56, 0.07, 17, 0.93, 14))
        return [('body', ring, P['body']), ('bar', bar, P['acc']), ('dots', dots, P['acc'])]


# ================================================================ 6. Chavito (the face on purpose: raccoon ears, glinting eyes)
class Chavito(V):
    """The face on purpose. The crossbar is the raccoon's mask (a thick band with two eyes in it), the upper dot is the
    forehead mark and the lower dot is the nose, so it is still e + ÷ at a glance."""
    id = 'v6'; slug = '06-chavito'; name = 'Chavito'; family = 'e con cara'

    def raw(self, P):
        rx, ry, W = 240, 262, 112
        cy = CY + 40
        ring = hand_ring(CX, cy, rx, ry, W, term=48, seed=4, wob=2.5, flick=20)
        bt = 132
        bar = stroke([(CX - rx - 6, cy + 4), (CX - rx * 0.4, cy), (CX + rx * 0.4, cy - 2), (CX + rx + 2, cy - 2)], bt, wobble=1.0, wseed=12)
        hole = _ellipse(CX, cy, rx - W / 2 + 2, ry - W / 2 + 2)       # keep the counter clean
        ears = []
        for s in (-1, 1):
            a = math.radians(36)
            ex = CX + s * (rx + 40) * math.sin(a)
            ey = cy - (ry + 40) * math.cos(a) - 14
            ears.append(blob(ex, ey, 80, 0.04, 50 + s))
        ears = diff(union(*ears), hole)
        eyes = [(CX - 84, cy - 2), (CX + 84, cy - 2)]
        eye_holes = union(*[disc(x, y, 38) for x, y in eyes])
        pupils = union(*[disc(x + 5, y + 1, 17) for x, y in eyes])
        body = union(diff(union(ring, bar, ears), eye_holes), pupils)
        dots = union(blob(CX + 2, cy - 138, 44, 0.05, 31, 0.8), blob(CX + 8, cy + 148, 54, 0.05, 33, 0.8))
        return [('body', body, P['body']), ('dots', dots, P['acc'])]


# ================================================================ 7. e de imprenta (a wide, typographic e: the version that avoids the face)
class Imprenta(V):
    id = 'v7'; slug = '07-e-de-imprenta'; name = 'e de imprenta'; family = 'e redonda · tipográfica'

    def raw(self, P):
        rx, ry, W, bt, term = 290, 248, 122, 104, 34
        pts = ring_pts(CX, CY, rx, ry, 0, -(360 - term), n=90)
        ring = stroke(pts, W, smooth=False, caps=(False, True))
        Ro = rx + W / 2.0
        bar = inter(rect(CX - Ro - 4, CY - bt / 2, 2 * Ro + 8, bt), _ellipse(CX, CY, Ro, ry + W / 2.0))
        gap, r = 20, 50
        dy = bt / 2 + gap + r
        dots = union(dot(CX - 4, CY - dy, r), dot(CX - 4, CY + dy, r))
        return [('body', ring, P['body']), ('bar', bar, P['acc']), ('dots', dots, P['acc'])]


# ================================================================ 8. E obelo (capital E, the middle arm is the bar)
class EGeo:
    def __init__(self, x0=244, x1=790, y0=184, y1=840, ts=118, ta=108, tb=100):
        self.x0, self.x1, self.y0, self.y1 = x0, x1, y0, y1
        self.ts, self.ta, self.tb = ts, ta, tb
        self.ym = (y0 + y1) / 2.0

    def body(self):
        x0, x1, y0, y1, ts, ta = self.x0, self.x1, self.y0, self.y1, self.ts, self.ta
        pts = [(x0, y0), (x1, y0), (x1, y0 + ta), (x0 + ts, y0 + ta), (x0 + ts, y1 - ta), (x1, y1 - ta), (x1, y1), (x0, y1)]
        rad = [62, ta / 2.0, ta / 2.0, 20, 20, ta / 2.0, ta / 2.0, 62]
        return parse(rpoly(pts, rad))

    def bar(self):
        r = self.tb / 2.0
        xs = self.x0 + self.ts - 26            # sinks into the stem, so there is no seam between the arm and the stem
        return parse('M%s %sH%sA%s %s 0 0 1 %s %sH%sZ' % (f(xs), f(self.ym - r), f(self.x1 - r), f(r), f(r), f(self.x1 - r), f(self.ym + r), f(xs)))

    def dots(self, r):
        x = (self.x0 + self.ts + self.x1) / 2.0 + 20
        up = (self.y0 + self.ta + self.ym - self.tb / 2.0) / 2.0
        dn = (self.y1 - self.ta + self.ym + self.tb / 2.0) / 2.0
        return union(dot(x, up, r), dot(x, dn, r))


class EObelo(V):
    id = 'v8'; slug = '08-e-obelo'; name = 'E obelo'; family = 'E mayúscula · geométrica'

    def raw(self, P):
        g = EGeo()
        return [('body', g.body(), P['body']), ('bar', g.bar(), P['acc']), ('dots', g.dots(56), P['acc'])]


# ================================================================ 9. E manuscrita (capital E, hand-drawn)
class EManuscrita(V):
    id = 'v9'; slug = '09-e-manuscrita'; name = 'E manuscrita'; family = 'E mayúscula · dibujada a mano'

    def raw(self, P):
        W = 122
        pts = [(790, 226), (560, 214), (330, 218), (272, 266), (266, 500), (270, 752), (330, 808), (560, 816), (796, 802)]
        e = stroke(pts, lambda t: W * (0.94 + 0.10 * math.sin(math.pi * t * 2.0)), wobble=2.5, wseed=5, taper=(0.92, 0.84))
        bar = stroke([(266, 516), (440, 510), (620, 508), (780, 502)], 98, wobble=1.5, wseed=9, taper=(1, 0.86))
        dots = union(blob(566, 372, 56, 0.07, 41, 0.95, -8), blob(562, 656, 56, 0.07, 43, 0.93, 10))
        return [('body', e, P['body']), ('bar', bar, P['acc']), ('dots', dots, P['acc'])]


VARIANTS = [Travesano(), Franja(), Cola(), UnTrazo(), Pincel(), Chavito(), Imprenta(), EObelo(), EManuscrita()]
BY_ID = {v.id: v for v in VARIANTS}
