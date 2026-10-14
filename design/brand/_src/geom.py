"""Boolean path operations (skia-pathops) so every mark is plain filled outlines: no masks, no clip paths,
no strokes. Cut-outs are real holes, so the SVGs open the same in browsers, Figma, Illustrator and Icon Composer."""
import pathops
from pathops import Path, PathOp, LineCap, LineJoin
from fontTools.svgLib.path import parse_path
from fontTools.pens.svgPathPen import SVGPathPen
from shapes import f


def P(d):
    p = Path()
    parse_path(d, p.getPen())
    return p


def union(*ps):
    out = Path()
    for p in ps:
        out = pathops.op(out, p, PathOp.UNION) if len(out) else Path(p)
    return out


def diff(a, b):
    return pathops.op(a, b, PathOp.DIFFERENCE)


def inter(a, b):
    return pathops.op(a, b, PathOp.INTERSECTION)


def grow(p, g):
    """p expanded by g on every side (round joins)."""
    s = Path(p)
    s.stroke(2 * g, LineCap.ROUND_CAP, LineJoin.ROUND_JOIN, 4)
    s.convertConicsToQuads(0.05)
    return union(p, s)


def shrink(p, g):
    """p pulled in by g on every side (the opposite of grow): p minus a band of width 2g centred on its outline."""
    s = Path(p)
    s.stroke(2 * g, LineCap.ROUND_CAP, LineJoin.ROUND_JOIN, 4)
    s.convertConicsToQuads(0.05)
    return diff(p, s)


def rect(x, y, w, h):
    return P('M%s %sH%sV%sH%sZ' % (f(x), f(y), f(x + w), f(y + h), f(x)))


def to_d(p):
    pen = SVGPathPen(None, ntos=lambda v: ('%.1f' % v).rstrip('0').rstrip('.') if abs(v) >= 0.05 else '0')
    p.draw(pen)
    return pen.getCommands()
