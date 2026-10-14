"""Hand-drawn stroke engine for round 3: variable-width, slightly wobbly strokes returned as filled outlines
(skia-pathops Paths), so the marks stay plain filled paths (no SVG strokes, masks or clip paths).

    stroke(points, width, wobble=0, seed=1)  centerline through the points (centripetal Catmull-Rom), round caps
    blob(cx, cy, r, wob, seed)               a slightly irregular hand-made dot
    ring_pts(...)                            dense points on an ellipse arc (angles in degrees, clockwise on screen)
"""
import math, random
from pathops import Path
from geom import union


def _cr(p0, p1, p2, p3, n, alpha=0.5):
    def tj(ti, a, b):
        return ti + max(math.hypot(b[0] - a[0], b[1] - a[1]), 1e-6) ** alpha
    t0 = 0.0
    t1 = tj(t0, p0, p1); t2 = tj(t1, p1, p2); t3 = tj(t2, p2, p3)
    out = []
    for i in range(n):
        t = t1 + (t2 - t1) * i / n
        pt = []
        for k in (0, 1):
            a1 = (t1 - t) / (t1 - t0) * p0[k] + (t - t0) / (t1 - t0) * p1[k]
            a2 = (t2 - t) / (t2 - t1) * p1[k] + (t - t1) / (t2 - t1) * p2[k]
            a3 = (t3 - t) / (t3 - t2) * p2[k] + (t - t2) / (t3 - t2) * p3[k]
            b1 = (t2 - t) / (t2 - t0) * a1 + (t - t0) / (t2 - t0) * a2
            b2 = (t3 - t) / (t3 - t1) * a2 + (t - t1) / (t3 - t1) * a3
            pt.append((t2 - t) / (t2 - t1) * b1 + (t - t1) / (t2 - t1) * b2)
        out.append(tuple(pt))
    return out


def spline(pts, per=18):
    """Open centripetal Catmull-Rom through pts (ends duplicated by reflection)."""
    if len(pts) == 2:
        return list(pts)
    P = [(2 * pts[0][0] - pts[1][0], 2 * pts[0][1] - pts[1][1])] + list(pts) + [(2 * pts[-1][0] - pts[-2][0], 2 * pts[-1][1] - pts[-2][1])]
    out = []
    for i in range(1, len(P) - 2):
        out += _cr(P[i - 1], P[i], P[i + 1], P[i + 2], per)
    out.append(tuple(pts[-1]))
    return out


def noise(seed, terms=3, f0=1.1):
    """Smooth 1-D noise in about [-1, 1] on t in [0, 1]."""
    r = random.Random(seed)
    ph = [r.uniform(0, 6.283) for _ in range(terms)]
    fr = [f0 * (1.7 ** k) * r.uniform(0.85, 1.2) for k in range(terms)]
    am = [1.0 / (1.5 ** k) for k in range(terms)]
    s = sum(am)
    return lambda t: sum(a * math.sin(6.283 * f * t + p) for a, f, p in zip(am, fr, ph)) / s


def _resample(pts, step=3.0):
    out = [pts[0]]
    acc = 0.0
    for a, b in zip(pts, pts[1:]):
        d = math.hypot(b[0] - a[0], b[1] - a[1])
        if d == 0:
            continue
        acc += d
        if acc >= step:
            out.append(b)
            acc = 0.0
    if out[-1] != pts[-1]:
        out.append(pts[-1])
    return out


def stroke(points, width, wobble=0.0, wseed=1, smooth=True, per=18, caps=(True, True), taper=(1.0, 1.0), wwob=0.0):
    """Variable-width stroke along points. width: number or callable(t)->w. wobble: centreline noise in px.
    taper: width multipliers at the start and end (1 = none); linear blend over the first/last 18% of the length.
    wwob: relative width noise (0.05 = 5%). Returns a pathops Path (union of one polygon and its round caps)."""
    pts = spline(points, per) if smooth else list(points)
    pts = _resample(pts, 2.5)
    n = len(pts)
    # arc length parameter
    L = [0.0]
    for a, b in zip(pts, pts[1:]):
        L.append(L[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    tot = L[-1] or 1.0
    wn = noise(wseed + 100, 2, 2.2)
    cn = noise(wseed, 3, 1.3)
    wf = width if callable(width) else (lambda t, w=width: w)

    def wat(i):
        t = L[i] / tot
        w = wf(t)
        a, b = taper
        ramp = 0.18
        if t < ramp:
            w *= a + (1 - a) * (t / ramp)
        elif t > 1 - ramp:
            w *= b + (1 - b) * ((1 - t) / ramp)
        return max(w * (1 + wwob * wn(t)), 2.0)

    cl = []
    for i, (x, y) in enumerate(pts):
        j0, j1 = max(i - 1, 0), min(i + 1, n - 1)
        dx, dy = pts[j1][0] - pts[j0][0], pts[j1][1] - pts[j0][1]
        d = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / d, dx / d
        o = wobble * cn(L[i] / tot)
        cl.append((x + nx * o, y + ny * o, nx, ny, wat(i)))
    left = [(x + nx * w / 2, y + ny * w / 2) for x, y, nx, ny, w in cl]
    right = [(x - nx * w / 2, y - ny * w / 2) for x, y, nx, ny, w in cl]
    poly = left + right[::-1]
    p = Path()
    pen = p.getPen()
    pen.moveTo(poly[0])
    for q in poly[1:]:
        pen.lineTo(q)
    pen.closePath()
    shapes = [p]
    for end, (x, y, nx, ny, w) in ((0, cl[0]), (1, cl[-1])):
        if caps[end]:
            shapes.append(disc(x, y, w / 2))
    return union(*shapes) if len(shapes) > 1 else p


def disc(cx, cy, r, n=40):
    p = Path()
    pen = p.getPen()
    for i in range(n):
        a = 2 * math.pi * i / n
        q = (cx + r * math.cos(a), cy + r * math.sin(a))
        pen.moveTo(q) if i == 0 else pen.lineTo(q)
    pen.closePath()
    return p


def blob(cx, cy, r, wob=0.07, seed=1, squash=1.0, rot=0.0, n=56):
    """Slightly irregular, hand-made dot. squash < 1 flattens it; rot in degrees."""
    nz = noise(seed, 3, 1.0)
    p = Path()
    pen = p.getPen()
    cr, sr = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    for i in range(n):
        a = 2 * math.pi * i / n
        rr = r * (1 + wob * nz(i / n))
        x, y = rr * math.cos(a), rr * math.sin(a) * squash
        q = (cx + x * cr - y * sr, cy + x * sr + y * cr)
        pen.moveTo(q) if i == 0 else pen.lineTo(q)
    pen.closePath()
    return p


def ring_pts(cx, cy, rx, ry, a0, a1, n=60, warp=None):
    """Points on an ellipse from a0 to a1 degrees (clockwise on screen, 0 = +x). warp(t)-> radius multiplier."""
    out = []
    for i in range(n + 1):
        t = i / n
        a = math.radians(a0 + (a1 - a0) * t)
        k = warp(t) if warp else 1.0
        out.append((cx + rx * k * math.cos(a), cy + ry * k * math.sin(a)))
    return out
