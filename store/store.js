(function () {
  'use strict';
  var cfg = window.REDMED_STORE;
  if (!cfg || !cfg.tiers || !cfg.tiers.length) return; // config.js missing: leave the static page alone
  var tiers = cfg.tiers;
  var selected = 'pair';
  var ok = /^https:\/\/(square\.link\/u\/|checkout\.square\.site\/)/;
  var $ = function (id) { return document.getElementById(id); };
  var fmt = new Intl.NumberFormat('en-US', { style: 'currency', currency: cfg.currency, maximumFractionDigits: 0 });
  var reduce = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;

  function tier(id) { return tiers.filter(function (t) { return t.id === id; })[0]; }
  function live(t) { return ok.test(t.link || ''); }
  function checkoutUrl(t) { return new URL(t.link).toString(); }

  // ---- theme toggle (initial value set in theme.js) ----
  $('theme-toggle').addEventListener('click', function () {
    var next = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
    document.documentElement.dataset.theme = next;
    try { localStorage.setItem('redmed-theme', next); } catch (e) {}
  });

  // ---- pack picker ----
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
      var dot = document.createElement('span'); dot.className = 'dot'; el.appendChild(dot);
      var h = document.createElement('h3'); h.textContent = t.name; el.appendChild(h);
      var p = document.createElement('p'); p.className = 'price'; p.textContent = fmt.format(t.price); el.appendChild(p);
      var per = document.createElement('p'); per.className = 'per'; per.textContent = t.bands > 1 ? fmt.format(Math.round(t.price / t.bands)) + ' per band' : 'One band'; el.appendChild(per);
      var d = document.createElement('p'); d.className = 'blurb'; d.textContent = t.blurb; el.appendChild(d);
      var btn = document.createElement('button');
      btn.type = 'button'; btn.className = 'button'; btn.textContent = 'Buy ' + t.name;
      btn.addEventListener('click', function (e) { e.stopPropagation(); selected = t.id; render(); openReview(); });
      el.appendChild(btn);
      el.addEventListener('click', function () { selected = t.id; render(); });
      box.appendChild(el);
    });
    var t = tier(selected);
    $('sumName').textContent = t.name;
    $('sumPrice').textContent = fmt.format(t.price);
    $('sumNote').textContent = t.bands + (t.bands > 1 ? ' blank bands. ' : ' blank band. ') + t.blurb;
    $('stickyText').textContent = t.name + ' · ' + fmt.format(t.price);
  }

  function move(step) {
    var i = tiers.map(function (t) { return t.id; }).indexOf(selected);
    selected = tiers[(i + step + tiers.length) % tiers.length].id;
    render();
    $('tiers').querySelector('.on').focus();
  }
  $('tiers').addEventListener('keydown', function (e) {
    if (e.key === 'ArrowRight' || e.key === 'ArrowDown') { move(1); e.preventDefault(); }
    if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') { move(-1); e.preventDefault(); }
  });

  // ---- review dialog, then hand off to Square ----
  var dlg = $('review'), ack = $('ack'), go = $('goBtn'), notice = $('notice'), goLabel = $('goLabel');
  function setGo() {
    var t = tier(selected);
    var ready = ack.checked;
    go.setAttribute('aria-disabled', ready ? 'false' : 'true');
    go.href = ready ? (live(t) ? checkoutUrl(t) : orderMailto(t)) : '#buy';
    goLabel.textContent = live(t) ? 'Continue to Square' : 'Order by email';
    notice.hidden = !(ready && !live(t));
    if (!live(t)) notice.textContent = 'Card checkout is not switched on yet. The button opens an email to ' + cfg.supportEmail + ' so you can order.';
  }
  function orderMailto(t) {
    var body = 'Hi RedMed,\n\nI would like to order: ' + t.name + ' (' + t.bands + (t.bands > 1 ? ' bands' : ' band') + ', ' + fmt.format(t.price) + ').\n\nName:\nShipping address:\n';
    return 'mailto:' + cfg.supportEmail + '?subject=' + encodeURIComponent('Band order: ' + t.name) + '&body=' + encodeURIComponent(body);
  }
  function openReview() {
    var t = tier(selected);
    $('reviewTitle').textContent = t.name + ' (' + t.bands + (t.bands > 1 ? ' bands)' : ' band)');
    $('reviewPrice').textContent = fmt.format(t.price);
    ack.checked = false; setGo();
    if (dlg.showModal) dlg.showModal(); else dlg.setAttribute('open', '');
  }
  ack.addEventListener('change', setGo);
  go.addEventListener('click', function (e) {
    if (go.getAttribute('aria-disabled') === 'true') e.preventDefault();
  });
  $('reviewClose').addEventListener('click', function () { dlg.close(); });
  dlg.addEventListener('click', function (e) { if (e.target === dlg) dlg.close(); });
  ['checkoutBtn', 'stickyBtn'].forEach(function (id) { $(id).addEventListener('click', openReview); });
  $('supportLink').href = 'mailto:' + cfg.supportEmail;

  // ---- sticky bar on phones once the picker is out of view ----
  if ('IntersectionObserver' in window) {
    new IntersectionObserver(function (en) {
      $('sticky').hidden = en[0].isIntersecting || en[0].boundingClientRect.top > 0;
    }).observe($('buy'));

    // scroll reveal
    var io = new IntersectionObserver(function (en) {
      en.forEach(function (x) { if (x.isIntersecting) { x.target.classList.add('in'); io.unobserve(x.target); } });
    }, { threshold: 0.12 });
    document.querySelectorAll('.section-heading, .tiers, .checkout, .steps article, .tech-copy dl div, .faq-list, .closing > *')
      .forEach(function (el) { el.classList.add('reveal'); io.observe(el); });
  }

  // ---- background video ----
  var v = $('bgvideo'), mb = $('motionBtn');
  function pause(p) {
    if (p) { v.pause(); } else { var r = v.play(); if (r && r.catch) r.catch(function () {}); }
    mb.setAttribute('aria-pressed', p ? 'true' : 'false');
    $('motionText').textContent = p ? 'Play video' : 'Pause video';
    $('motionIcon').setAttribute('href', p ? '#i-play' : '#i-pause');
  }
  var saveData = navigator.connection && navigator.connection.saveData;
  if (reduce || saveData) { pause(true); }
  else {
    // iOS Low Power Mode and some browsers block autoplay: keep the poster and show a Play button.
    var first = v.play();
    if (first && first.catch) first.catch(function () { pause(true); });
  }
  mb.addEventListener('click', function () { pause(!v.paused); });
  // Hide only when the video itself or its last fallback source fails, not when the first source is skipped.
  v.addEventListener('error', function (e) { if (e.target === v || e.target === v.lastElementChild) v.style.display = 'none'; }, true);

  // gentle parallax on the hero video (desktop pointer only)
  var hero = document.querySelector('.hero');
  if (!reduce && matchMedia('(hover:hover)').matches) {
    hero.addEventListener('mousemove', function (e) {
      var r = hero.getBoundingClientRect();
      var x = (e.clientX - r.left) / r.width - 0.5, y = (e.clientY - r.top) / r.height - 0.5;
      v.style.transform = 'scale(1.05) translate(' + (x * -14) + 'px,' + (y * -10) + 'px)';
    });
    hero.addEventListener('mouseleave', function () { v.style.transform = ''; });
  }

  render();
})();
