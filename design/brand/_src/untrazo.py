"""Round 5 adds class DP at the bottom of this file: Dos paredes, the final mark (the pink bar is the region between the inner
edges of the two walls, cut out by the green's own outline, so the two colours meet on one clean line).

Round 4: the Un trazo e (round 3's hand-drawn e, one stroke) with the ÷ in different relationships to the letter.

Everything is plain filled outlines (skia-pathops booleans): no strokes, masks or clip paths in the output.
Coordinates are in a 1024 box, fitted afterwards into a FIT x FIT box like every earlier round.

The ring (the e's one hand stroke) is the round-3 ring, unchanged: centre (512, 512), centre-line radii 232 x 280,
stroke about 112, seed 3, starting at 3 o'clock, going over the top and round the bottom to a lifted flick.
Measured on its raster (row y = 512): left wall x 222 to 336, counter 337 to 690, right wall 695 to 794.

The dots have two explicit parameters (units of the 1024 box, before the final fit scale):

    DOT_R    dot radius (round 3 used 56)
    DOT_GAP  clear distance between the dot's edge and the bar's edge (round 3: about 34, so the dot floated mid-counter)

so the dot centre sits at  bar edge + DOT_GAP + DOT_R  above and below the bar.

Colour roles in P: body (the e), acc (the bar, and the dots unless P has 'dots'), dots (optional, to colour them apart).
"""
import math
from pathops import Path
from geom import union, diff, inter, rect, to_d, grow, shrink
from strokes import stroke, blob
from variants import V, CX, CY, hand_ring, _ellipse, fit

RING = dict(rx=232, ry=280, W=112, term=44, seed=3)
WALL_L_IN = 337        # x of the left wall's inner face at the bar height (measured)
WALL_R_IN = 690        # x of the right wall's inner face at the bar height (measured)
OUT_L, OUT_R = 222, 798
BAR_T = 96             # round 3's bar thickness
BAR_Y = CY - 2         # the bar's centre line (hand-drawn: it leans up a hair to the right)

# the three dot settings shown to the owner (radius, gap). S2 is the proposal.
DOT_SETTINGS = {
    'S1': dict(r=49, gap=30, name='S1 · Un poco menos', note='A touch smaller (r 49 vs 56) and nearer the bar (gap 30).'),
    'S2': dict(r=44, gap=22, name='S2 · Medio', note='Smaller (r 44) and tucked in (gap 22). The proposal.'),
    'S3': dict(r=40, gap=13, name='S3 · Pegado', note='Smallest (r 40) and hugging the bar (gap 13). Strongest ÷, smallest dots.'),
}
DEFAULT_DOT = 'S2'


def ring_path():
    return hand_ring(CX, CY, RING['rx'], RING['ry'], RING['W'], term=RING['term'], seed=RING['seed'])


def outer_ellipse():
    """The ring's outer silhouette as an ellipse (fitted to the raster: x 222 to 798, y 173 to 841)."""
    return _ellipse(510, 507, 288, 334)


def bar_stroke(x0, x1, t=BAR_T, end_caps=(True, True), seed=11, taper=(1.0, 1.0)):
    """A slightly hand-drawn horizontal bar from x0 to x1 (caps are included in the span)."""
    mid = (x0 + x1) / 2.0
    pts = [(x0, BAR_Y + 3), (mid - (x1 - x0) * 0.2, BAR_Y), (mid + (x1 - x0) * 0.2, BAR_Y - 2), (x1, BAR_Y - 4)]
    return stroke(pts, t, wobble=0.8, wseed=seed, caps=end_caps, taper=taper)


def dots_for(r, gap, t=BAR_T, xs=(4, -2), seed=5):
    """Two hand-made dots above and below the bar: centre = bar edge + gap + r."""
    d = t / 2.0 + gap + r
    return union(blob(CX + xs[0], BAR_Y - d, r, 0.05, seed, 0.96, -10, n=72), blob(CX + xs[1], BAR_Y + d + 2, r + 1, 0.05, seed + 2, 0.95, 12, n=72))


KINDS = ['a', 'b', 'c', 'd', 'e', 'f', 'g']


class UT(V):
    """kind:  a  bar fills the e, wall to wall, pink, fused to both walls (cut to the e's outline)
              b  floating pink bar in the middle: stops short of both walls, e outline unchanged
              c  pink bar touching the left wall only
              d  pink bar fused at the left wall, runs through the right wall and out as a small tail
              e  green bar (part of the e, round 3's Un trazo), pink dots
              f  pink bar (floating), green dots
              g  wall to wall like a, but the e is cut open round the bar by a cream hair-line (a stamped-in bar)
    """
    family = 'e dibujada a mano · Un trazo'

    def __init__(self, kind, dot='S2', r=None, gap=None, bar_t=None):
        self.kind = kind
        self.dot_key = dot
        s = DOT_SETTINGS[dot]
        self.r = r if r is not None else s['r']
        self.gap = gap if gap is not None else s['gap']
        self.bar_t = bar_t
        self.id = 'u' + kind + ('' if (dot == DEFAULT_DOT and r is None and gap is None) else ('-' + (dot if (r is None and gap is None) else 'x%s_%s' % (r, gap))))
        self.slug = '%s-%s' % ('abcdefg'.index(kind) + 1 and '0%d' % ('abcdefg'.index(kind) + 1), SLUGS[kind]) if self.id == 'u' + kind else self.id
        self.name = NAMES[kind][0]

    def raw(self, P):
        k = self.kind
        ring = ring_path()
        dotc = P['body'] if k == 'f' else P.get('dots', P['acc'])
        t = self.bar_t or BAR_T
        gapw = 24
        if k == 'a' or k == 'g':
            bar = inter(bar_stroke(OUT_L - 30, OUT_R + 30, t, end_caps=(False, False)), outer_ellipse())
            if k == 'g':        # a cream hair-line all round the bar: the e is cut open for it
                ring = diff(ring, rect(OUT_L - 60, BAR_Y - t / 2.0 - 16, OUT_R - OUT_L + 120, t + 32))
        elif k in ('b', 'f'):
            bar = bar_stroke(WALL_L_IN + gapw + t / 2.0, WALL_R_IN - gapw - t / 2.0, t)
        elif k == 'c':
            bar = bar_stroke(WALL_L_IN - 14, WALL_R_IN - 46 - t / 2.0, t, end_caps=(False, True))
        elif k == 'd':
            bar = stroke([(WALL_L_IN - 14, BAR_Y + 3), (CX - 40, BAR_Y), (CX + 140, BAR_Y - 2), (OUT_R + 10, BAR_Y - 6), (OUT_R + 84, BAR_Y - 30)],
                         lambda u: t - 14 * u, wobble=0.8, wseed=21, caps=(False, True), taper=(1.0, 0.72))
        elif k == 'e':
            bar = inter(bar_stroke(OUT_L - 30, OUT_R + 30, t, end_caps=(False, False)), outer_ellipse())
        else:
            raise ValueError(k)
        dots = dots_for(self.r, self.gap, t)
        if k == 'e':
            return [('body', union(ring, bar), P['body']), ('dots', dots, dotc)]
        return [('body', ring, P['body']), ('bar', bar, P['acc']), ('dots', dots, dotc)]


NAMES = {
    'a': ('Pared a pared', 'Wall to wall'),
    'b': ('Flotante', 'Floating'),
    'c': ('Una pared', 'One wall'),
    'd': ('Con cola', 'With a tail'),
    'e': ('Barra verde', 'Green bar'),
    'f': ('Puntos verdes', 'Green dots'),
    'g': ('Con corte', 'Cut in'),
}

SLUGS = {'a': 'pared-a-pared', 'b': 'flotante', 'c': 'una-pared', 'd': 'con-cola', 'e': 'barra-verde', 'f': 'puntos-verdes', 'g': 'con-corte'}


# ================================================================ round 5: Dos paredes (the final mark)
START = 6              # degrees below 3 o'clock where the e's stroke starts: round 4 used -4 (4 degrees above), which left the right wall
                       # ending above the bar's bottom edge; at 6 the wall's rounded start cap is centred on the bar's lower edge, so the
                       # bar meets a wall (not the open mouth) along its whole right end. Moves the start by 10 degrees of arc (about 49 units).
BAND_X0, BAND_X1 = 250, 760     # the bar's raw span: both ends lie well inside the walls (x 222 to 337 and 690 to 798); the walls cut it back
UNDER_D = 8.0          # the hidden strip of the "under" joint, in drawing units (see bar5): about 9 px at 1024, 1.6 px at 180


def ring5(start=START):
    return hand_ring(CX, CY, RING['rx'], RING['ry'], RING['W'], term=RING['term'], seed=RING['seed'], start=start)


def bar5(ring, t=BAR_T, joint='butt', d=0.8):
    """The pink bar as the region between the inner faces of the two walls: a hand-drawn band, cut by the green's outline.

    joint  butt   the pink ends exactly on the green's edge (shared boundary: no overlap, no gap)
           under  the pink runs d units under the green (the green is drawn on top of it): hides the anti-aliasing seam of a butt
           gap    a cream hair-line of d units between pink and green
    The 'under' strip is only the part of the walls within d of their inner edge, inside the bar's own height, so it can never touch the
    green's rim where it faces the cream.
    """
    band = bar_stroke(BAND_X0, BAND_X1, t, end_caps=(False, False))
    if joint == 'gap':
        bar = diff(band, grow(ring, d))
    elif joint == 'under':
        bar = diff(band, shrink(ring, d))
    else:
        bar = diff(band, ring)
    if joint != 'under':
        assert len(list(bar.contours)) == 1, 'the bar must be one piece between the walls'
    return bar


class DP(V):
    """Dos paredes. Pieces back to front: bar (when it is meant to sit under the green) or body first, then bar, dots."""
    family = 'e dibujada a mano · Un trazo'
    name = 'Dos paredes'

    def __init__(self, joint='butt', dot='S2', start=START, d=UNDER_D):
        self.joint, self.start, self.d = joint, start, d
        s = DOT_SETTINGS[dot]
        self.r, self.gap = s['r'], s['gap']
        self.id = 'dp' + ('' if joint == 'butt' else '-' + joint) + ('' if start == START else '-s%s' % start)
        self.slug = '01-dos-paredes' if self.id == 'dp' else self.id

    def raw(self, P):
        ring = ring5(self.start)
        bar = bar5(ring, joint=self.joint, d=self.d)
        dots = dots_for(self.r, self.gap)
        body = ('body', ring, P['body'])
        barp = ('bar', bar, P['acc'])
        dotp = ('dots', dots, P.get('dots', P['acc']))
        return [barp, body, dotp] if self.joint == 'under' else [body, barp, dotp]
