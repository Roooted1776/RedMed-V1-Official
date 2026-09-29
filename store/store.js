(function () {
  'use strict';
  var cfg = window.REDMED_STORE;
  var tiers = cfg.tiers;
  var selected = 'pair';
  var ok = /^https:\/\/(buy|checkout)\.stripe\.com\//;
  var $ = function (id) { return document.getElementById(id); };
  var fmt = new Intl.NumberFormat('en-US', { style: 'currency', currency: cfg.currency, maximumFractionDigits: 0 });

  function tier(id) { return tiers.filter(function (t) { return t.id === id; })[0]; }
  function live(t) { return ok.test(t.link || ''); }

  function href(t) {
    if (!live(t)) return '#buy';
    var u = new URL(t.link);
    u.searchParams.set('client_reference_id', 'store-' + t.id);
    return u.toString();
  }

  function go(t, e) {
    if (live(t)) return; // plain link navigates
    e.preventDefault();
    var n = $('notice');
    n.hidden = false;
    n.textContent = 'Checkout is not switched on yet. Email ' + cfg.supportEmail + ' to order.';
  }

  function render() {
    var box = $('tiers');
    box.textContent = '';
    tiers.forEach(function (t) {
      var on = t.id === selected;
      var el = document.createElement('div');
      el.className = 'tier' + (on ? ' on' : '');
      el.setAttribute('role', 'radio');
      el.setAttribute('aria-checked', on ? 'true' : 'false');
      el.tabIndex = on ? 0 : -1;
      el.dataset.id = t.id;
      if (t.badge) { var b = document.createElement('span'); b.className = 'badge'; b.textContent = t.badge; el.appendChild(b); }
      var h = document.createElement('h3'); h.textContent = t.name; el.appendChild(h);
      var p = document.createElement('p'); p.className = 'price'; p.textContent = fmt.format(t.price); el.appendChild(p);
      var per = document.createElement('p'); per.className = 'per'; per.textContent = t.bands > 1 ? fmt.format(Math.round(t.price / t.bands)) + ' per band' : 'One band'; el.appendChild(per);
      var d = document.createElement('p'); d.className = 'blurb'; d.textContent = t.blurb; el.appendChild(d);
      var a = document.createElement('a');
      a.className = 'btn ' + (on ? 'primary' : 'ghost'); a.textContent = 'Buy ' + t.name;
      a.href = href(t); a.rel = 'noopener';
      a.addEventListener('click', function (e) { go(t, e); });
      el.appendChild(a);
      el.addEventListener('click', function (e) { if (e.target.tagName !== 'A') select(t.id); });
      box.appendChild(el);
    });
    var t = tier(selected);
    $('sumName').textContent = t.name + ' (' + t.bands + (t.bands > 1 ? ' bands)' : ' band)');
    $('sumPrice').textContent = fmt.format(t.price);
    $('stickyText').textContent = t.name + ' · ' + fmt.format(t.price);
    ['checkoutBtn', 'stickyBtn'].forEach(function (id) { $(id).href = href(t); });
    $('notice').hidden = true;
  }

  function select(id) { selected = id; render(); var n = $('tiers').querySelector('.on'); if (n && document.activeElement && document.activeElement.className === 'tier') n.focus(); }

  $('tiers').addEventListener('keydown', function (e) {
    var i = tiers.map(function (t) { return t.id; }).indexOf(selected);
    if (e.key === 'ArrowRight' || e.key === 'ArrowDown') { select(tiers[(i + 1) % tiers.length].id); $('tiers').querySelector('.on').focus(); e.preventDefault(); }
    if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') { select(tiers[(i + tiers.length - 1) % tiers.length].id); $('tiers').querySelector('.on').focus(); e.preventDefault(); }
  });
  ['checkoutBtn', 'stickyBtn'].forEach(function (id) {
    $(id).addEventListener('click', function (e) { go(tier(selected), e); });
  });
  $('supportLink').href = 'mailto:' + cfg.supportEmail;

  // Sticky bar on phones once the pack picker scrolls out of view.
  var sticky = $('sticky');
  if ('IntersectionObserver' in window) {
    new IntersectionObserver(function (en) { sticky.hidden = en[0].isIntersecting || en[0].boundingClientRect.top > 0; }, { threshold: 0 })
      .observe($('buy'));
  }

  // Background video: respect reduced motion, allow pause, fall back to poster if it fails.
  var v = $('bgvideo'), mb = $('motionBtn');
  function pause(p) {
    if (p) { v.pause(); } else { var r = v.play(); if (r && r.catch) r.catch(function () {}); }
    mb.setAttribute('aria-pressed', p ? 'true' : 'false');
    mb.textContent = p ? 'Play background video' : 'Pause background video';
  }
  if (window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches) pause(true);
  mb.addEventListener('click', function () { pause(!v.paused); });
  v.addEventListener('error', function () { v.style.display = 'none'; document.querySelector('.bg').classList.add('poster'); }, true);

  render();
})();
