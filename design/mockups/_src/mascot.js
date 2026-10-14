/* Original raccoon mascot ("Chavito", formerly the working name "Rocco"), drawn as inline SVG. Flat style, four expressions.
   Head is drawn in a 200x200 box; scenes compose it with paws, tail, receipts, confetti. */
(function (root) {
  'use strict';
  // every colour is a CSS variable from tokens.css (section 6), so a palette change never touches this file
  var FUR = 'var(--m-fur)', FURD = 'var(--m-furd)', MASK = 'var(--m-mask)', CREAM = 'var(--m-cream)', PINK = 'var(--m-cheek)', GOLD = 'var(--m-coin)', NOSE = 'var(--m-nose)';
  // The ÷ motif from the logo (two dots and a bar), pink; decorative. Shared by the scenes and the app.
  var DIVG = '<circle cx="12" cy="4.6" r="2.5"/><rect x="3" y="10.4" width="18" height="3.2" rx="1.6"/><circle cx="12" cy="19.4" r="2.5"/>';
  function sticker(x, y, rot, k) { return '<g transform="translate(' + x + ' ' + y + ') rotate(' + rot + ') scale(' + k + ')" fill="var(--pink)">' + DIVG + '</g>'; }
  var uid = 0;

  function eyeAt(cx, look) {
    return '<circle cx="' + cx + '" cy="108" r="10.5" fill="var(--m-white)"/>' +
      '<g class="pupil" style="transform:translate(' + look[0] + 'px,' + look[1] + 'px)">' +
      '<circle cx="' + cx + '" cy="108" r="5.6" fill="' + MASK + '"/><circle cx="' + (cx + 1.8) + '" cy="105.6" r="1.9" fill="var(--m-white)"/></g>';
  }

  // Returns the head as SVG group markup (200x200 coordinate space).
  function head(expr, o) {
    o = o || {};
    var look = o.look || (expr === 'thinking' ? [3, -4] : expr === 'worried' ? [-2, 2] : [0, 0]);
    var eyes, brows = '', mouth, extra = '', cheeks = '';
    if (expr === 'happy') {
      eyes = '<g class="eyes-shut" fill="none" stroke="' + CREAM + '" stroke-width="4.6" stroke-linecap="round">' +
        '<path d="M61 113 Q72 98 83 113"/><path d="M117 113 Q128 98 139 113"/></g>';
      mouth = '<path d="M86 147 Q100 172 114 147 Z" fill="' + MASK + '"/><path d="M93 160 Q100 152 107 160 Q100 168 93 160Z" fill="' + PINK + '"/>';
      cheeks = '<ellipse cx="55" cy="139" rx="15" ry="10" fill="' + PINK + '" opacity=".85"/><ellipse cx="145" cy="139" rx="15" ry="10" fill="' + PINK + '" opacity=".85"/>';
    } else {
      eyes = '<g class="eyes">' + eyeAt(72, look) + eyeAt(128, look) + '</g>';
      if (expr === 'worried') {
        brows = '<path d="M59 92 L85 81" stroke="' + MASK + '" stroke-width="4.5" stroke-linecap="round"/><path d="M115 81 L141 92" stroke="' + MASK + '" stroke-width="4.5" stroke-linecap="round"/>';
        mouth = '<path d="M87 157 Q100 145 113 157" fill="none" stroke="' + MASK + '" stroke-width="4" stroke-linecap="round"/>';
        extra = '<path d="M164 62 C171 73 173 80 164 85 C155 80 157 73 164 62Z" fill="var(--m-tear)"/><ellipse cx="162" cy="78" rx="2" ry="3" fill="var(--m-white)" opacity=".7"/>';
      } else if (expr === 'thinking') {
        brows = '<path d="M62 87 L83 87" stroke="' + MASK + '" stroke-width="4.5" stroke-linecap="round"/><path d="M117 82 Q130 74 143 81" fill="none" stroke="' + MASK + '" stroke-width="4.5" stroke-linecap="round"/>';
        mouth = '<path d="M90 153 Q103 148 113 154" fill="none" stroke="' + MASK + '" stroke-width="4" stroke-linecap="round"/>';
        extra = '<circle cx="162" cy="46" r="4" fill="' + CREAM + '" stroke="' + FURD + '" stroke-width="1.5"/><circle cx="173" cy="32" r="6" fill="' + CREAM + '" stroke="' + FURD + '" stroke-width="1.5"/>';
      } else {
        mouth = '<path d="M88 150 Q100 160 112 150" fill="none" stroke="' + MASK + '" stroke-width="4" stroke-linecap="round"/>';
        cheeks = '<ellipse cx="56" cy="140" rx="14" ry="9" fill="' + PINK + '" opacity=".8"/><ellipse cx="144" cy="140" rx="14" ry="9" fill="' + PINK + '" opacity=".8"/>';
      }
    }
    return '' +
      // ears
      '<circle cx="52" cy="62" r="23" fill="' + FUR + '"/><circle cx="54" cy="65" r="12" fill="' + FURD + '"/>' +
      '<circle cx="148" cy="62" r="23" fill="' + FUR + '"/><circle cx="146" cy="65" r="12" fill="' + FURD + '"/>' +
      // cheek tufts + head
      '<path d="M34 112 L12 130 L38 142Z" fill="' + FUR + '"/><path d="M166 112 L188 130 L162 142Z" fill="' + FUR + '"/>' +
      '<path d="M28 116 C28 72 62 48 100 48 C138 48 172 72 172 116 C172 152 142 174 100 174 C58 174 28 152 28 116Z" fill="' + FUR + '"/>' +
      // forehead stripe
      '<path d="M91 50 L109 50 L106 84 L94 84Z" fill="' + FURD + '"/>' +
      // brow patches, muzzle, mask
      '<ellipse cx="72" cy="87" rx="15" ry="8" fill="' + CREAM + '"/><ellipse cx="128" cy="87" rx="15" ry="8" fill="' + CREAM + '"/>' +
      '<ellipse cx="100" cy="143" rx="35" ry="27" fill="' + CREAM + '"/>' +
      '<path d="M36 106 C48 88 80 86 100 99 C120 86 152 88 164 106 C162 130 134 136 117 124 C108 119 92 119 83 124 C66 136 38 130 36 106Z" fill="' + MASK + '"/>' +
      eyes + brows + cheeks +
      // nose + philtrum + mouth
      '<path d="M88 127 C88 120 112 120 112 127 C112 134 105 139 100 140 C95 139 88 134 88 127Z" fill="' + NOSE + '" stroke="' + MASK + '" stroke-width="2.2" stroke-linejoin="round"/><ellipse cx="94" cy="125.5" rx="3.6" ry="1.9" fill="var(--m-white)" opacity=".55"/>' +
      '<path d="M100 140 L100 148" stroke="' + MASK + '" stroke-width="3.2" stroke-linecap="round"/>' +
      mouth + extra +
      (o.coin ? '<g class="coin"><ellipse cx="146" cy="176" rx="17" ry="11" fill="' + FUR + '"/><circle cx="159" cy="160" r="25" fill="' + GOLD + '" stroke="var(--m-coin-edge)" stroke-width="3.5"/><text x="159" y="167" text-anchor="middle" font-family="-apple-system,system-ui,sans-serif" font-weight="700" font-size="21" fill="var(--m-coin-ink)">1¢</text></g>' : '');
  }

  function svg(expr, size, o) {
    o = o || {};
    var M = (root.ESP_T && root.ESP_T.mascot) || { expr: {} };
    var label = o.label || M.expr[expr] || ('Raccoon mascot, ' + expr);
    var h = o.coin ? 200 : 190;
    return '<svg class="rc rc-' + expr + '" viewBox="0 6 200 ' + (h) + '" width="' + size + '" height="' + Math.round(size * h / 200) + '" role="img" aria-label="' + label + '">' + head(expr, o) + '</svg>';
  }

  function ML_() { return (root.ESP_T && root.ESP_T.mascot) || {}; }
  var ML = new Proxy({}, { get: function (_, k) { return ML_()[k] || ''; } });

  function paw(x, y, rot) {
    return '<g transform="translate(' + x + ' ' + y + ') rotate(' + (rot || 0) + ')"><ellipse rx="19" ry="13" fill="' + FUR + '"/>' +
      '<path d="M-7 -4 v6 M0 -5 v7 M7 -4 v6" stroke="' + FURD + '" stroke-width="2.6" stroke-linecap="round"/></g>';
  }

  function tail(x, y, rot, id) {
    // striped tail: rounded bar clipped, with dark rings
    return '<g transform="translate(' + x + ' ' + y + ') rotate(' + rot + ')"><clipPath id="' + id + '"><rect x="-70" y="-24" width="140" height="48" rx="24"/></clipPath>' +
      '<g clip-path="url(#' + id + ')"><rect x="-70" y="-24" width="140" height="48" fill="' + FUR + '"/>' +
      [-48, -18, 12, 42].map(function (px) { return '<rect x="' + px + '" y="-24" width="14" height="48" fill="' + FURD + '"/>'; }).join('') +
      '<rect x="46" y="-24" width="24" height="48" fill="' + MASK + '"/></g></g>';
  }

  var lines = function (x, y, w, n, gap, col) {
    var s = '';
    for (var i = 0; i < n; i++) {
      var ww = i % 3 === 2 ? w * 0.6 : w;
      s += '<rect x="' + x + '" y="' + (y + i * gap) + '" width="' + ww + '" height="4" rx="2" fill="' + col + '"/>';
    }
    return s;
  };

  /* ---------- scenes ---------- */
  // Home hero: raccoon peeks over a long receipt it is holding; tail curls out the side.
  function sceneHome(w) {
    var id = 'tl' + (++uid);
    return '<svg class="scene" viewBox="0 0 320 232" width="' + w + '" height="' + Math.round(w * 232 / 320) + '" role="img" aria-label="' + ML.home + '">' +
      '<circle cx="160" cy="120" r="104" fill="var(--disc-hero)"/>' +
      sticker(20, 28, -12, 2.3) +
      '<g class="tail-wag">' + tail(262, 150, -28, id) + '</g>' +
      '<g transform="translate(60 6)">' + head('happy', {}) + '</g>' +
      '<g transform="translate(94 150)"><path d="M0 0 H132 V92 L121 84 L110 92 L99 84 L88 92 L77 84 L66 92 L55 84 L44 92 L33 84 L22 92 L11 84 L0 92Z" fill="var(--m-receipt)" stroke="var(--m-receipt-edge)" stroke-width="1.5"/>' +
      '<rect x="14" y="16" width="52" height="5" rx="2.5" fill="var(--m-mask)" opacity=".75"/><rect x="92" y="16" width="26" height="5" rx="2.5" fill="var(--m-mask)" opacity=".75"/>' +
      '<rect x="14" y="30" width="64" height="4" rx="2" fill="var(--m-mask)" opacity=".28"/><rect x="92" y="30" width="26" height="4" rx="2" fill="var(--m-mask)" opacity=".28"/>' +
      '<rect x="14" y="43" width="44" height="4" rx="2" fill="var(--m-mask)" opacity=".28"/><rect x="92" y="43" width="26" height="4" rx="2" fill="var(--m-mask)" opacity=".28"/>' +
      '<rect x="14" y="62" width="104" height="14" rx="4" fill="var(--m-receipt-bar)"/></g>' +
      paw(106, 156, -8) + paw(214, 156, 8) +
      '</svg>';
  }

  // Processing: raccoon reads a receipt through a magnifier that slides along the lines.
  function sceneProcessing(w) {
    var id = 'pr' + (++uid);
    return '<svg class="scene" viewBox="0 0 280 240" width="' + w + '" height="' + Math.round(w * 240 / 280) + '" role="img" aria-label="' + ML.processing + '">' +
      '<circle cx="140" cy="122" r="108" fill="var(--disc-hero)"/>' +
      '<g transform="translate(40 0) scale(1)"><g class="look-around">' + head('thinking', {}) + '</g></g>' +
      '<g transform="translate(70 148)"><path d="M0 0 H140 V84 L128 76 L116 84 L104 76 L92 84 L80 76 L68 84 L56 76 L44 84 L32 76 L20 84 L10 76 L0 84Z" fill="var(--m-receipt)" stroke="var(--m-receipt-edge)" stroke-width="1.5"/>' +
      lines(14, 14, 78, 5, 12, 'color-mix(in srgb,var(--m-mask) 28%,transparent)') +
      '<g fill="color-mix(in srgb,var(--m-mask) 40%,transparent)"><rect x="104" y="14" width="22" height="4" rx="2"/><rect x="104" y="26" width="22" height="4" rx="2"/><rect x="104" y="38" width="22" height="4" rx="2"/><rect x="104" y="50" width="22" height="4" rx="2"/></g>' +
      '<rect class="scanline" x="4" y="10" width="132" height="10" rx="3" fill="var(--pink)" opacity=".38"/></g>' +
      '<g class="glass"><circle cx="0" cy="0" r="25" fill="var(--m-glass)" stroke="' + FURD + '" stroke-width="6"/><path d="M18 18 L40 40" stroke="' + FURD + '" stroke-width="8" stroke-linecap="round"/>' +
      '<path d="M-14 -8 A16 16 0 0 1 -4 -16" fill="none" stroke="var(--m-white)" stroke-width="3" stroke-linecap="round"/></g>' +
      paw(88, 168, 12) +
      '</svg>';
  }

  // Failed scan: worried raccoon, receipt with a question mark.
  function sceneFailed(w) {
    return '<svg class="scene" viewBox="0 0 280 240" width="' + w + '" height="' + Math.round(w * 240 / 280) + '" role="img" aria-label="' + ML.failed + '">' +
      '<circle cx="140" cy="122" r="108" fill="var(--disc-hero)"/>' +
      '<g transform="translate(40 0)">' + head('worried', {}) + '</g>' +
      '<g transform="translate(78 150) rotate(-4 60 40)"><path d="M0 0 H124 V80 L113 72 L102 80 L91 72 L80 80 L69 72 L58 80 L47 72 L36 80 L25 72 L14 80 L0 72Z" fill="var(--m-receipt)" stroke="var(--m-receipt-edge)" stroke-width="1.5"/>' +
      lines(14, 14, 60, 3, 12, 'color-mix(in srgb,var(--m-mask) 18%,transparent)') +
      '<text x="96" y="52" font-family="-apple-system,system-ui,sans-serif" font-weight="700" font-size="34" fill="var(--m-warn)" text-anchor="middle">?</text></g>' +
      paw(92, 160, 10) + paw(202, 160, -10) +
      '</svg>';
  }

  // Empty state: raccoon waiting at a table with empty seats.
  function sceneEmpty(w) {
    return '<svg class="scene" viewBox="0 0 300 200" width="' + w + '" height="' + Math.round(w * 200 / 300) + '" role="img" aria-label="' + ML.empty + '">' +
      '<ellipse cx="150" cy="168" rx="124" ry="22" fill="var(--well)"/>' +
      '<circle cx="150" cy="72" r="78" fill="var(--disc-hero)"/>' +
      sticker(232, 14, 12, 1.5) +
      '<g transform="translate(75 0) scale(.75)"><g class="look-around">' + head('neutral', { look: [-4, 1] }) + '</g></g>' +
      [0, 1, 2, 3].map(function (i) {
        var x = 60 + i * 60;
        return '<g><circle cx="' + x + '" cy="168" r="19" fill="none" stroke="var(--ink2)" stroke-width="2.5" stroke-dasharray="4 5" opacity=".7"/>' +
          '<path d="M' + (x - 6) + ' 168 H' + (x + 6) + ' M' + x + ' 162 V174" stroke="var(--ink2)" stroke-width="2.5" stroke-linecap="round" opacity=".7"/></g>';
      }).join('') +
      '</svg>';
  }

  // Success: happy raccoon with paws up and a little confetti (skippable, respects Reduce Motion).
  function sceneSuccess(w) {
    var conf = [[40, 40, 'var(--cf1)', 8], [248, 52, 'var(--cf2)', 7], [70, 96, 'var(--cf3)', 9], [226, 104, 'var(--cf4)', 8], [24, 150, 'var(--cf5)', 7], [262, 158, 'var(--cf6)', 8], [150, 14, 'var(--cf7)', 7], [108, 36, 'var(--cf8)', 6], [196, 30, 'var(--cf9)', 6]];
    return '<svg class="scene" viewBox="0 0 290 250" width="' + w + '" height="' + Math.round(w * 250 / 290) + '" role="img" aria-label="' + ML.success + '">' +
      '<circle cx="145" cy="132" r="104" fill="var(--sh-ok-disc)"/>' +
      conf.map(function (c, i) {
        return '<rect class="conf" style="animation-delay:' + (i * 0.12) + 's" x="' + c[0] + '" y="' + c[1] + '" width="' + c[3] + '" height="' + (c[3] * 1.6) + '" rx="2" fill="' + c[2] + '" transform="rotate(' + (i * 37 % 90 - 30) + ' ' + c[0] + ' ' + c[1] + ')"/>';
      }).join('') +
      sticker(30, 40, -14, 1.9) +
      '<g transform="translate(45 20)">' + head('happy', {}) + '</g>' +
      paw(62, 128, -50) + paw(228, 128, 50) +
      '<g transform="translate(206 196)"><circle r="26" fill="var(--primary)" stroke="var(--surface)" stroke-width="4"/><path d="M-11 0 L-3 9 L12 -9" fill="none" stroke="var(--on-primary)" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round"/></g>' +
      '</svg>';
  }

  // Favicon-sized mark used for the wordmark.
  function mark(size) {
    return '<svg viewBox="0 0 200 200" width="' + size + '" height="' + size + '" aria-hidden="true">' + head('neutral', {}) + '</svg>';
  }

  root.Raccoon = { svg: svg, head: head, mark: mark, sticker: sticker, DIVG: DIVG, scenes: { home: sceneHome, processing: sceneProcessing, failed: sceneFailed, empty: sceneEmpty, success: sceneSuccess } };
})(typeof window !== 'undefined' ? window : this);
