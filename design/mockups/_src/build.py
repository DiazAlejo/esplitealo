import json, os, re, sys
# usage: python3 build.py <out_root>   -> writes <out_root>/es, <out_root>/en, <out_root>/index.html (landing) and <out_root>/colors.html (colour plan); all self-contained, offline pages
src = os.path.dirname(os.path.abspath(__file__))
root_out = sys.argv[1]
rd = lambda n: open(os.path.join(src, n), encoding='utf-8').read()
css, calc, mascot, app, tpl, strings, idx_tpl = rd('tokens.css') + '\n' + rd('style.css') + '\n' + rd('wordmark.css'), rd('calc.js'), rd('mascot.js'), rd('app.js'), rd('template.html'), rd('strings.js'), rd('index.tpl.html')
import base64
# the ESPLITÉALO wordmark: outlined logo wordmark with the acute of the É as its own path (see wordmark.css)
_wm = rd('wordmark.svg')
_wm_vb = re.search(r'viewBox="([^"]+)"', _wm).group(1)
_wm_paths = ''.join(re.findall(r'<path [^>]+/>', _wm))
WORDMARK = ('<span class="wm" role="img" aria-label="Esplitéalo"><svg class="wm-svg" viewBox="' + _wm_vb + '" aria-hidden="true" focusable="false">' + _wm_paths + '</svg><span class="wm-txt">Esplitéalo</span></span>')
WORDMARK_CSS = rd('wordmark.css')
strings = 'window.ESP_WM = ' + json.dumps(WORDMARK, ensure_ascii=False) + ';\n' + strings
css = css.replace('__UNKEMPT_REG_B64__', base64.b64encode(open(os.path.join(src, 'fonts', 'Unkempt-Regular-latin.woff2'), 'rb').read()).decode())
css = css.replace('__UNKEMPT_B64__', base64.b64encode(open(os.path.join(src, 'fonts', 'Unkempt-Bold-latin.woff2'), 'rb').read()).decode())
screens = json.load(open(os.path.join(src, 'screens.json'), encoding='utf-8'))
META = {'es': ('es-PR', ' · maqueta de Esplitéalo', 'Esplitéalo · diseños de pantallas', 'Prototipo completo'),
        'en': ('en', ' · Esplitéalo mockup', 'Esplitéalo · screen designs', 'Full prototype')}
SC = 0.6
def page(lang, title, start):
    hl, suf, _, _ = META[lang]
    return (tpl.replace('__HTMLLANG__', hl).replace('__TITLE__', title + suf).replace('__LANG__', lang).replace('__STRINGS__', strings)
            .replace('__CSS__', css).replace('__CALC__', calc).replace('__MASCOT__', mascot)
            .replace('__START__', json.dumps(start)).replace('__APP__', app))
for lang in ('es', 'en'):
    out = os.path.join(root_out, lang)
    os.makedirs(out, exist_ok=True)
    for s in screens:
        open(os.path.join(out, s['file']), 'w', encoding='utf-8').write(page(lang, s['title'][lang], s['start']))
    open(os.path.join(out, 'prototype.html'), 'w', encoding='utf-8').write(page(lang, META[lang][3], {'screen': 'home', 'data': 'scanned'}))
    idx = (idx_tpl.replace('__HTMLLANG__', META[lang][0]).replace('__IDXTITLE__', META[lang][2]).replace('__LANG__', lang).replace('__STRINGS__', strings)
           .replace('__CSS__', css).replace('__MASCOT__', mascot).replace('__SCREENS__', json.dumps(screens, ensure_ascii=False))
           .replace('__W__', str(round(414 * SC))).replace('__H__', str(round(868 * SC))).replace('__S__', str(SC)))
    open(os.path.join(out, 'index.html'), 'w', encoding='utf-8').write(idx)
    print('built', len(screens) + 2, 'pages ->', out)
tokens = rd('tokens.css')
def fonts(t):
    return t.replace('__UNKEMPT_REG_B64__', base64.b64encode(open(os.path.join(src, 'fonts', 'Unkempt-Regular-latin.woff2'), 'rb').read()).decode()).replace('__UNKEMPT_B64__', base64.b64encode(open(os.path.join(src, 'fonts', 'Unkempt-Bold-latin.woff2'), 'rb').read()).decode())
open(os.path.join(root_out, 'index.html'), 'w', encoding='utf-8').write(fonts(rd('landing.tpl.html').replace('__WORDMARK_CSS__', WORDMARK_CSS).replace('__WORDMARK__', WORDMARK).replace('__TOKENS__', tokens).replace('__NSCREENS__', str(len(screens)))))
WM_SIZES = ''.join('<span style="display:flex;flex-direction:column;gap:6px;align-items:flex-start"><span class="sub" style="font-size:12px">' + label + '</span>' + WORDMARK.replace('<span class="wm" ', '<span class="wm" style="font-size:' + px + 'px" ', 1) + '</span>' for px, label in (('14', '14 px'), ('24', '24 px (Home header)'), ('44', '44 px')))
open(os.path.join(root_out, 'colors.html'), 'w', encoding='utf-8').write(fonts(rd('colors.tpl.html').replace('__WORDMARK_CSS__', WORDMARK_CSS).replace('__WORDMARK_SIZES__', WM_SIZES).replace('__WORDMARK__', WORDMARK).replace('__TOKENS__', tokens)))
print('built landing index.html + colors.html ->', root_out)
