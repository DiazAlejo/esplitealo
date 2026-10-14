import sys, io, numpy as np
from PIL import Image, ImageCms
SRGB = ImageCms.createProfile('sRGB')
def load_srgb(path):
    im = Image.open(path)
    icc = im.info.get('icc_profile')
    im = im.convert('RGBA')
    if icc:
        src = ImageCms.ImageCmsProfile(io.BytesIO(icc))
        rgb = im.convert('RGB')
        out = ImageCms.profileToProfile(rgb, src, SRGB, renderingIntent=ImageCms.Intent.RELATIVE_COLORIMETRIC, outputMode='RGB')
        a = im.getchannel('A'); out.putalpha(a); im = out
    return im
def hexs(v): return '#%02X%02X%02X' % tuple(int(round(x)) for x in v)
def core(mask,k=9):
    from numpy.lib.stride_tricks import sliding_window_view
    return sliding_window_view(np.pad(mask,k//2),(k,k)).all(axis=(2,3))
def region_med(im, mask):
    if mask.sum()==0: return None
    return hexs(np.median(im[mask][:, :3], axis=0))
def stats(path, pinkmask=None, greenmask=None):
    """Median sRGB colour of the pink and green regions. Masks are boolean 1024x1024 arrays from the geometry (eroded)."""
    im = np.array(load_srgb(path)).astype(int)
    return dict(pink=region_med(im, pinkmask), green=region_med(im, greenmask), corner=hexs(im[300,6][:3]))
