"""Colour treatments of the layered icon: what each Icon Composer appearance uses for the ground, the e, the bar and the dots."""
from layered import Treatment

CREAM, GREEN, BASIL, PINK = '#FBF7EF', '#1F7A5A', '#145A42', '#EA5A78'
NIGHT = '#0F2A21'                       # dark ground (a near-black green)
GREEN_DK, PINK_LIGHT = '#4CC59A', '#FF8DA4'     # round 3's dark suggestions

LIGHT = dict(ground=CREAM, body=GREEN, bar=PINK, dots=PINK)
LIGHT_BASIL = dict(ground=CREAM, body=BASIL, bar=PINK, dots=PINK)       # the documented alternative green
# tinted: the system keeps only lightness and tints it with the user's colour, so what matters is the grey each layer starts as.
TINT_FINAL = dict(ground='#0A0A0A', body='#FFFFFF', bar='#8C8C8C', dots='#8C8C8C')       # round 4: found by rendering 9 sets (see report)
TINT_R3 = dict(ground='#4A4A4A', body='#FFFFFF', bar='#B4B4B4', dots='#B4B4B4')          # round 3

DARKS = {
    'lightened': dict(ground=NIGHT, body=GREEN_DK, bar=PINK_LIGHT, dots=PINK_LIGHT),     # round 3: lightened green and pink
    'same-pink': dict(ground=NIGHT, body=GREEN_DK, bar=PINK, dots=PINK),                 # same coral pink, lightened green e
    'cream-e': dict(ground=NIGHT, body=CREAM, bar=PINK, dots=PINK),                      # same coral pink, cream e
}
GLASS_ALL = dict(body=True, bar=True, dots=True)
GLASS_E_ONLY = dict(body=True, bar=False, dots=False)      # the e is lit, the pink is flat and so exact
