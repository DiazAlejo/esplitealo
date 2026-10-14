/* Esplitéalo bill math — integer cents only (mirrors docs/CALCULATION_RULES.md).
   Leftover cents: largest remainder, ties broken by participant order. */
(function (root) {
  'use strict';

  // Split `cents` equally among ids; the first (cents mod n) ids in order get +1¢.
  function splitEqual(cents, ids) {
    var n = ids.length, out = {};
    if (!n) return out;
    var base = Math.floor(cents / n), rem = cents - base * n;
    ids.forEach(function (id, i) { out[id] = base + (i < rem ? 1 : 0); });
    return out;
  }

  // Allocate `total` cents proportionally to integer `weights` (largest remainder).
  // Returns shares and the indexes that received a leftover cent.
  function allocate(total, weights) {
    var sumW = weights.reduce(function (a, b) { return a + b; }, 0);
    var shares = weights.map(function () { return 0; });
    if (!sumW || !total) return { shares: shares, bumps: [] };
    var rems = [], used = 0;
    weights.forEach(function (w, i) {
      var num = total * w;
      shares[i] = Math.floor(num / sumW);
      rems.push({ i: i, r: num % sumW });
      used += shares[i];
    });
    var left = total - used;
    rems.sort(function (a, b) { return b.r - a.r || a.i - b.i; });
    var bumps = [];
    for (var k = 0; k < left; k++) { shares[rems[k].i] += 1; bumps.push(rems[k].i); }
    return { shares: shares, bumps: bumps.sort(function (a, b) { return a - b; }) };
  }

  // Tip as a percentage of the pre-tax subtotal, rounded half-up to whole cents.
  function tipFromPct(subtotal, pct) {
    return Math.floor((subtotal * pct * 2 + 100) / 200);
  }

  // items: [{id, price, who:[personId...]}], people: [{id}]
  function computeBill(o) {
    var people = o.people, items = o.items;
    var rows = people.map(function (p) {
      return { id: p.id, items: 0, tax: 0, service: 0, tip: 0, total: 0, itemAdj: [], taxAdj: 0, serviceAdj: 0, tipAdj: 0, lines: [] };
    });
    var byId = {};
    rows.forEach(function (r) { byId[r.id] = r; });
    var unassigned = [];
    items.forEach(function (it) {
      var who = people.map(function (p) { return p.id; }).filter(function (id) { return it.who.indexOf(id) >= 0; });
      if (!who.length) { unassigned.push(it); return; }
      var parts = splitEqual(it.price, who);
      var base = Math.floor(it.price / who.length);
      who.forEach(function (id) {
        byId[id].items += parts[id];
        byId[id].lines.push({ item: it, cents: parts[id], of: who.length });
        if (parts[id] > base) byId[id].itemAdj.push({ item: it, cents: parts[id] - base });
      });
    });
    var w = rows.map(function (r) { return r.items; });
    var t = allocate(o.tax, w), g = allocate(o.tip, w), v = allocate(o.service || 0, w);
    rows.forEach(function (r, i) {
      r.tax = t.shares[i]; r.tip = g.shares[i]; r.service = v.shares[i];
      r.serviceAdj = v.bumps.indexOf(i) >= 0 ? 1 : 0;
      r.taxAdj = t.bumps.indexOf(i) >= 0 ? 1 : 0;
      r.tipAdj = g.bumps.indexOf(i) >= 0 ? 1 : 0;
      r.total = r.items + r.tax + r.service + r.tip;
    });
    var sum = function (f) { return rows.reduce(function (a, r) { return a + f(r); }, 0); };
    return {
      rows: rows, unassigned: unassigned,
      items: sum(function (r) { return r.items; }),
      tax: sum(function (r) { return r.tax; }),
      service: sum(function (r) { return r.service; }),
      tip: sum(function (r) { return r.tip; }),
      total: sum(function (r) { return r.total; })
    };
  }

  var api = { splitEqual: splitEqual, allocate: allocate, tipFromPct: tipFromPct, computeBill: computeBill };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.Calc = api;
})(typeof window !== 'undefined' ? window : this);
