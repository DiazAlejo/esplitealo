"""Geometry helpers for the round-2 E dividida marks. Everything returns filled SVG path data
(no strokes), so each part can be exported as its own layer for Icon Composer."""
import math


def f(v):
    s = ('%.2f' % v).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


def capsule(x1, y1, x2, y2, w):
    """Filled line segment with round caps, as a path."""
    r = w / 2.0
    dx, dy = x2 - x1, y2 - y1
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    nx, ny = -uy, ux                      # normal, 90 deg anticlockwise on screen
    return ('M%s %sA%s %s 0 0 1 %s %sL%s %sA%s %s 0 0 1 %s %sZ' % (
        f(x1 + nx * r), f(y1 + ny * r), f(r), f(r), f(x1 - nx * r), f(y1 - ny * r),
        f(x2 - nx * r), f(y2 - ny * r), f(r), f(r), f(x2 + nx * r), f(y2 + ny * r)))


def rrect(x, y, w, h, r):
    r = min(r, w / 2.0, h / 2.0)
    return ('M%s %sH%sA%s %s 0 0 1 %s %sV%sA%s %s 0 0 1 %s %sH%sA%s %s 0 0 1 %s %sV%sA%s %s 0 0 1 %s %sZ' % (
        f(x + r), f(y), f(x + w - r), f(r), f(r), f(x + w), f(y + r), f(y + h - r), f(r), f(r), f(x + w - r), f(y + h),
        f(x + r), f(r), f(r), f(x), f(y + h - r), f(y + r), f(r), f(r), f(x + r), f(y)))


def circle(cx, cy, r):
    return 'M%s %sA%s %s 0 1 1 %s %sA%s %s 0 1 1 %s %sZ' % (f(cx - r), f(cy), f(r), f(r), f(cx + r), f(cy), f(r), f(r), f(cx - r), f(cy))


def ring(cx, cy, r_out, r_in):
    """Annulus (even-odd needed: draw with fill-rule evenodd)."""
    return circle(cx, cy, r_out) + circle(cx, cy, r_in)


def band(cx, cy, R, w, a_from, a_to, round_end=True, round_start=False):
    """Arc band of centre-line radius R and width w, from angle a_from to a_to (degrees, clockwise on
    screen, 0 = +x). a_to < a_from travels anticlockwise."""
    Ro, Ri, r = R + w / 2.0, R - w / 2.0, w / 2.0
    d = 1 if a_to > a_from else -1
    sw = 1 if d > 0 else 0
    span = abs(a_to - a_from)
    large = 1 if span > 180 else 0

    def pt(rad, a):
        t = math.radians(a)
        return cx + rad * math.cos(t), cy + rad * math.sin(t)
    po0, po1 = pt(Ro, a_from), pt(Ro, a_to)
    pi0, pi1 = pt(Ri, a_from), pt(Ri, a_to)
    out = 'M%s %sA%s %s 0 %d %d %s %s' % (f(po0[0]), f(po0[1]), f(Ro), f(Ro), large, sw, f(po1[0]), f(po1[1]))
    out += ('A%s %s 0 0 %d %s %s' % (f(r), f(r), sw, f(pi1[0]), f(pi1[1]))) if round_end else 'L%s %s' % (f(pi1[0]), f(pi1[1]))
    out += 'A%s %s 0 %d %d %s %s' % (f(Ri), f(Ri), large, 1 - sw, f(pi0[0]), f(pi0[1]))
    out += ('A%s %s 0 0 %d %s %s' % (f(r), f(r), sw, f(po0[0]), f(po0[1]))) if round_start else ''
    return out + 'Z'


def poly(points):
    return 'M' + 'L'.join('%s %s' % (f(x), f(y)) for x, y in points) + 'Z'


def path(d, fill, extra=''):
    return '<path d="%s" fill="%s"%s/>' % (d, fill, extra)


def rpoly(points, radii):
    """Closed polygon with a corner radius per vertex (clockwise on screen). Concave corners work too."""
    n = len(points)
    out = []
    for i in range(n):
        P, V, N = points[i - 1], points[i], points[(i + 1) % n]
        d1 = (V[0] - P[0], V[1] - P[1]); d2 = (N[0] - V[0], N[1] - V[1])
        l1 = math.hypot(*d1); l2 = math.hypot(*d2)
        r = radii[i]
        A = (V[0] - d1[0] / l1 * r, V[1] - d1[1] / l1 * r)
        B = (V[0] + d2[0] / l2 * r, V[1] + d2[1] / l2 * r)
        cross = d1[0] * d2[1] - d1[1] * d2[0]
        sw = 1 if cross > 0 else 0
        out.append((A, B, r, sw))
    d = 'M%s %s' % (f(out[0][0][0]), f(out[0][0][1]))
    for i, (A, B, r, sw) in enumerate(out):
        if i:
            d += 'L%s %s' % (f(A[0]), f(A[1]))
        if r > 0:
            d += 'A%s %s 0 0 %d %s %s' % (f(r), f(r), sw, f(B[0]), f(B[1]))
    return d + 'Z'


def tongue(x_left, x_right, yc, t):
    """Horizontal bar, flat at the left (butts against a stem), fully round at the right."""
    r = t / 2.0
    return 'M%s %sH%sA%s %s 0 0 1 %s %sH%sZ' % (f(x_left), f(yc - r), f(x_right - r), f(r), f(r), f(x_right - r), f(yc + r), f(x_left))
