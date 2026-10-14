import json, os, re, sys
# usage: python3 build.py <out_root>   -> writes <out_root>/es and <out_root>/en (self-contained, offline pages)
src = os.path.dirname(os.path.abspath(__file__))
root_out = sys.argv[1]
rd = lambda n: open(os.path.join(src, n), encoding='utf-8').read()
css, calc, mascot, app, tpl, strings, idx_tpl = rd('style.css'), rd('calc.js'), rd('mascot.js'), rd('app.js'), rd('template.html'), rd('strings.js'), rd('index.tpl.html')
font_reg = '../_src/fonts/Unkempt-Regular-latin.woff2'
font_bold = '../_src/fonts/Unkempt-Bold-latin.woff2'
css = css.replace('url(data:font/woff2;base64,__UNKEMPT_REG_B64__)', 'url(' + font_reg + ')')
css = css.replace('url(data:font/woff2;base64,__UNKEMPT_B64__)', 'url(' + font_bold + ')')
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
