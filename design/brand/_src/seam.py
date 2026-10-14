"""Seam metric for the pink / green joint (round 5).  A butt joint of two anti-aliased shapes can show a hair-line that is lighter than both
colours (the background leaks through partly covered edge pixels).  For every row of the bar we find the joint from the geometry, take the
colour on the pink side and on the green side (a few pixels away from the joint), and measure how far each pixel across the joint falls
from the straight line between those two colours, as a share of the distance between them.  0 = a clean blend of the two colours;
0.25 = a quarter of the way to the ground colour (the worst case for a plain butt of two anti-aliased edges)."""
import io
import numpy as np
from PIL import Image


def joints(bar_alpha, y0=470, y1=552):
    """{y: (x_left_joint, x_right_joint)} from the bar's own alpha (a 1024-px raster of the pure butt bar; the joint is its left/right edge)."""
    a = np.asarray(bar_alpha)[..., 3] if np.asarray(bar_alpha).ndim == 3 else np.asarray(bar_alpha)
    out = {}
    for y in range(y0, y1):
        xs = np.where(a[y] > 127)[0]
        out[y] = (xs.min(), xs.max()) if len(xs) else None
    return out


def profile_residual(img, jt, scale=1.0, half=6, side=5):
    """max and mean relative residual over all rows and both joints. img: PIL RGB (any size; scale = size/1024)."""
    a = np.asarray(img.convert('RGB'), float)
    res = []
    for y, j in jt.items():
        if j is None:
            continue
        for k, xj in enumerate(j):
            for (ys, xs) in ((y * scale, xj * scale),):
                yy = int(round(ys)); xc = xs + (0.5 if k == 1 else 0.0)
                xi = int(round(xc))
                if k == 0:
                    inner_lo, inner_hi = xi - side, xi + side      # pink starts at xi: green on the left, pink on the right
                    c_green = np.median(a[yy, xi - side - 2:xi - side + 1], axis=0); c_pink = np.median(a[yy, xi + side:xi + side + 3], axis=0)
                    c1, c2 = c_green, c_pink
                else:
                    c_pink = np.median(a[yy, xi - side - 2:xi - side + 1], axis=0); c_green = np.median(a[yy, xi + side:xi + side + 3], axis=0)
                    c1, c2 = c_pink, c_green
                seg = c2 - c1
                n2 = float(seg @ seg)
                if n2 < 50:
                    continue
                for x in range(xi - half, xi + half + 1):
                    p = a[yy, x]
                    t = float((p - c1) @ seg) / n2
                    t = min(max(t, 0.0), 1.0)
                    res.append(float(np.linalg.norm(p - (c1 + t * seg))) / n2 ** 0.5)
    res = np.array(res)
    return res.max(), res.mean()
