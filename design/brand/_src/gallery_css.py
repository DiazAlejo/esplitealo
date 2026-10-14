"""CSS of the gallery (round 2's stylesheet, extended in build_gallery.py)."""
CSS = r'''
@font-face{font-family:"Unkempt";font-weight:700;font-style:normal;src:url(data:font/woff2;base64,%FONT%) format("woff2")}
:root{--paper:#FBF7EF;--ink:#1E2933;--ink2:#5B6670;--line:#DDD3BE;--primary:#1F7A5A;--page:#F1ECE0;--card:#FFFFFF;--night:#14181C;--gold:#B87A00;
 --ft:-apple-system,BlinkMacSystemFont,"SF Pro Text",system-ui,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%;scroll-behavior:smooth}
body{margin:0;background:var(--page);color:var(--ink);font:16px/1.5 var(--ft)}
.wrap{max-width:1100px;margin:0 auto;padding:0 16px 80px}
h1,h2,.h2,.num,.badge{font-family:"Unkempt",var(--ft);font-weight:700;text-transform:uppercase;letter-spacing:.02em}
h1{font-size:clamp(34px,7vw,62px);line-height:1.05;margin:36px 0 8px;color:var(--primary)}
h2{font-size:clamp(26px,5vw,38px);line-height:1.1;margin:52px 0 6px;scroll-margin-top:64px}
.h2{font-size:clamp(24px,4.6vw,34px);line-height:1.1;margin:0}
h3{font-size:13px;letter-spacing:.09em;text-transform:uppercase;color:var(--ink2);margin:30px 0 10px;font-weight:700}
h4{font-size:13px;letter-spacing:.08em;text-transform:uppercase;color:var(--ink2);margin:26px 0 8px;font-weight:700}
p{margin:.5em 0 1em}
a{color:var(--primary)}
code{font:13px ui-monospace,SFMono-Regular,Menlo,monospace;background:#0001;padding:1px 5px;border-radius:4px;overflow-wrap:anywhere}
.lead{font-size:18px;max-width:780px}
.note{font-size:13px;color:var(--ink2);max-width:860px}
nav.top{position:sticky;top:0;z-index:20;background:#F1ECEAe6;backdrop-filter:blur(8px);border-bottom:1px solid var(--line);margin:0 -16px;padding:8px 16px;display:flex;gap:6px 14px;flex-wrap:wrap;font-size:14px}
nav.top a{text-decoration:none;font-weight:600;color:var(--ink);padding:4px 2px}
.card{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:18px 20px;margin:14px 0}
.card h4:first-child{margin-top:0}
.tablewrap{overflow-x:auto;-webkit-overflow-scrolling:touch}
table{border-collapse:collapse;width:100%}
td,th{padding:8px 10px;border-bottom:1px solid var(--line);text-align:left;font-size:14px;vertical-align:top}
th{font-size:12px;letter-spacing:.06em;text-transform:uppercase;color:var(--ink2)}
td.tnum{white-space:nowrap;font-variant-numeric:tabular-nums;font-weight:600}
.sw{display:inline-block;width:22px;height:22px;border-radius:6px;border:1px solid #0002;margin-right:6px;vertical-align:middle}
.pt td:nth-child(2){white-space:nowrap}
.nt td:first-child{min-width:150px}.nt td:nth-child(2){min-width:120px}.nt td:nth-child(3){min-width:150px}
/* hero */
.hero{display:grid;grid-template-columns:minmax(0,300px) 1fr;gap:26px;align-items:center;background:var(--card);border:1px solid var(--line);border-radius:22px;padding:22px;margin:18px 0}
.hero .big{width:100%;max-width:300px}
.hero ul{margin:6px 0 0;padding-left:18px}.hero li{margin:6px 0}
.badge{display:inline-block;font-size:12px;padding:3px 10px;border-radius:12px;vertical-align:middle;background:var(--ink);color:#fff;margin-left:6px;letter-spacing:.04em}
.badge.top{background:var(--primary)}.badge.run{background:#7A5E1E}
/* icons */
.icow{display:inline-block;filter:drop-shadow(0 1px 1.5px rgba(0,0,0,.28));line-height:0;vertical-align:top;width:var(--s,auto)}
.ico{display:block;width:100%;height:100%;clip-path:url(#squircle);overflow:hidden}
.ico.sq{clip-path:none}
.ico svg{display:block}
.ico.ph{display:flex;align-items:center;justify-content:center}
.ico.ink29{background:#fff;display:flex;align-items:center;justify-content:center;padding:18%}
.sym29{width:100%;height:100%}
.raw{display:inline-block;line-height:0;outline:1px dashed #0004;outline-offset:3px}
.ov{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:12px}
.ovi{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:14px;text-decoration:none;color:var(--ink);display:block}
.ovi.pick{border-color:var(--primary);box-shadow:0 0 0 2px #1F7A5A33}
.ovi b{display:block;margin-top:8px}.ovi small{color:var(--ink2)}
.ovrow{display:flex;gap:10px;align-items:flex-end;flex-wrap:wrap}
.concept{background:var(--card);border:1px solid var(--line);border-radius:22px;padding:22px 22px 26px;margin:26px 0;scroll-margin-top:60px}
.concept.picked{border-color:#1F7A5A88}
.concept>header{display:flex;gap:14px;align-items:center}
.num{width:44px;height:44px;border-radius:50%;background:var(--primary);color:#fff;display:flex;align-items:center;justify-content:center;font-size:21px;flex:none}
.tag{margin:0;font-size:12px;letter-spacing:.09em;text-transform:uppercase;color:var(--ink2);font-weight:700}
.what{max-width:780px;font-size:17px}
.row3{display:flex;gap:30px;flex-wrap:wrap;align-items:flex-start}
.mono2{display:flex;gap:16px;flex-wrap:wrap}
figure{margin:0}
figcaption{font-size:13px;color:var(--ink2);margin-top:8px;max-width:300px;line-height:1.35}
.monobox{width:150px;height:150px;border-radius:30px;background:#fff;border:1px solid var(--line);display:flex;align-items:center;justify-content:center;padding:22px}
.monobox.dk{background:var(--night);border-color:#000}
.symimg{width:100%;height:100%}
.sizes{display:flex;gap:22px;flex-wrap:wrap;align-items:flex-end;padding:16px 18px;border-radius:16px;margin:10px 0;position:relative}
.sizes .lad{position:absolute;top:6px;right:12px;font-size:11px;letter-spacing:.08em;text-transform:uppercase;opacity:.6}
.sizes.onlight{background:linear-gradient(160deg,#E8E2D4,#D5DAE0)}
.sizes.ondark{background:linear-gradient(160deg,#0B0D10,#1C2530);color:#fff}
.sizes.ondark figcaption{color:#A5AEB6}
.sizes figure.big .icow{width:min(100%,200px);aspect-ratio:1}
.sizes figure.big{width:min(100%,200px)}
.pc{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:20px}
.pc ul{margin:0;padding-left:18px}.pc li{margin:6px 0}
.files{font-size:13px;color:var(--ink2);margin-top:18px}
/* palettes */
.mx{display:grid;grid-template-columns:minmax(120px,170px) repeat(3,minmax(0,1fr));gap:8px 10px;align-items:center;background:var(--card);border:1px solid var(--line);border-radius:16px;padding:14px}
.mxh{font-size:12px;letter-spacing:.06em;text-transform:uppercase;color:var(--ink2);font-weight:700}
.mxl small{display:block;color:var(--ink2)}
.mxc{display:flex;justify-content:center}
.pcard{background:var(--card);border:1px solid var(--line);border-radius:20px;padding:16px 18px 20px;margin:16px 0}
.pch{display:flex;gap:12px;align-items:center;margin-bottom:12px}.pcs .sw{width:34px;height:34px;margin:0}
.phones{display:flex;gap:22px;flex-wrap:wrap;align-items:flex-start}
.plabel{font-size:13px;color:var(--ink2);margin:0 0 8px}
.phone{width:290px;height:612px;border-radius:44px;position:relative;overflow:hidden;border:7px solid #1b1d20;background-origin:border-box;box-shadow:0 10px 30px rgba(0,0,0,.18)}
.phone.light{background:linear-gradient(170deg,#BFD9EA 0%,#F3DDC9 55%,#EFC9B8 100%)}
.phone.dark{background:linear-gradient(170deg,#0E1620 0%,#1C2A3A 60%,#16202C 100%)}
.notch{position:absolute;top:9px;left:50%;width:84px;height:24px;margin-left:-42px;background:#000;border-radius:14px;z-index:3}
.stat{position:absolute;top:12px;left:24px;right:24px;display:flex;justify-content:space-between;font:600 13px var(--ft);color:#fff;z-index:2}
.phone.light .stat{color:#10202c}
.grid{position:absolute;top:58px;left:16px;right:16px;display:grid;grid-template-columns:repeat(4,1fr);gap:14px 6px}
.cell{display:flex;flex-direction:column;align-items:center;gap:4px}
.cell .icow{width:52px;height:52px}
.lbl{font:500 10px/1.1 var(--ft);color:#fff;text-shadow:0 1px 2px #0007;white-space:nowrap}
.phone.light .lbl{color:#10202c;text-shadow:none}
.dock{position:absolute;left:10px;right:10px;bottom:20px;height:74px;border-radius:28px;background:rgba(255,255,255,.28);display:flex;justify-content:space-around;align-items:center;padding:0 6px}
.phone.dark .dock{background:rgba(255,255,255,.12)}
.dock .icow{width:52px;height:52px}
.hind{position:absolute;bottom:6px;left:50%;width:100px;height:4px;margin-left:-50px;border-radius:2px;background:#fff8}
.phone.light .hind{background:#0007}
.rankcards{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:14px}
.rk .rkh{display:flex;gap:12px;align-items:center;margin-bottom:6px}.rk h4{margin:0;font-size:15px}
.rk .num{width:34px;height:34px;font-size:17px}
.rk p{font-size:14px;margin:.4em 0}.rk .rel{color:var(--ink2)}
/* lockups */
.lk{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:12px}
.lkp{border-radius:16px;padding:26px 22px 12px;border:1px solid var(--line);display:flex;flex-direction:column;gap:14px;justify-content:space-between}
.lkp svg{width:100%;height:auto;max-height:170px;margin:auto 0}
.lkp span{font-size:12px;color:var(--ink2)}
.lkp.paper{background:var(--paper)}.lkp.night{background:var(--night);border-color:#000}.lkp.night span{color:#A5AEB6}
.lkp.mono{background:#fff}.lkp.primary{background:var(--primary);border-color:var(--primary)}.lkp.primary span{color:#D5EFE3}
.wl{fill:var(--wl)}.wa{fill:var(--wa)}
.lkh{margin-top:30px}
/* layers */
.expl{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:14px}
.chk{background-color:#fff;background-image:linear-gradient(45deg,#e6e6e6 25%,transparent 25%,transparent 75%,#e6e6e6 75%),linear-gradient(45deg,#e6e6e6 25%,transparent 25%,transparent 75%,#e6e6e6 75%);background-size:20px 20px;background-position:0 0,10px 10px;border:1px solid var(--line);border-radius:14px;overflow:hidden;line-height:0}
.chk svg{width:100%;height:auto}
.rend{display:flex;gap:14px;flex-wrap:wrap;padding:16px;border-radius:16px;background:linear-gradient(160deg,#6F86A6,#9FB3CE)}
.rend figure{width:150px}.rend img{display:block;width:150px;height:150px}
.rend figcaption{color:#fff;font-size:12px;text-shadow:0 1px 2px #0005}
pre{background:#0001;border-radius:12px;padding:12px 14px;overflow-x:auto;font:12.5px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace}
.rank{list-style:none;padding:0;margin:0}
.rank li{display:flex;gap:14px;align-items:center;padding:12px 0;border-bottom:1px solid var(--line)}
.rank li:last-child{border:0}
.rank .bd{font:700 20px "Unkempt",var(--ft);width:38px;height:38px;border-radius:50%;background:var(--ink);color:#fff;display:flex;align-items:center;justify-content:center;flex:none}
.rank li:first-child .bd{background:var(--primary)}
.rank p{margin:2px 0 0;font-size:14px;color:var(--ink2)}
.q li{margin:10px 0}
.warnbox{border-left:4px solid #C23A1D;background:#C23A1D12;padding:10px 14px;border-radius:0 10px 10px 0;margin:14px 0;font-size:14px}
@media (max-width:760px){.hero{grid-template-columns:1fr}.hero .big{max-width:240px}}
@media (max-width:640px){.nt thead{display:none}.nt,.nt tbody,.nt tr,.nt td{display:block;width:100%}.nt tr{border-bottom:1px solid var(--line);padding:8px 0}.nt td{border:0;padding:2px 0;min-width:0!important}.nt td:nth-child(2),.nt td:nth-child(3){color:var(--ink2);font-size:13px}nav.top{position:static}.concept{padding:16px 14px 22px;border-radius:18px}.sizes{gap:16px;padding:14px}.phones{justify-content:center}.mx{grid-template-columns:minmax(78px,100px) repeat(3,minmax(0,1fr));gap:6px}.mx .icow{width:64px!important;height:64px!important}.row3{gap:18px}}
'''
