/* Esplitéalo — clickable HTML mockup engine. One app, started on any screen via window.ESP_START. */
(function () {
  'use strict';
  var Calc = window.Calc, R = window.Raccoon, T = window.ESP_T, LANG = T.lang;
  var START = window.ESP_START || { screen: 'home' };
  var root = document.documentElement;
  var qs = new URLSearchParams(location.search);
  var EMBED = qs.get('embed') === '1';
  // Person + share-sheet colours: proposed (default) or previous. ?people=old|new switches both; ?share=old|new overrides the share sheet only.
  function setPeople(v) {
    root.dataset.people = v === 'old' ? 'old' : 'new';
    root.dataset.share = root.dataset.people;
    document.querySelectorAll('[data-people-btn]').forEach(function (b) { b.setAttribute('aria-pressed', b.dataset.peopleBtn === root.dataset.people); });
    try { var u = new URL(location.href); if (root.dataset.people === 'old') u.searchParams.set('people', 'old'); else u.searchParams.delete('people'); u.searchParams.delete('share'); history.replaceState(null, '', u.toString()); } catch (e) {}
  }
  function keepQ() { var p = []; p.push('theme=' + root.dataset.theme); if (root.dataset.people === 'old') p.push('people=old'); return p.join('&'); }

  /* ------------------------------------------------------------ helpers */
  function fmt(c) { var n = c < 0; c = Math.abs(c); return (n ? '−' : '') + '$' + Math.floor(c / 100) + '.' + ('0' + (c % 100)).slice(-2); }
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  function parseCents(s) {
    var m = String(s).replace(/[$,\s]/g, '').match(/^(\d*)(?:\.(\d{0,2}))?$/);
    if (!m || (m[1] === '' && !m[2])) return null;
    return parseInt(m[1] || '0', 10) * 100 + parseInt(((m[2] || '') + '00').slice(0, 2), 10);
  }
  function reduced() { return root.dataset.reduce === '1' || (window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches); }
  function sum(a, f) { return a.reduce(function (x, y) { return x + f(y); }, 0); }
  function ic(n) {
    var P = {
      back: '<path d="M15 5 L8 12 L15 19"/>', next: '<path d="M9 5 L16 12 L9 19"/>',
      camera: '<path d="M3.5 8.5h3.2l1.8-2.8h7l1.8 2.8h3.2v10.5h-17z"/><circle cx="12" cy="13.6" r="3.6"/>',
      photo: '<rect x="3.5" y="4.5" width="17" height="15" rx="3"/><circle cx="9" cy="10" r="1.8"/><path d="M4 17.5l4.8-4.6 3.6 3.4 2.6-2.4 5 4.2"/>',
      check: '<path d="M5 12.5l4.6 4.6L19 7.4"/>', plus: '<path d="M12 5v14M5 12h14"/>', x: '<path d="M6 6l12 12M18 6L6 18"/>',
      warn: '<path d="M12 4.2L21 19.5H3z"/><path d="M12 10v4.2M12 16.9v.2"/>',
      share: '<path d="M12 3.5v11M8 7.2l4-3.7 4 3.7M6 11.5H5.2v8.3h13.6v-8.3H18"/>',
      help: '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.6 2.6 0 1 1 3.6 2.4c-.7.4-1.1.9-1.1 1.8M12 16.8v.2"/>',
      bolt: '<path d="M13 3L5.5 13.5H11L10 21l7.5-10.5H12z"/>',
      info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5.5M12 7.6v.2"/>',
      doc: '<path d="M7 3.5h7l4 4v13H7z"/><path d="M14 3.5v4h4"/>',
      chevd: '<path d="M6 9l6 6 6-6"/>', chevu: '<path d="M6 15l6-6 6 6"/>',
      lock: '<rect x="5" y="10.5" width="14" height="9.5" rx="2.5"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5"/>'
    };
    return '<svg class="ico" viewBox="0 0 24 24" aria-hidden="true">' + (P[n] || '') + '</svg>';
  }

  // The ÷ motif (two dots and a bar) from the logo: pink, decorative, never carries meaning on its own.
  var DIV = '<svg class="divmark" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="4.6" r="2.5"/><rect x="3" y="10.4" width="18" height="3.2" rx="1.6"/><circle cx="12" cy="19.4" r="2.5"/></svg>';

  /* ------------------------------------------------------------ sample data */
  var PRICES = [400, 500, 1400, 2200, 1800, 1400, 1500, 900]; // the receipt exactly as printed (juice, beer, starter, mains, dessert)
  var PRINTED = PRICES.map(function (c, i) { return [T.itemNames[i], c]; });
  var WHO_MID = { 2: ['b'], 3: ['a', 'b', 'c'], 4: ['a'], 5: ['b'], 6: ['c'], 7: ['d'] };
  var WHO_ALL = { 1: ['d'], 2: ['b'], 3: ['a', 'b', 'c'], 4: ['a'], 5: ['b'], 6: ['c'], 7: ['d'], 8: ['a', 'b', 'c', 'd'] };
  var NAMES = [['a', 'Marisol', 1], ['b', 'Héctor', 2], ['c', 'Keishla', 3], ['d', 'Yadiel', 4]];
  var RECEIPT = { subtotal: 10100, tax: 1162, total: 11262 };
  var RECEIPT_SVC = { subtotal: 10100, tax: 1162, service: 1515, total: 12777 };

  function makeItems(opts) {
    return PRINTED.map(function (p, i) {
      var id = i + 1, bad = opts.bad && id === 8;
      return { id: id, name: p[0], price: bad ? 1900 : p[1], flag: bad ? 'price' : null, who: (opts.who && opts.who[id] || []).slice() };
    });
  }
  function dataset(name) {
    var bad = name === 'scanned' || name === 'complete-bad';
    var full = name === 'complete' || name === 'complete-bad' || name === 'service';
    var who = name === 'midway' ? WHO_MID : full ? WHO_ALL : null;
    var people = (name === 'midway' || full) ? NAMES.map(function (n) { return { id: n[0], name: n[1], slot: n[2] }; }) : [];
    var svc = name === 'service';
    // when the receipt already shows a service charge the tip starts at $0 (design decision)
    return { items: makeItems({ bad: bad, who: who }), people: people, receipt: Object.assign({}, svc ? RECEIPT_SVC : RECEIPT), tip: svc ? { mode: 'custom', cents: 0 } : { mode: 'pct', pct: 18 } };
  }

  /* ------------------------------------------------------------ state */
  var S = {
    screen: START.screen || 'home', data: START.data || 'scanned',
    tip: START.tip || null,
    cap: START.cap || 'live', proc: { failed: !!START.failed, manual: false, showManual: false },
    thumb: !!START.thumb, paint: START.paint || null, warn: !!START.warn,
    sheet: START.sheet || null, draft: {}, expanded: {}, toast: null, fromFlow: false, nextId: 100, nextPerson: 10
  };
  (function apply(d) { S.items = d.items; S.people = d.people; S.receipt = d.receipt; if (!S.tip) S.tip = d.tip; })(dataset(S.data));
  if (START.items) START.items(S);
  var LAST = {};

  /* ------------------------------------------------------------ derived */
  function issues() {
    var items = sum(S.items, function (i) { return i.price; }), r = S.receipt, out = [];
    if (items !== r.subtotal) out.push({ kind: 'subtotal', diff: items - r.subtotal, items: items });
    else if (r.subtotal + r.tax + (r.service || 0) !== r.total) out.push({ kind: 'total', diff: r.subtotal + r.tax + (r.service || 0) - r.total, calc: r.subtotal + r.tax + (r.service || 0) });
    return out;
  }
  function tipCents() { return S.tip.mode === 'pct' ? Calc.tipFromPct(S.receipt.subtotal, S.tip.pct) : S.tip.cents; }
  function bill() { return Calc.computeBill({ items: S.items, people: S.people, tax: S.receipt.tax, service: S.receipt.service || 0, tip: tipCents() }); }
  function person(id) { return S.people.filter(function (p) { return p.id === id; })[0]; }
  function av(p, cls) { return '<span class="av s' + p.slot + ' ' + (cls || '') + '" aria-hidden="true">' + esc(p.name.charAt(0).toUpperCase()) + '</span>'; }
  function shareOf(item) { // person -> cents for an item
    var ids = S.people.map(function (p) { return p.id; }).filter(function (id) { return item.who.indexOf(id) >= 0; });
    return Calc.splitEqual(item.price, ids);
  }
  function itemById(id) { return S.items.filter(function (i) { return i.id === id; })[0]; }
  function subtotalOf(pid) { return sum(S.items, function (it) { var s = shareOf(it); return s[pid] || 0; }); }
  function unassigned() { return S.items.filter(function (i) { return !i.who.length; }); }
  function amt(key, cents, cls) { return '<span class="' + (cls || 't-amount') + '" data-amt data-key="' + key + '" data-v="' + cents + '">' + fmt(cents) + '</span>'; }
  function summaryText(b) {
    var X = T.share, svc = S.receipt.service || 0, conf = S.receipt.total + tipCents();
    var t = X.head(T.merchant, T.dateShort, fmt(S.receipt.total), S.tip.mode === 'pct' ? X.tipPct(S.tip.pct) : X.tipFlat, fmt(tipCents()), fmt(conf), svc ? fmt(svc) : '');
    b.rows.forEach(function (r) { t += X.person(person(r.id).name, fmt(r.total), fmt(r.items), fmt(r.tax), svc ? fmt(r.service) : '', fmt(r.tip)); });
    return t + X.close(fmt(b.total));
  }
  function stepLabel(n) { // five dots (done in green, the current step in pink, the rest quiet) plus the words, which stay the real signal
    var d = ''; for (var i = 1; i <= 5; i++) d += '<i class="' + (i < n ? 'done' : i === n ? 'now' : '') + '"></i>';
    return '<span class="step"><span class="steps" aria-hidden="true">' + d + '</span>' + T.step(n) + '</span>';
  }
  function nav(label, to, step) {
    return '<div class="nav"><button class="back" data-act="go" data-to="' + to + '">' + ic('back') + esc(label) + '</button>' + (step ? stepLabel(step) : '') + '</div>';
  }

  /* ------------------------------------------------------------ receipt paper (a "photo" of the receipt) */
  function paper(opts) {
    opts = opts || {};
    var P = T.paper, svc = S.receipt && S.receipt.service;
    var fs = opts.fs || 11, rows = PRINTED.map(function (p, i) {
      var hl = opts.mark && i === 7;
      return '<div class="pl' + (hl ? ' hl' : '') + '"><span>1 ' + esc(p[0]) + '</span><span>' + (p[1] / 100).toFixed(2) + '</span></div>';
    }).join('');
    return '<div class="paper" style="font-size:' + fs + 'px;' + (opts.style || '') + '"><div class="pc big">' + esc(T.merchant.toUpperCase()) + '</div><div class="pc">' + P.addr + '</div><div class="pc">' + P.when + '</div><div class="pd"></div>' +
      rows + '<div class="pd"></div><div class="pl"><span>' + P.sub + '</span><span>101.00</span></div><div class="pl"><span>' + P.tax + '</span><span>11.62</span></div>' + (svc ? '<div class="pl"><span>' + P.service + '</span><span>15.15</span></div>' : '') + '<div class="pl b"><span>' + P.total + '</span><span>' + (svc ? '127.77' : '112.62') + '</span></div><div class="pc" style="margin-top:.6em">' + P.thanks + '</div></div>';
  }

  /* ------------------------------------------------------------ screens */
  var V = {};

  V.home = function () {
    var H = T.home;
    return '<div class="view"><div class="scroll" data-scroll="home" style="padding-top:4px">' +
      '<div style="display:flex;align-items:center;justify-content:space-between;height:48px;margin:0 -4px 0 0">' +
        '<div class="brand" style="display:flex;align-items:center;gap:8px">' + R.mark(34) + window.ESP_WM + '</div>' +
        '<button class="back" style="padding:0 6px" data-act="sheet" data-type="how" aria-label="' + esc(H.how) + '">' + ic('help') + '<span style="font-size:15px;margin-left:4px">' + H.how + '</span></button></div>' +
      '<div style="display:flex;justify-content:center;margin:2px 0 6px">' + R.scenes.home(250) + '</div>' +
      '<div style="display:flex;justify-content:center;margin:0 0 10px"><span class="say">' + H.bubble + '</span></div>' +
      '<div style="text-align:center;margin:2px 4px 16px"><h1 class="t-title" style="margin:0">' + H.title + '</h1>' +
      '<p class="t-sub" style="margin:8px 0 0">' + H.sub + '</p></div>' +
      '<button class="btn btn-primary" data-act="start-scan" style="min-height:58px">' + ic('camera') + H.scan + '</button>' +
      '<button class="btn btn-secondary" data-act="start-photo" style="margin-top:12px">' + ic('photo') + H.photo + '</button>' +
      '<div class="t-foot" style="display:flex;gap:6px;align-items:center;justify-content:center;margin:14px 0 0">' + ic('lock') + H.privacy + '</div>' +
      '<div class="group-label" style="margin-top:22px">' + H.recent + '</div><div class="card" style="overflow:hidden">' +
      T.recent.map(function (r, i) {
        return '<button class="rbill" data-act="toast" data-msg="' + esc(H.placeholder) + '" style="' + (i ? 'border-top:1px solid var(--line)' : '') + '"><span><b class="t-head" style="display:block">' + r[0] + '</b><span class="t-foot">' + r[1] + ' · ' + H.people(r[3]) + '</span></span>' + amt('rb' + i, r[2], 't-amount') + '</button>';
      }).join('') + '</div></div></div>';
  };

  V.capture = function () {
    var C = T.cap;
    if (S.cap === 'denied') {
      return '<div class="view">' + nav(C.cancel, 'home') + '<div class="scroll" style="display:flex;flex-direction:column;justify-content:center;gap:16px;padding-bottom:60px">' +
        '<div class="card" style="padding:24px 20px;text-align:center"><div style="display:flex;justify-content:center"><span class="disc">' + R.svg('thinking', 100) + '<svg class="stk" viewBox="0 0 24 24" aria-hidden="true" fill="var(--pink)">' + R.DIVG + '</svg></span></div>' +
        '<h2 class="t-title" style="margin:6px 0 8px;font-size:24px">' + C.deniedTitle + '</h2>' +
        '<p class="t-sub" style="margin:0 0 18px">' + C.deniedBody + '</p>' +
        '<button class="btn btn-primary" data-act="toast" data-msg="' + esc(C.settingsToast) + '">' + C.openSettings + '</button></div>' +
        '<button class="btn btn-secondary" data-act="start-photo">' + ic('photo') + C.choose + '</button></div></div>';
    }
    var shot = S.cap === 'captured';
    return '<div class="view dark-view" style="background:var(--dev-island);padding-top:0"><div class="vf' + (shot ? ' frozen' : '') + '">' +
      '<div class="table"></div><div class="edge' + (shot ? ' snap' : '') + '" style="position:absolute;left:50%;top:50%;width:262px;margin:-232px 0 0 -131px;transform:rotate(-2.2deg)">' + paper({ fs: 11.5, style: 'position:relative' }) + '</div>' +
      '<div class="brk" style="left:36px;top:178px"></div><div class="brk r" style="right:36px;top:178px"></div><div class="brk b" style="left:36px;bottom:208px"></div><div class="brk br" style="right:36px;bottom:208px"></div></div>' +
      '<div class="cam-top"><button class="cam-btn" data-act="go" data-to="home">' + C.cancel + '</button>' + (shot ? '' : '<button class="cam-btn" data-act="toast" data-msg="' + esc(C.flashToast) + '" aria-label="' + C.flash + '">' + ic('bolt') + '</button>') + '</div>' +
      '<div class="guide-pill">' + (shot ? ic('check') + C.looks : ic('info') + C.guide) + '</div>' +
      (shot ? '<div class="cam-bottom" style="gap:10px"><button class="btn btn-primary" data-act="use-photo">' + C.use + '</button><button class="btn btn-secondary" data-act="retake" style="background:var(--cam-ghost);color:var(--cam-ink);border-color:var(--cam-edge)">' + C.retake + '</button></div>'
        : '<div class="cam-bottom row"><button class="lib" data-act="start-photo"><span class="lib-th">' + ic('photo') + '</span>' + C.choose + '</button><button class="shutter" data-act="shutter" aria-label="' + C.shutter + '"><i></i></button><span style="width:76px"></span></div>') +
      '<div class="flash" id="flash"></div></div>';
  };

  V.processing = function () {
    var P = T.proc, failed = S.proc.failed;
    if (failed) {
      return '<div class="view">' + nav(P.back, 'capture') + '<div class="scroll" style="display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;text-align:center;padding-bottom:30px">' +
        R.scenes.failed(250) + '<h1 class="t-title" style="margin:6px 0 0">' + P.failTitle + '</h1>' +
        '<p class="t-sub" style="margin:0 12px 14px">' + P.failBody + '</p>' +
        '<button class="btn btn-primary" data-act="retry">' + P.retry + '</button><button class="btn btn-secondary" data-act="manual">' + P.manual + '</button>' +
        '<button class="btn-quiet" data-act="go" data-to="capture">' + P.another + '</button></div></div>';
    }
    return '<div class="view">' + nav(P.cancel, 'capture') + '<div class="scroll" style="display:flex;flex-direction:column;align-items:center;justify-content:center;gap:12px;text-align:center;padding-bottom:40px">' +
      R.scenes.processing(260) + '<h1 class="t-title" style="margin:8px 0 0" id="pmsg" aria-live="polite">' + P.msgs[0] + '</h1>' +
      '<div class="ibar" role="progressbar" aria-label="' + esc(P.bar) + '"><i></i></div>' +
      '<p class="t-foot" style="margin:0 20px">' + P.foot + '</p>' +
      '<div style="width:100%;min-height:56px;margin-top:10px">' + (S.proc.showManual ? '<button class="btn btn-secondary fadein" data-act="manual">' + P.manual + '</button>' : '') + '</div></div></div>';
  };

  V.review = function () {
    var Rv = T.rev, iss = issues(), r = S.receipt, svc = r.service || 0, items = sum(S.items, function (i) { return i.price; });
    var banner = '';
    if (!S.items.length) banner = '';
    else if (iss.length) {
      var i0 = iss[0];
      var msg = i0.kind === 'subtotal' ? Rv.warnSub(fmt(i0.items), fmt(r.subtotal)) : (svc ? Rv.warnTotSvc : Rv.warnTot)(fmt(i0.calc), fmt(r.total));
      banner = '<div class="banner warn" role="alert"><div class="rc-wrap">' + R.svg('worried', 62) + '</div><div><b>' + Rv.warnTitle + '</b><div class="t-foot" style="color:var(--ink)">' + msg + Rv.diff(fmt(Math.abs(i0.diff))) + (i0.kind === 'subtotal' ? Rv.checkRow : Rv.checkAmts) + '</div></div></div>';
    } else banner = '<div class="banner ok"><span class="b-ico">' + ic('check') + '</span><div><b>' + Rv.okTitle + '</b><div class="t-foot">' + Rv.okBody + '</div></div></div>';

    var rowHTML = function (it) {
      var flag = it.flag === 'price';
      return '<button class="rrow' + (flag ? ' flag' : '') + '" data-act="sheet" data-type="edit-item" data-id="' + it.id + '"><span class="rr-l"><span class="t-body">' + esc(it.name) + '</span>' +
        (flag ? '<span class="pill warn" style="margin-top:4px;align-self:flex-start">' + ic('warn') + Rv.flag + '</span>' : '') + '</span>' + amt('ri' + it.id, it.price, 't-amount' + (flag ? ' warn-t' : '')) + '</button>';
    };
    var flagged = S.items.filter(function (i) { return i.flag; }), plain = S.items.filter(function (i) { return !i.flag; });
    var field = function (key, label, val, bad, note) {
      return '<button class="frow' + (bad ? ' bad' : '') + '" data-act="sheet" data-type="edit-field" data-field="' + key + '"><span><span class="t-body">' + label + '</span>' + (note ? '<span class="t-foot" style="display:block;' + (bad ? 'color:var(--warn)' : '') + '">' + note + '</span>' : '') + '</span><span style="display:flex;align-items:center;gap:8px">' + (bad ? '<span class="pill warn">' + ic('warn') + Rv.check + '</span>' : '') + amt('f' + key, val, 't-amount' + (bad ? ' warn-t' : '')) + '</span></button>';
    };
    var sBad = iss[0] && iss[0].kind === 'subtotal', tBad = iss[0] && iss[0].kind === 'total';
    var empty = !S.items.length;
    return '<div class="view">' + nav(Rv.back, 'capture', 2) + '<div class="head"><h1 class="t-title">' + Rv.title + '</h1><p class="t-sub">' + Rv.sub + '</p></div>' +
      '<div class="scroll" data-scroll="review" style="padding-bottom:16px">' +
      '<div class="card thumb' + (S.thumb ? ' open' : '') + '"><button class="thumb-h" data-act="thumb" aria-expanded="' + S.thumb + '"><span class="th-mini">' + paper({ fs: 3.4, style: 'width:70px;pointer-events:none' }) + '</span><span><b class="t-head" style="display:block">' + Rv.origTitle + '</b><span class="t-foot">' + (S.thumb ? Rv.origOpen : Rv.origClosed) + '</span></span><span style="margin-left:auto;color:var(--ink2)">' + ic(S.thumb ? 'chevu' : 'chevd') + '</span></button>' +
      (S.thumb ? '<div class="th-body">' + paper({ fs: 12, mark: S.data === 'scanned' || S.items.some(function (i) { return i.flag; }), style: 'width:250px;margin:0 auto' }) + (S.items.some(function (i) { return i.flag; }) ? '<div class="t-foot" style="text-align:center;margin-top:8px">' + Rv.origNote('$9.00', '$19.00') + '</div>' : '') + '</div>' : '') + '</div>' +
      '<div style="margin:12px 0">' + banner + '</div>' +
      (empty ? '<div class="card" style="padding:22px;text-align:center"><div style="display:flex;justify-content:center">' + R.svg('neutral', 96) + '</div><b class="t-head" style="display:block;margin-top:6px">' + Rv.empty + '</b><p class="t-sub" style="margin:4px 0 0">' + Rv.emptyBody + '</p></div>' :
        (flagged.length ? '<div class="group-label" style="margin-top:6px;color:var(--warn)">' + Rv.needsLook + ' · ' + flagged.length + '</div><div class="card" style="overflow:hidden;border-color:var(--warn)">' + flagged.map(rowHTML).join('') + '</div>' : '') +
        '<div class="group-label" style="margin-top:' + (flagged.length ? 16 : 6) + 'px">' + Rv.items + ' · ' + plain.length + '</div><div class="card" style="overflow:hidden">' + plain.map(rowHTML).join('') + '</div>') +
      '<button class="btn btn-secondary sm" data-act="add-item" style="margin-top:12px">' + ic('plus') + Rv.add + '</button>' +
      '<div class="group-label">' + Rv.amounts + '</div><div class="well" style="overflow:hidden">' +
      field('subtotal', Rv.subtotal, r.subtotal, sBad, sBad ? Rv.itemsAddUp(fmt(items)) : '') + field('tax', Rv.tax, r.tax, false, '11.5%') +
      (svc ? field('service', Rv.service, svc, false, '15%') : '') +
      field('total', Rv.total, r.total, tBad, tBad ? (svc ? Rv.subPlusTaxSvc : Rv.subPlusTax)(fmt(r.subtotal + r.tax + svc)) : '') + '</div></div>' +
      '<div class="footer bar"><button class="btn btn-primary' + (empty ? ' is-disabled' : '') + '" data-act="review-continue">' + Rv.cont + '</button></div></div>';
  };

  V.people = function () {
    var Pp = T.ppl, n = S.people.length, d = S.draft.person || '';
    var rows = S.people.map(function (p, i) {
      var cnt = S.items.filter(function (it) { return it.who.indexOf(p.id) >= 0; }).length;
      return '<div class="prow2">' + av(p, 'lg' + (i >= 8 ? ' dotted' : '')) + '<div style="flex:1;min-width:0"><b class="t-head" style="display:block">' + esc(p.name) + '</b><span class="t-foot">' + (cnt ? Pp.assigned(cnt) : Pp.none) + '</span></div>' +
        '<button class="mini" data-act="sheet" data-type="rename" data-id="' + p.id + '">' + Pp.rename + '</button><button class="mini warn-t" data-act="remove-person" data-id="' + p.id + '">' + Pp.remove + '</button></div>';
    }).join('');
    return '<div class="view">' + nav(Pp.back, 'review', 3) + '<div class="head"><h1 class="t-title">' + Pp.title + '</h1><p class="t-sub">' + Pp.sub + '</p></div>' +
      '<div class="scroll" data-scroll="people" style="padding-bottom:16px">' +
      '<div style="display:flex;gap:8px;align-items:stretch"><input class="input" id="pname" placeholder="' + esc(Pp.placeholder) + '" value="' + esc(d) + '" autocomplete="off" maxlength="18" aria-label="' + esc(Pp.placeholder) + '"><button class="btn btn-secondary sm" style="width:auto;padding:0 14px;white-space:nowrap;flex:none" data-act="add-person">' + ic('plus') + Pp.add + '</button></div>' +
      '<div class="t-foot" id="perr" style="margin:6px 2px 0;min-height:18px;color:var(--warn)">' + (S.draft.err || '') + '</div>' +
      (n ? '<div class="group-label" style="margin-top:6px">' + Pp.atTable(n) + '</div><div class="card" style="overflow:hidden">' + rows + '</div>' :
        '<div style="text-align:center;margin-top:18px"><div style="display:flex;justify-content:center">' + R.scenes.empty(290) + '</div><h2 class="t-title" style="font-size:22px;margin:10px 0 4px">' + Pp.emptyTitle + '</h2><p class="t-sub" style="margin:0 24px">' + Pp.emptyBody + '</p></div>') +
      '</div><div class="footer bar"><button class="btn btn-primary' + (n ? '' : ' is-disabled') + '" data-act="people-continue">' + Pp.next + '</button></div></div>';
  };

  function chipsHTML() {
    return '<div class="chips-wrap"><div class="group-label" style="margin:0 20px 2px;font-size:12px">' + T.asg.chips + '</div><div class="chips" data-scroll="chips">' + S.people.map(function (p) {
      return '<button class="chip s' + p.slot + (S.paint === p.id ? ' on' : '') + '" data-act="paint" data-id="' + p.id + '" data-chip="' + p.id + '" aria-pressed="' + (S.paint === p.id) + '">' +
        av(p) + '<span class="chip-tx"><b>' + esc(p.name) + '</b>' + amt('chip' + p.id, subtotalOf(p.id)) + '</span></button>';
    }).join('') + '</div></div>';
  }
  function itemRowHTML(it) {
    var A_ = T.asg, who = S.people.filter(function (p) { return it.who.indexOf(p.id) >= 0; });
    var cls = 'irow' + (S.sheet && S.sheet.type === 'assign' && S.sheet.id === it.id ? ' sel' : ''), r2 = '', bar = '';
    if (!who.length) {
      cls += ' un' + (S.warn ? ' pulse' : '');
      r2 = '<span class="un-dot">' + ic('warn') + '</span><span class="un-t">' + A_.unassigned + '</span><span class="t-foot">' + A_.tapChoose + '</span>';
    } else {
      var sh = shareOf(it), vals = who.map(function (p) { return sh[p.id]; });
      if (who.length === 1) r2 = av(who[0], 'sm') + '<span>' + esc(who[0].name) + '</span>';
      else {
        var same = vals.every(function (v) { return v === vals[0]; });
        r2 = '<span class="av-stack">' + who.map(function (p) { return av(p, 'sm'); }).join('') + '</span><span class="t-foot">' + (same ? A_.equal(fmt(vals[0])) : A_.equalMix(vals.map(fmt).join(' · '))) + '</span>';
      }
    }
    return '<div class="' + cls + '" role="button" tabindex="0" data-act="item" data-id="' + it.id + '" aria-label="' + esc(A_.aria(it.name, fmt(it.price), who.map(function (p) { return p.name; }).join(', '))) + '">' + bar +
      '<div class="ir-main"><div class="ir-1"><span class="t-body ir-name">' + esc(it.name) + '</span>' + amt('it' + it.id, it.price) + '</div><div class="ir-2">' + r2 + '</div></div></div>';
  }
  function assignSheet(id) {
    var A_ = T.asg, it = itemById(id); if (!it) return '';
    var sh = shareOf(it), who = it.who.length, rows = S.people.map(function (p) {
      var on = it.who.indexOf(p.id) >= 0;
      return '<button class="prow' + (on ? ' on' : '') + ' s' + p.slot + '" data-act="toggle" data-id="' + it.id + '" data-pid="' + p.id + '" data-prow="' + p.id + '" role="checkbox" aria-checked="' + on + '"><span class="ck">' + (on ? ic('check') : '') + '</span>' + av(p, 'lg') + '<b class="t-head" style="flex:1">' + esc(p.name) + '</b>' + (on ? '<span class="t-amount num">' + fmt(sh[p.id]) + '</span>' : '<span class="t-foot">—</span>') + '</button>';
    }).join('');
    var vals = Object.keys(sh).map(function (k) { return sh[k]; }), extra = who > 1 && !vals.every(function (v) { return v === vals[0]; });
    var note = !who ? A_.pickOne : who === 1 ? A_.all : A_.splitN(who);
    if (extra) { var firsts = S.people.filter(function (p) { return sh[p.id] === Math.max.apply(null, vals); }).map(function (p) { return p.name; }); note = A_.extra(who, it.price % who, firsts); }
    return '<div class="scrim" data-act="close"></div><div class="sheet' + (LAST.sheetOpen === 'assign' ? ' still' : '') + '" role="dialog" aria-label="' + esc(A_.sheetLabel(it.name)) + '"><div class="grab"></div>' +
      '<div style="display:flex;justify-content:space-between;align-items:baseline;gap:12px"><h3>' + esc(it.name) + '</h3>' + amt('sh-price', it.price) + '</div>' +
      '<div style="display:flex;justify-content:space-between;align-items:center;margin:2px 0 8px"><span class="t-sub">' + A_.who + '</span><button class="link" style="min-width:44px;justify-content:flex-end;font-size:15px" data-act="everyone" data-id="' + it.id + '">' + (it.who.length === S.people.length ? A_.clear : A_.everyone) + '</button></div>' +
      '<div class="prows">' + rows + '</div><div class="t-foot" style="margin:10px 2px 12px;min-height:34px">' + note + '</div><button class="btn btn-primary" data-act="close">' + A_.done + '</button></div>';
  }
  V.assign = function () {
    var A_ = T.asg, n = S.items.length, left = unassigned(), done = n - left.length, all = !left.length;
    var paintName = S.paint && person(S.paint) ? person(S.paint).name : null;
    var footTxt = all ? '<span class="ok-t" style="display:flex;gap:6px;align-items:center;font-weight:600">' + ic('check') + A_.allDone(n) + '</span>' :
      '<span style="color:var(--ink2)">' + A_.left(fmt(sum(left, function (i) { return i.price; })), left.length) + '</span>';
    return '<div class="view">' + nav(A_.back, 'people', 4) +
      '<div class="head" style="padding-bottom:10px"><div style="display:flex;align-items:baseline;justify-content:space-between"><h1 class="t-title">' + A_.title + '</h1><span class="t-sub num" style="color:' + (all ? 'var(--primary)' : 'var(--ink2)') + ';font-weight:600">' + A_.progress(done, n) + (all ? ' ✓' : '') + '</span></div>' +
      '<div class="meter' + (all ? ' done' : '') + '" role="progressbar" aria-valuemin="0" aria-valuemax="' + n + '" aria-valuenow="' + done + '" aria-label="' + esc(A_.meter) + '" style="margin-top:10px"><i style="width:' + (n ? Math.round(done / n * 100) : 0) + '%"></i></div></div>' +
      chipsHTML() +
      (paintName ? '<div class="paintbar s' + person(S.paint).slot + '"><span>' + A_.paintBar(esc(paintName)) + '</span><button class="link" style="min-width:44px;justify-content:flex-end" data-act="paint" data-id="' + S.paint + '">' + A_.done + '</button></div>' : '') +
      '<div class="scroll" data-scroll="assign" style="padding-top:8px;padding-bottom:12px">' +
      (S.warn && left.length ? '<div class="banner flat warn" role="alert" style="margin-bottom:10px">' + '<span class="b-ico">' + ic('warn') + '</span><div><b>' + A_.warnTitle(left.length) + '</b><div class="t-foot">' + A_.warnBody(left.length) + '</div><button class="btn btn-secondary sm" data-act="split-rest" style="margin-top:10px;background:var(--surface)">' + A_.restEven + '</button></div></div>' : '') +
      '<div class="ilist">' + S.items.map(itemRowHTML).join('') + '</div>' +
      (S.paint ? '' : '<p class="t-foot" style="text-align:center;margin:14px 20px 0">' + A_.foot + '</p>') + '</div>' +
      '<div class="footer bar"><div class="t-foot" style="display:flex;justify-content:center;font-size:14px">' + footTxt + '</div><button class="btn btn-primary" id="rsbtn" data-act="review-split">' + A_.btn(all ? 0 : left.length) + '</button></div></div>' +
      (S.sheet && S.sheet.type === 'assign' ? assignSheet(S.sheet.id) : '');
  };

  V.totals = function () {
    var X = T.tot, b = bill(), tip = tipCents(), svc = S.receipt.service || 0, conf = S.receipt.total + tip, un = unassigned(), iss = issues();
    var ok = !un.length && b.total === conf, short = iss[0];
    var banner;
    if (un.length) banner = '<div class="banner flat warn" role="alert"><span class="b-ico">' + ic('warn') + '</span><div><b>' + X.notSettled + '</b><div class="t-foot">' + X.notSettledBody(un.length, fmt(sum(un, function (i) { return i.price; }))) + '</div></div></div>';
    else if (!ok) banner = '<div class="banner flat warn" role="alert"><div class="rc-wrap">' + R.svg('worried', 64) + '</div><div><b>' + X.offTitle(fmt(Math.abs(b.total - conf))) + '</b><div class="t-foot" style="color:var(--ink)">' + X.offBody(short && short.kind === 'subtotal' ? fmt(short.items) : null, fmt(S.receipt.subtotal)) + X.offFix + '</div></div></div>';
    else banner = '<div class="banner flat ok" style="align-items:center"><span class="b-ico" style="margin:0">' + ic('check') + '</span><div style="flex:1"><b class="num">' + X.okTitle(fmt(b.total)) + '</b><div class="t-foot">' + X.okSub + '</div></div></div>';

    var seg = [15, 18, 20].map(function (p) { return '<button data-act="tip" data-pct="' + p + '" aria-pressed="' + (S.tip.mode === 'pct' && S.tip.pct === p) + '">' + p + '%</button>'; }).join('') +
      '<button data-act="tip" data-pct="custom" aria-pressed="' + (S.tip.mode === 'custom') + '">' + X.custom + '</button>';
    var custom = S.tip.mode === 'custom' ? '<div style="display:flex;gap:8px;align-items:center;margin-top:10px"><button class="mini" style="min-width:44px;font-size:22px" data-act="tipstep" data-d="-50" aria-label="' + X.tipDec + '">−</button><input class="input amt" id="ctip" inputmode="decimal" value="' + (tip / 100).toFixed(2) + '" aria-label="' + X.tipCustomAria + '"><button class="mini" style="min-width:44px;font-size:22px" data-act="tipstep" data-d="50" aria-label="' + X.tipInc + '">+</button></div>' : '';
    var svcHint = svc ? '<div class="t-foot" style="margin-top:8px">' + (tip === 0 ? X.tipSvc(fmt(svc)) : X.tipSvcMore(fmt(svc))) + '</div>' : '';

    var total = Math.max(1, b.total);
    var bar = '<div class="sbar" role="img" aria-label="' + X.barAria + '">' + b.rows.map(function (r) {
      var p = person(r.id), pc = r.total / total * 100;
      return '<span class="s' + p.slot + '" style="width:' + pc + '%"></span>';
    }).join('') + '</div><div class="sbar-rule" aria-hidden="true"></div><div class="legend">' + b.rows.map(function (r) { var p = person(r.id); return '<span class="s' + p.slot + '"><i></i>' + esc(p.name) + ' ' + Math.round(r.total / total * 100) + '%</span>'; }).join('') + '</div>';

    var cards = b.rows.map(function (r) {
      var p = person(r.id), open = S.expanded[p.id], adj = r.itemAdj.length + r.taxAdj + r.serviceAdj + r.tipAdj;
      return '<div class="pcard s' + p.slot + (open ? ' open' : '') + '"><button class="pc-h" data-act="expand" data-id="' + p.id + '" aria-expanded="' + !!open + '"><div class="pc-top">' + av(p, 'md') + '<div class="pc-name"><b>' + esc(p.name) + '</b><span class="t-foot">' + X.line(fmt(r.items), fmt(r.tax), svc ? fmt(r.service) : '', fmt(r.tip)) + '</span>' +
        (adj ? '<span class="pc-adj">' + X.rounding(adj) + '</span>' : '') + '</div>' + amt('pt' + p.id, r.total, 't-total') + ic('chevd').replace('class="ico"', 'class="ico chev"') + '</div></button>' +
        (open ? '<div class="pc-body">' + r.lines.map(function (l) { return '<div class="ln"><span>' + esc(l.item.name) + (l.of > 1 ? ' <i class="t-cap">1/' + l.of + '</i>' : '') + '</span><span class="num">' + fmt(l.cents) + '</span></div>'; }).join('') + '</div>' : '') + '</div>';
    }).join('');

    // rounding explainer
    var notes = [];
    S.items.forEach(function (it) { if (it.who.length > 1 && it.price % it.who.length) { var sh = shareOf(it), mx = Math.max.apply(null, Object.keys(sh).map(function (k) { return sh[k]; })); var ws = S.people.filter(function (p) { return sh[p.id] === mx; }).map(function (p) { return p.name; }); notes.push(X.roundItem(esc(it.name), fmt(it.price), it.who.length, it.price % it.who.length, ws.map(esc))); } });
    var names = function (key) { return b.rows.filter(function (r) { return r[key]; }).map(function (r) { return esc(person(r.id).name); }); };
    var tx = names('taxAdj'), sv = names('serviceAdj'), tp = names('tipAdj');
    if (tx.length) notes.push(X.roundPool(X.poolTax, tx.length, tx));
    if (sv.length) notes.push(X.roundPool(X.poolSvc, sv.length, sv));
    if (tp.length) notes.push(X.roundPool(X.poolTip, tp.length, tp));
    var round = notes.length ? '<div class="round"><div class="rc-wrap">' + R.svg('thinking', 76, { coin: 1, label: X.roundCoin }) + '</div><div><b class="t-head" style="display:block">' + X.roundTitle + '</b><ul class="t-foot" style="margin:4px 0 0;padding-left:16px">' + notes.map(function (n) { return '<li>' + n + '</li>'; }).join('') + '</ul><div class="t-foot" style="margin-top:6px">' + X.roundRule + '</div></div></div>' : '';

    return '<div class="view">' + nav(X.back, 'assign', 5) + '<div class="head" style="padding-bottom:8px"><h1 class="t-title">' + X.title + '</h1></div>' +
      '<div class="scroll" data-scroll="totals" style="padding-bottom:12px">' + banner +
      '<div class="group-label">' + X.tipLabel(fmt(S.receipt.subtotal)) + '</div><div class="segm" role="group" aria-label="' + X.tipAria + '">' + seg + '</div>' + custom + svcHint +
      '<div class="sum"><div style="display:flex;justify-content:space-between;align-items:flex-end;gap:8px"><div><div class="t-cap">' + X.billTotal + '</div>' + amt('bt', conf, 't-display') + '</div></div>' +
      '<div class="sum3" style="grid-template-columns:repeat(' + (svc ? 4 : 3) + ',1fr)"><div><span class="t-cap">' + X.subtotal + '</span>' + amt('ss', S.receipt.subtotal) + '</div><div><span class="t-cap">' + X.tax + '</span>' + amt('stx', S.receipt.tax) + '</div>' + (svc ? '<div><span class="t-cap">' + X.service + '</span>' + amt('ssv', svc) + '</div>' : '') + '<div><span class="t-cap">' + X.tip + '</span>' + amt('stp', tip) + '</div></div></div>' +
      '<div class="group-label divlabel">' + DIV + X.whoOwes + '</div>' + bar + '<div class="cards">' + cards + '</div>' + round + '</div>' +
      '<div class="footer bar"><button class="btn btn-primary' + (ok ? '' : ' is-disabled') + '" data-act="share">' + ic('share') + X.share + '</button>' +
      (ok ? '' : '<div class="t-foot" style="text-align:center;color:var(--warn)">' + X.blocked + '</div>') +
      '<div style="display:flex;gap:8px"><button class="btn-quiet" style="flex:1" data-act="go" data-to="assign">' + X.editAsg + '</button><button class="btn-quiet" style="flex:1" data-act="go" data-to="review">' + X.editReceipt + '</button></div></div></div>' +
      (S.sheet && S.sheet.type === 'share' ? shareSheet(b) : '') + (S.sheet && S.sheet.type === 'success' ? successView(b) : '');
  };
  function shareSheet(b) {
    var Sh = T.share, t = [['Messages', 1, 'M5 6h14v9H10l-4 3.5V15H5z'], ['Mail', 2, 'M4 7h16v10H4zM4 8l8 6 8-6'], ['Notes', 3, 'M6 4h12v16H6zM9 9h6M9 13h6'], ['Copy', 4, 'M8 8h10v11H8zM6 16V5h10']];
    return '<div class="scrim" data-act="close"></div><div class="sheet share" role="dialog" aria-label="' + esc(Sh.docTitle(T.merchant)) + '"><div class="grab"></div>' +
      '<div style="display:flex;gap:12px;align-items:center;margin-bottom:10px"><span class="doc">' + ic('doc') + '</span><div style="min-width:0;flex:1"><b class="t-head" style="display:block">' + esc(Sh.docTitle(T.merchant)) + '</b><span class="t-foot">' + Sh.docSub(S.people.length) + '</span></div><span class="av-stack sh-people">' + S.people.map(function (p) { return av(p, 'sm'); }).join('') + '</span></div>' +
      '<pre class="sumtxt">' + esc(summaryText(b)) + '</pre>' +
      '<div class="apps">' + t.map(function (a) { return '<button data-act="shared" data-app="' + a[0] + '"><span style="background:var(--sh-app' + a[1] + '-bg);color:var(--sh-app' + a[1] + '-fg)"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="' + a[2] + '"/></svg></span>' + Sh.apps[a[0]] + '</button>'; }).join('') + '</div>' +
      '<div class="t-foot" style="text-align:center;margin:10px 0 2px">' + Sh.native + '</div><button class="btn-quiet" style="width:100%" data-act="close">' + Sh.cancel + '</button></div>';
  }
  function successView(b) {
    var O = T.ok;
    return '<div class="success fadein"><div style="display:flex;flex-direction:column;align-items:center;text-align:center;gap:6px;padding:0 24px">' + R.scenes.success(290) +
      '<h1 class="t-title" style="margin:6px 0 0">' + O.title + '</h1><span class="av-stack sh-people sent" aria-hidden="true">' + S.people.map(function (p) { return av(p, 'md'); }).join('') + '</span><p class="t-sub" style="margin:0 0 18px">' + O.body(S.people.length, fmt(b.total)) + '</p>' +
      '<button class="btn btn-primary" data-act="new-bill">' + O.again + '</button><button class="btn-quiet" data-act="close">' + O.back + '</button></div></div>';
  }

  /* ------------------------------------------------------------ sheets that do not belong to one screen */
  function globalSheet() {
    var s = S.sheet; if (!s) return '';
    var Sh = T.sheet;
    if (s.type === 'how') return '<div class="scrim" data-act="close"></div><div class="sheet"><div class="grab"></div><h3>' + T.how.title + '</h3><ol class="how">' +
      T.how.steps.map(function (st) { return '<li><b>' + st[0] + '</b><span>' + st[1] + '</span></li>'; }).join('') + '</ol><button class="btn btn-primary" data-act="close">' + T.how.ok + '</button></div>';
    if (s.type === 'edit-item') {
      var it = itemById(s.id), isNew = !!s.isNew; if (!it) return '';
      var d = S.draft.item || (S.draft.item = { name: it.name, price: (it.price / 100).toFixed(2) });
      return '<div class="scrim" data-act="close"></div><div class="sheet"><div class="grab"></div><h3>' + (isNew ? Sh.newItem : Sh.editItem) + '</h3>' +
        (it.flag ? '<div class="banner warn" style="margin:10px 0"><span class="b-ico">' + ic('warn') + '</span><div class="t-foot" style="color:var(--ink)">' + Sh.flagNote(fmt(it.price)) + '</div></div>' : '') +
        '<div class="field" style="margin-top:12px"><label for="e-name">' + Sh.desc + '</label><input class="input" id="e-name" data-bind="item.name" value="' + esc(d.name) + '" placeholder="' + esc(Sh.descPh) + '" autocomplete="off"></div>' +
        '<div class="field" style="margin-top:12px"><label for="e-price">' + Sh.price + '</label><input class="input amt" id="e-price" data-bind="item.price" inputmode="decimal" value="' + esc(d.price) + '" placeholder="0.00"></div>' +
        '<div class="t-foot warn-t" id="e-err" style="min-height:20px;margin-top:6px"></div><button class="btn btn-primary" data-act="save-item" data-id="' + it.id + '">' + Sh.save + '</button>' +
        '<div style="display:flex;gap:8px;margin-top:4px"><button class="btn-quiet warn-t" style="flex:1" data-act="delete-item" data-id="' + it.id + '">' + Sh.del + '</button><button class="btn-quiet" style="flex:1" data-act="close">' + Sh.cancel + '</button></div></div>';
    }
    if (s.type === 'edit-field') {
      var lab = { subtotal: T.rev.subtotal, tax: T.rev.tax, service: T.rev.service, total: Sh.receiptTotal }[s.field], dd = S.draft.field || (S.draft.field = { v: (S.receipt[s.field] / 100).toFixed(2) });
      return '<div class="scrim" data-act="close"></div><div class="sheet"><div class="grab"></div><h3>' + lab + '</h3><p class="t-sub" style="margin:4px 0 12px">' + Sh.typeIt + '</p>' +
        '<div class="field"><label for="e-field">' + Sh.amount + '</label><input class="input amt" id="e-field" data-bind="field.v" inputmode="decimal" value="' + esc(dd.v) + '"></div><div class="t-foot warn-t" id="e-err" style="min-height:20px;margin-top:6px"></div>' +
        '<button class="btn btn-primary" data-act="save-field" data-field="' + s.field + '">' + Sh.save + '</button><button class="btn-quiet" style="width:100%" data-act="close">' + Sh.cancel + '</button></div>';
    }
    if (s.type === 'rename') {
      var p = person(s.id), dr = S.draft.rename || (S.draft.rename = { v: p.name });
      return '<div class="scrim" data-act="close"></div><div class="sheet"><div class="grab"></div><h3>' + Sh.rename + '</h3><div class="field" style="margin-top:12px"><label for="e-rn">' + Sh.name + '</label><input class="input" id="e-rn" data-bind="rename.v" value="' + esc(dr.v) + '" maxlength="18"></div><div style="height:12px"></div>' +
        '<button class="btn btn-primary" data-act="save-rename" data-id="' + p.id + '">' + Sh.save + '</button><button class="btn-quiet" style="width:100%" data-act="close">' + Sh.cancel + '</button></div>';
    }
    if (s.type === 'remove') {
      var q = person(s.id), had = S.items.filter(function (i) { return i.who.indexOf(q.id) >= 0; }), orphan = had.filter(function (i) { return i.who.length === 1; });
      return '<div class="scrim" data-act="close"></div><div class="sheet warnish"><div class="grab"></div><h3>' + esc(T.ppl.removeTitle(q.name)) + '</h3>' +
        '<p class="t-sub" style="margin:8px 0 16px;color:var(--ink)">' + esc(T.ppl.removeBody(q.name, had.length, orphan.map(function (i) { return i.name; }), had.length - orphan.length > 0)) + '</p>' +
        '<div style="display:flex;gap:10px"><button class="btn btn-primary" style="flex:2" data-act="close">' + esc(T.ppl.keep(q.name)) + '</button><button class="btn btn-warn" style="flex:1" data-act="confirm-remove" data-id="' + q.id + '">' + T.ppl.remove + '</button></div></div>';
    }
    if (s.type === 'continue-bad') {
      var i0 = issues()[0];
      return '<div class="scrim" data-act="close"></div><div class="sheet warnish"><div class="grab"></div><div style="display:flex;gap:10px;align-items:center">' + R.svg('worried', 64) + '<h3>' + T.rev.badTitle + '</h3></div>' +
        '<p class="t-sub" style="margin:10px 0 16px;color:var(--ink)">' + T.rev.badBody(fmt(Math.abs(i0.diff))) + '</p>' +
        '<div style="display:flex;gap:10px"><button class="btn btn-primary" style="flex:2" data-act="close">' + T.rev.fixIt + '</button><button class="btn btn-secondary" style="flex:1" data-act="continue-anyway">' + T.rev.keepGoing + '</button></div></div>';
    }
    return '';
  }

  /* ------------------------------------------------------------ render */
  var appEl, fxEl, timers = {};
  function render() {
    var scrolls = {}; appEl.querySelectorAll('[data-scroll]').forEach(function (e) { scrolls[e.dataset.scroll] = [e.scrollTop, e.scrollLeft]; });
    var html = V[S.screen]();
    if (S.sheet && S.sheet.type !== 'assign' && S.sheet.type !== 'share' && S.sheet.type !== 'success') html += globalSheet();
    if (S.toast) html += '<div class="toast" role="status">' + esc(S.toast) + '</div>';
    appEl.innerHTML = html;
    appEl.classList.toggle('dark-chrome', S.screen === 'capture' && S.cap !== 'denied');
    document.querySelector('.screen').classList.toggle('dark-chrome', S.screen === 'capture' && S.cap !== 'denied');
    appEl.querySelectorAll('[data-scroll]').forEach(function (e) { var s = scrolls[e.dataset.scroll]; if (s) { e.scrollTop = s[0]; e.scrollLeft = s[1]; } });
    tweenAmts();
    // the unassigned -> assigned moment: a pink rail and check badge on the row that just got its first person
    var asg = {}; S.items.forEach(function (i) { if (i.who.length) asg[i.id] = 1; });
    if (S.screen === 'assign' && LAST.screen === 'assign' && LAST.asg) {
      var k = 0; S.items.forEach(function (i) {
        if (!asg[i.id] || LAST.asg[i.id]) return;
        var row = appEl.querySelector('.irow[data-id="' + i.id + '"]'); if (!row) return;
        row.classList.add('just'); row.style.setProperty('--d', (k++ * 0.09) + 's');
        row.insertAdjacentHTML('beforeend', '<span class="just-badge" aria-hidden="true">' + ic('check') + '</span>');
      });
    }
    LAST.asg = asg;
    LAST.sheetOpen = S.sheet && S.sheet.type;
    LAST.screen = S.screen;
    schedule();
    var tt = document.getElementById('ttl'); if (tt) tt.textContent = TITLES[S.screen] || '';
  }
  var TITLES = T.titles;
  var prevAmt = {};
  function tweenAmts() {
    appEl.querySelectorAll('[data-amt]').forEach(function (el) {
      var k = S.screen + ':' + el.dataset.key, v = +el.dataset.v, p = prevAmt[k]; prevAmt[k] = v;
      if (p === undefined || p === v || reduced()) return;
      var t0 = performance.now(), dur = 380; el.classList.add('pop');
      (function step(t) { var x = Math.min(1, (t - t0) / dur), e = 1 - Math.pow(1 - x, 3); el.textContent = fmt(Math.round(p + (v - p) * e)); if (x < 1) requestAnimationFrame(step); else el.classList.remove('pop'); })(t0);
    });
  }
  function fly(fromEl, toEl, text) {
    if (reduced() || !fromEl || !toEl) return;
    var sr = document.querySelector('.screen').getBoundingClientRect(), a = fromEl.getBoundingClientRect(), b = toEl.getBoundingClientRect(), k = sr.width / 390;
    var el = document.createElement('div'); el.className = 'fly'; el.textContent = text; fxEl.appendChild(el);
    var x0 = (a.left + a.width / 2 - sr.left) / k, y0 = (a.top + a.height / 2 - sr.top) / k, x1 = (b.left + b.width / 2 - sr.left) / k, y1 = (b.top + b.height / 2 - sr.top) / k;
    el.style.left = x0 + 'px'; el.style.top = y0 + 'px';
    el.animate([{ transform: 'translate(-50%,-50%) scale(1)', opacity: 1 }, { transform: 'translate(calc(-50% + ' + (x1 - x0) + 'px),calc(-50% + ' + (y1 - y0) + 'px)) scale(.7)', opacity: .1 }], { duration: 480, easing: 'cubic-bezier(.4,0,.2,1)' }).onfinish = function () { el.remove(); };
  }
  function haptic(kind) {
    var h = document.getElementById('haptic'); if (!h) return; h.textContent = '((•)) ' + T.hapticWord + ': ' + (T.haptic[kind] || kind); h.classList.add('on'); clearTimeout(timers.h); timers.h = setTimeout(function () { h.classList.remove('on'); }, 1400);
  }
  function toast(m) { S.toast = m; render(); clearTimeout(timers.t); timers.t = setTimeout(function () { S.toast = null; render(); }, 2400); }
  function go(to) {
    S.screen = to; S.sheet = null; S.warn = false; S.paint = null; S.toast = null; S.draft = {};
    if (to === 'capture' && S.cap !== 'denied') S.cap = 'live';
    if (to === 'processing') { S.proc.showManual = false; if (!START.failed) S.proc.failed = false; }
    render(); var sc = appEl.querySelector('.scroll'); if (sc) sc.scrollTop = 0;
  }

  /* scheduled behaviour for the processing screen */
  function schedule() {
    clearTimeout(timers.p1); clearTimeout(timers.p2); clearTimeout(timers.p3); clearInterval(timers.pm);
    if (S.screen !== 'processing' || S.proc.failed) return;
    var msgs = T.proc.msgs, i = 0;
    timers.pm = setInterval(function () { var e = document.getElementById('pmsg'); if (!e) return; i = (i + 1) % msgs.length; e.textContent = msgs[i]; }, 1700);
    if (!S.proc.showManual) timers.p2 = setTimeout(function () { if (S.screen === 'processing') { S.proc.showManual = true; render(); } }, 8000);
    if (S.fromFlow) timers.p3 = setTimeout(function () { if (S.screen === 'processing') { S.fromFlow = false; go('review'); } }, 4800);
  }

  /* ------------------------------------------------------------ actions */
  function assignToggle(id, pid, withFly) {
    var it = itemById(id), idx = it.who.indexOf(pid);
    if (idx >= 0) it.who.splice(idx, 1); else it.who.push(pid);
    haptic('selection tick');
    if (S.warn && !unassigned().length) S.warn = false;
    render();
    revealChip(pid);
    if (withFly && idx < 0) { var sh = shareOf(it); fly(appEl.querySelector('[data-prow="' + pid + '"]') || appEl.querySelector('[data-id="' + id + '"]'), appEl.querySelector('[data-chip="' + pid + '"]'), '+' + fmt(sh[pid])); }
  }
  function revealChip(pid) { // keep the changing subtotal on screen
    var c = appEl.querySelector('[data-chip="' + pid + '"]'); if (!c) return;
    var box = c.parentElement, l = c.offsetLeft, r = l + c.offsetWidth;
    if (r > box.scrollLeft + box.clientWidth - 8) box.scrollLeft = r - box.clientWidth + 24;
    else if (l < box.scrollLeft + 8) box.scrollLeft = Math.max(0, l - 16);
  }
  var A = {
    go: function (d) { go(d.to); },
    toast: function (d) { toast(d.msg); },
    'start-scan': function () { S.fromFlow = true; S.cap = 'live'; go('capture'); },
    'start-photo': function () { S.fromFlow = true; S.cap = 'captured'; go('capture'); S.cap = 'captured'; render(); },
    shutter: function () { var f = document.getElementById('flash'); if (f && !reduced()) f.classList.add('go'); setTimeout(function () { S.cap = 'captured'; render(); }, reduced() ? 0 : 160); },
    retake: function () { S.cap = 'live'; render(); },
    'use-photo': function () { S.proc.failed = !!START.failed && START.screen === 'processing'; go('processing'); },
    retry: function () { S.proc.failed = false; S.fromFlow = true; go('processing'); },
    manual: function () { S.items = []; S.receipt = { subtotal: 0, tax: 0, total: 0 }; go('review'); },
    thumb: function () { S.thumb = !S.thumb; render(); },
    'add-item': function () { var id = ++S.nextId; S.items.push({ id: id, name: '', price: 0, flag: null, who: [] }); S.draft = {}; S.sheet = { type: 'edit-item', id: id, isNew: true }; render(); },
    'review-continue': function () { if (!S.items.length) return toast(T.rev.needOne); if (issues().length) { haptic('warning'); S.sheet = { type: 'continue-bad' }; render(); } else go('people'); },
    'continue-anyway': function () { go('people'); },
    sheet: function (d) { S.draft = {}; S.sheet = { type: d.type, id: d.id ? (isNaN(+d.id) ? d.id : +d.id) : null, field: d.field }; render(); },
    close: function () { S.sheet = null; S.draft = {}; render(); },
    'save-item': function (d) {
      var it = itemById(+d.id), dr = S.draft.item || {}, c = parseCents(dr.price), name = (dr.name || '').trim();
      if (!name || c === null) { var e = document.getElementById('e-err'); if (e) e.textContent = !name ? T.sheet.errName : T.sheet.errPrice; return; }
      it.name = name; it.price = c; it.flag = null; S.sheet = null; S.draft = {}; render();
    },
    'delete-item': function (d) { S.items = S.items.filter(function (i) { return i.id !== +d.id; }); S.sheet = null; render(); },
    'save-field': function (d) { var c = parseCents((S.draft.field || {}).v); if (c === null) { var e = document.getElementById('e-err'); if (e) e.textContent = T.sheet.errAmt; return; } S.receipt[d.field] = c; S.sheet = null; S.draft = {}; render(); },
    'add-person': function () {
      var inp = document.getElementById('pname'), v = (inp.value || '').trim();
      if (!v) { S.draft.err = T.ppl.errName; render(); return; }
      if (S.people.some(function (p) { return p.name.toLowerCase() === v.toLowerCase(); })) { S.draft.err = T.ppl.errDup(v); S.draft.person = v; render(); return; }
      var used = S.people.map(function (p) { return p.slot; }), slot = 1; while (used.indexOf(slot) >= 0 && slot <= 8) slot++;
      if (slot > 8) slot = (S.people.length % 8) + 1;
      S.people.push({ id: 'p' + (++S.nextPerson), name: v, slot: slot }); S.draft = {}; haptic('selection tick'); render(); var n = document.getElementById('pname'); if (n) n.focus();
    },
    'remove-person': function (d) {
      var had = S.items.some(function (i) { return i.who.indexOf(d.id) >= 0; });
      if (had) { S.sheet = { type: 'remove', id: d.id }; haptic('warning'); render(); } else { S.people = S.people.filter(function (p) { return p.id !== d.id; }); render(); }
    },
    'confirm-remove': function (d) { S.people = S.people.filter(function (p) { return p.id !== d.id; }); S.items.forEach(function (i) { i.who = i.who.filter(function (w) { return w !== d.id; }); }); S.sheet = null; render(); },
    'save-rename': function (d) { var v = ((S.draft.rename || {}).v || '').trim(); if (v) person(d.id).name = v; S.sheet = null; S.draft = {}; render(); },
    'people-continue': function () { if (!S.people.length) { haptic('warning'); return toast(T.ppl.needOne); } go('assign'); },
    item: function (d) {
      var id = +d.id;
      if (S.paint) { assignToggle(id, S.paint, false); var it = itemById(id); if (it.who.indexOf(S.paint) >= 0) fly(appEl.querySelector('[data-id="' + id + '"]'), appEl.querySelector('[data-chip="' + S.paint + '"]'), '+' + fmt(shareOf(it)[S.paint])); return; }
      S.sheet = { type: 'assign', id: id }; LAST.sheetOpen = null; render();
    },
    toggle: function (d) { assignToggle(+d.id, d.pid, true); },
    everyone: function (d) { var it = itemById(+d.id); it.who = it.who.length === S.people.length ? [] : S.people.map(function (p) { return p.id; }); haptic('selection tick'); if (S.warn && !unassigned().length) S.warn = false; render(); },
    paint: function (d) { S.paint = S.paint === d.id ? null : d.id; S.sheet = null; render(); if (S.paint) revealChip(S.paint); },
    'review-split': function () {
      var left = unassigned();
      if (left.length) { S.warn = true; S.paint = null; haptic('warning'); render(); var b = document.getElementById('rsbtn'); if (b && !reduced()) b.animate([{ transform: 'translateX(0)' }, { transform: 'translateX(-8px)' }, { transform: 'translateX(8px)' }, { transform: 'translateX(-5px)' }, { transform: 'translateX(0)' }], { duration: 320 });
        var u = appEl.querySelector('.irow.un'); if (u) u.scrollIntoView({ block: 'center', behavior: reduced() ? 'auto' : 'smooth' }); }
      else { haptic('success'); go('totals'); }
    },
    tip: function (d) { if (d.pct === 'custom') S.tip = { mode: 'custom', cents: tipCents() }; else S.tip = { mode: 'pct', pct: +d.pct }; render(); },
    tipstep: function (d) { S.tip = { mode: 'custom', cents: Math.max(0, tipCents() + (+d.d)) }; render(); },
    expand: function (d) { S.expanded[d.id] = !S.expanded[d.id]; render(); },
    share: function () { var un = unassigned().length, ok = !un && bill().total === S.receipt.total + tipCents(); if (!ok) { haptic('warning'); return toast(T.tot.blockedToast); } S.sheet = { type: 'share' }; render(); },
    shared: function () { S.sheet = { type: 'success' }; haptic('success'); render(); },
    'split-rest': function () { S.items.forEach(function (i) { if (!i.who.length) i.who = S.people.map(function (p) { return p.id; }); }); S.warn = false; haptic('selection tick'); render(); },
    'new-bill': function () { var d = dataset('scanned'); S.items = d.items; S.people = []; S.receipt = d.receipt; S.tip = d.tip; S.fromFlow = false; go('home'); }
  };

  /* ------------------------------------------------------------ boot */
  function boot() {
    var screenEl = document.querySelector('.screen');
    appEl = document.getElementById('app'); fxEl = document.getElementById('fx');
    screenEl.addEventListener('click', function (e) {
      var t = e.target.closest('[data-act]'); if (!t || !screenEl.contains(t)) return;
      if (t.classList.contains('is-disabled') && !/review-continue|people-continue|share/.test(t.dataset.act)) return;
      var f = A[t.dataset.act]; if (f) f(t.dataset);
    });
    screenEl.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' && e.target.id === 'pname') { A['add-person'](); return; }
      if (e.key === 'Enter' && e.target.id === 'ctip') { e.target.blur(); return; }
      if ((e.key === 'Enter' || e.key === ' ') && e.target.matches('[role="button"][data-act]')) { e.preventDefault(); e.target.click(); }
    });
    screenEl.addEventListener('input', function (e) {
      var t = e.target; if (t.id === 'pname') { S.draft.person = t.value; S.draft.err = ''; var pe = document.getElementById('perr'); if (pe) pe.textContent = ''; return; }
      if (t.dataset.bind) { var k = t.dataset.bind.split('.'); (S.draft[k[0]] = S.draft[k[0]] || {})[k[1]] = t.value; }
    });
    screenEl.addEventListener('change', function (e) { if (e.target.id === 'ctip') { var c = parseCents(e.target.value); if (c !== null) { S.tip = { mode: 'custom', cents: c }; render(); } } });
    render();
    chrome();
  }

  /* ------------------------------------------------------------ page chrome: toolbar, theme, fit */
  function setTheme(t) {
    root.dataset.theme = t;
    try { localStorage.setItem('esp-theme', t); } catch (e) {}
    document.querySelectorAll('[data-theme-btn]').forEach(function (b) { b.setAttribute('aria-pressed', b.dataset.themeBtn === t); });
  }
  function applyData(name) {
    var d = dataset(name); S.data = name; S.items = d.items; S.people = d.people; S.receipt = d.receipt; S.sheet = null; S.warn = false; S.paint = null; S.tip = d.tip;
    document.querySelectorAll('[data-data-btn]').forEach(function (b) { b.setAttribute('aria-pressed', b.dataset.dataBtn === name); });
    render();
  }
  function chrome() {
    var stored = null; try { stored = localStorage.getItem('esp-theme'); } catch (e) {}
    var t = qs.get('theme') || stored || (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    setTheme(t);
    root.dataset.people = qs.get('people') === 'old' ? 'old' : 'new';
    root.dataset.share = qs.get('share') ? (qs.get('share') === 'old' ? 'old' : 'new') : root.dataset.people;
    if (qs.get('reduce') === '1') root.dataset.reduce = '1';
    window.addEventListener('message', function (e) { var m = e.data; if (m && m.esp === 'theme') setTheme(m.v); if (m && m.esp === 'people') { root.dataset.people = m.v === 'old' ? 'old' : 'new'; root.dataset.share = root.dataset.people; } if (m && m.esp === 'reduce') root.dataset.reduce = m.v ? '1' : '0'; });
    var tb = document.getElementById('toolbar');
    if (EMBED) { document.body.classList.add('embed'); if (tb) tb.remove(); return; }
    var q = location.search.replace(/^\?/, '');
    var Tb = T.tb, here = decodeURIComponent((location.pathname.split('/').pop() || 'index.html'));
    tb.innerHTML = '<a href="index.html" id="back-index">' + Tb.all + '</a><span class="ttl" id="ttl"></span>' +
      '<span><span class="tb-label">' + Tb.mode + '</span><span class="seg"><button data-theme-btn="light">' + Tb.light + '</button><button data-theme-btn="dark">' + Tb.dark + '</button></span></span>' +
      '<span><span class="tb-label">' + Tb.people + '</span><span class="seg"><button data-people-btn="new" title="' + esc(Tb.peopleNewTip) + '">' + Tb.peopleNew + '</button><button data-people-btn="old" title="' + esc(Tb.peopleOldTip) + '">' + Tb.peopleOld + '</button></span></span>' +
      '<span><span class="tb-label">' + Tb.demo + '</span><span class="seg"><button data-data-btn="scanned" title="' + esc(Tb.scanTip) + '">' + Tb.scan + '</button><button data-data-btn="midway" title="' + esc(Tb.midTip) + '">' + Tb.mid + '</button><button data-data-btn="complete" title="' + esc(Tb.completeTip) + '">' + Tb.complete + '</button><button data-data-btn="service" title="' + esc(Tb.serviceTip) + '">' + Tb.service + '</button></span></span>' +
      '<label style="display:inline-flex;gap:6px;align-items:center;cursor:pointer"><input type="checkbox" id="rm"> ' + Tb.reduce + '</label><span class="haptic" id="haptic"></span>' +
      '<span><span class="tb-label">' + Tb.lang + '</span><span class="seg"><button aria-pressed="true" disabled>' + T.thisLabel + '</button><a class="langsw" id="lang-sw" href="../' + T.other + '/' + here + '">' + T.otherLabel + '</a></span></span>';
    tb.querySelectorAll('[data-theme-btn]').forEach(function (b) { b.onclick = function () { setTheme(b.dataset.themeBtn); }; b.setAttribute('aria-pressed', b.dataset.themeBtn === root.dataset.theme); });
    tb.querySelectorAll('[data-people-btn]').forEach(function (b) { b.onclick = function () { setPeople(b.dataset.peopleBtn); }; b.setAttribute('aria-pressed', b.dataset.peopleBtn === root.dataset.people); });
    tb.querySelectorAll('[data-data-btn]').forEach(function (b) { b.onclick = function () { applyData(b.dataset.dataBtn); }; b.setAttribute('aria-pressed', b.dataset.dataBtn === S.data); });
    document.getElementById('rm').onchange = function (e) { root.dataset.reduce = e.target.checked ? '1' : '0'; };
    document.getElementById('back-index').addEventListener('click', function (e) { e.currentTarget.href = 'index.html?' + keepQ(); });
    document.getElementById('lang-sw').addEventListener('click', function (e) { e.currentTarget.href = '../' + T.other + '/' + here + '?' + keepQ(); });
    var tt = document.getElementById('ttl'); tt.textContent = TITLES[S.screen] || '';
    fit();
    window.addEventListener('resize', fit);
  }
  function fit() {
    var f = document.getElementById('fit'), tb = document.getElementById('toolbar'); if (!f) return;
    var availH = innerHeight - (tb ? tb.offsetHeight : 0) - 16, availW = innerWidth - 16;
    var s = Math.min(1, availH / 868, availW / 414); f.style.transform = 'scale(' + s + ')'; f.parentElement.style.height = (868 * s) + 'px';
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
})();
