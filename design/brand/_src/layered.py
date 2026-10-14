"""Layered-icon export for Icon Composer (.icon bundle) of a mark with the layers body / bar / dots.

Layers (back to front), each a 1024 x 1024 canvas with the shapes already in place:
    0-background   full-bleed opaque ground                         group "Background"
    1-e-body       the green e                                      group "E"
    2-division-bar the pink bar                                     group "Division"
    3-dots         the dots                                         group "Division"
icon.json lists groups front to back (the first group is the top of the sidebar). The schema was worked out by
rendering in rounds 2 and 3; round 4 added the `glass` switch per layer (see the report, section 1).

A Treatment says what each appearance uses for each layer and whether the layer gets the Liquid Glass look:

    default / dark / tinted : {ground, body, bar, dots} hex colours (tinted is the grey the system tints from)
    glass                   : {body, bar, dots} booleans (False = flat fill: the system does not light the layer)
"""
import json, os, shutil, subprocess
from core import svg_doc, png_rgb, png_rgba, write, lum

ICTOOL = '/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool'
RENDITIONS = [('Default', 'default'), ('Dark', 'dark'), ('TintedLight', 'tinted-light'), ('TintedDark', 'tinted-dark'),
              ('ClearLight', 'clear-light'), ('ClearDark', 'clear-dark')]


def hex_rgb(h):
    h = h.lstrip('#')
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]


def srgb(h):
    return 'srgb:%.5f,%.5f,%.5f,1.00000' % tuple(hex_rgb(h))


class Treatment:
    def __init__(self, name, default, dark, tinted, glass=None, translucent_body=None, note='', e_front=False):
        self.name, self.default, self.dark, self.tinted, self.note = name, default, dark, tinted, note
        self.e_front = e_front      # True: the E group sits in front of the Division group (the pink runs a hair under the green)
        self.glass = glass or dict(body=True, bar=True, dots=True)
        self.translucent_body = translucent_body


def layer_svgs(variant, P, ground):
    """{filename: svg text}; only the layers the variant has are written."""
    L = variant.layers(P)
    out = {'0-background.svg': svg_doc(1024, 1024, '<rect width="1024" height="1024" fill="%s"/>' % ground, 'Background layer')}
    for key, fn, label in (('body', '1-e-body', 'E body'), ('bar', '2-division-bar', 'Division bar'), ('dots', '3-dots', 'Dots')):
        if key in L:
            out['%s.svg' % fn] = svg_doc(1024, 1024, L[key], '%s layer, %s' % (label, variant.name))
    return out


def icon_json(variant, tr, have):
    def spec(role):
        return [{'value': {'solid': srgb(tr.default[role])}},
                {'appearance': 'dark', 'value': {'solid': srgb(tr.dark[role])}},
                {'appearance': 'tinted', 'value': {'solid': srgb(tr.tinted[role])}}]
    shadow = {'kind': 'neutral', 'opacity': 0.5}

    def layer(key, fn, role):
        return {'glass': bool(tr.glass[key]), 'image-name': fn + '.svg', 'name': fn, 'fill-specializations': spec(role)}
    g_div = {'name': 'Division', 'layers': [layer(k, fn, k) for k, fn in (('bar', '2-division-bar'), ('dots', '3-dots')) if k in have],
             'shadow': shadow, 'translucency': {'enabled': False, 'value': 0}}
    g_e = {'name': 'E', 'layers': [layer('body', '1-e-body', 'body')], 'shadow': shadow,
           'translucency': {'enabled': bool(tr.translucent_body), 'value': tr.translucent_body or 0}}
    g_bg = {'name': 'Background', 'layers': [{'glass': False, 'image-name': '0-background.svg', 'name': '0-background', 'fill-specializations': spec('ground')}]}
    front, back = ([g_e], [g_div]) if tr.e_front else ([g_div], [g_e])
    groups = [g for g in front + back if g['layers']] + [g_bg]
    return {'groups': groups, 'supported-platforms': {'squares': 'shared'}}


def write_bundle(variant, P, tr, out_dir, name):
    os.makedirs(out_dir, exist_ok=True)
    svgs = layer_svgs(variant, P, tr.default['ground'])
    for fn, s in svgs.items():
        write(os.path.join(out_dir, 'svg', fn), s)
        im = png_rgb(s) if fn.startswith('0-') else png_rgba(s)
        os.makedirs(os.path.join(out_dir, 'png'), exist_ok=True)
        im.save(os.path.join(out_dir, 'png', fn.replace('.svg', '.png')), optimize=True)
    bundle = os.path.join(out_dir, '%s.icon' % name)
    if os.path.isdir(bundle):
        shutil.rmtree(bundle)
    os.makedirs(os.path.join(bundle, 'Assets'))
    for fn, s in svgs.items():
        write(os.path.join(bundle, 'Assets', fn), s)
    have = {'body', 'dots'} | ({'bar'} if 'bar' in variant.layers(P) else set())
    with open(os.path.join(bundle, 'icon.json'), 'w') as fh:
        json.dump(icon_json(variant, tr, have), fh, indent=2)
        fh.write('\n')
    return bundle


def to_srgb(path):
    """ictool tags its Default / Tinted / Clear renders Display P3 (and the Dark one sRGB). Read as sRGB, a P3 render looks muted:
    round 3 measured the default pink as #DD667C for that reason. Convert in place to real sRGB so the numbers and the pictures are true."""
    import io
    from PIL import Image, ImageCms
    im = Image.open(path)
    icc = im.info.get('icc_profile')
    a = im.convert('RGBA').getchannel('A')
    rgb = im.convert('RGB')
    srgb_p = ImageCms.createProfile('sRGB')
    if icc:
        rgb = ImageCms.profileToProfile(rgb, ImageCms.ImageCmsProfile(io.BytesIO(icc)), srgb_p, renderingIntent=ImageCms.Intent.RELATIVE_COLORIMETRIC, outputMode='RGB')
    rgb.putalpha(a)
    rgb.save(path, optimize=True, icc_profile=ImageCms.ImageCmsProfile(srgb_p).tobytes())


def render(bundle, rend, out, extra=()):
    r = subprocess.run([ICTOOL, bundle, '--export-image', '--output-file', out, '--platform', 'iOS', '--rendition', rend,
                        '--width', '1024', '--height', '1024', '--scale', '1', *extra], capture_output=True, text=True)
    ok = r.returncode == 0 and os.path.exists(out)
    if ok:
        to_srgb(out)
    return ok, r.returncode, (r.stderr or r.stdout)[:200]


def build(variant, P, tr, out_dir, name, previews=True):
    """Writes <out_dir>/svg, png, <name>.icon and preview renders (PNG keeps the ictool colour profile). Returns facts."""
    bundle = write_bundle(variant, P, tr, out_dir, name)
    facts = {'bundle': bundle}
    if previews and os.path.exists(ICTOOL):
        pdir = os.path.join(out_dir, 'preview')
        os.makedirs(pdir, exist_ok=True)
        ok, log = True, []
        for rend, slug in RENDITIONS:
            p = os.path.join(pdir, '%s.png' % slug)
            good, rc, msg = render(bundle, rend, p)
            ok = ok and good
            log.append('%s exit=%s %s' % (rend, rc, 'ok' if good else msg))
        facts['ictool'] = ok
        facts['ictool_log'] = log
    return facts
