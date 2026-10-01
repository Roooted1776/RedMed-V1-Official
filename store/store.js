(function () {
  'use strict';
  var cfg = window.REDMED_STORE;
  if (!cfg || !cfg.tiers || !cfg.tiers.length) return; // config.js missing: leave the static page alone
  var tiers = cfg.tiers;
  var selected = 'pair';
  var qty = 1, MAX_QTY = 10; // how many of the chosen pack (used for the email order; Square's own page has its own selector)
  var wanted = /[?&]pack=([a-z0-9_-]+)/i.exec(location.search); // from the home page's Buy now buttons
  var ok = /^https:\/\/(square\.link\/u\/|checkout\.square\.site\/)/;
  var $ = function (id) { return document.getElementById(id); };
  var fmt = new Intl.NumberFormat('en-US', { style: 'currency', currency: cfg.currency, maximumFractionDigits: 0 });
  var fmtBand = new Intl.NumberFormat('en-US', { style: 'currency', currency: cfg.currency, minimumFractionDigits: 0, maximumFractionDigits: 2 });
  function perBand(t) { var v = t.price / t.bands; return (v % 1 ? new Intl.NumberFormat('en-US', { style: 'currency', currency: cfg.currency, minimumFractionDigits: 2, maximumFractionDigits: 2 }) : fmtBand).format(v); }
  var reduce = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;

  function tier(id) { return tiers.filter(function (t) { return t.id === id; })[0]; }
  function live(t) { return ok.test(t.link || ''); }
  function checkoutUrl(t) { return new URL(t.link).toString(); }

  // ---- theme toggle (state, saving and meta color live in theme.js) ----
  $('theme-toggle').addEventListener('click', function () {
    document.documentElement.dataset.theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
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
      var per = document.createElement('p'); per.className = 'per'; per.textContent = t.bands > 1 ? perBand(t) + ' per band' : 'One band'; el.appendChild(per);
      var d = document.createElement('p'); d.className = 'blurb'; d.textContent = t.blurb; el.appendChild(d);
      var btn = document.createElement('button');
      btn.type = 'button'; btn.className = 'button'; btn.textContent = 'Buy now'; btn.setAttribute('aria-label', 'Buy now: ' + t.name);
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
    var bandsTotal = t.bands * qty;
    var body = 'Hi RedMed,\n\nI would like to order: ' + qty + ' x ' + t.name + ' (' + bandsTotal + (bandsTotal > 1 ? ' bands' : ' band') + ' in total, ' + fmt.format(t.price * qty) + ').\n\nName:\nShipping address:\n';
    return 'mailto:' + cfg.supportEmail + '?subject=' + encodeURIComponent('Band order: ' + qty + ' x ' + t.name) + '&body=' + encodeURIComponent(body);
  }
  // Quantity step. Hidden when a live Square link exists: Square's checkout page has its own quantity selector.
  function updateReview() {
    var t = tier(selected), bandsTotal = t.bands * qty;
    $('reviewTitle').textContent = qty > 1 ? qty + ' \u00d7 ' + t.name + ' (' + bandsTotal + ' bands)' : t.name + ' (' + t.bands + (t.bands > 1 ? ' bands)' : ' band)');
    $('reviewPrice').textContent = fmt.format(t.price * qty);
    $('qtyVal').textContent = qty;
    $('qtyMinus').disabled = qty <= 1;
    $('qtyPlus').disabled = qty >= MAX_QTY;
    $('qtyRow').hidden = live(t);
    $('payLine').textContent = live(t)
      ? "Step 3: pay on Square's secure page with a debit or credit card, or Apple Pay and Google Pay on phones that support them. You can change the quantity there."
      : 'Step 3: card checkout is not switched on yet, so your order opens as an email to us.';
    setGo();
  }
  function changeQty(step) {
    qty = Math.min(MAX_QTY, Math.max(1, qty + step));
    updateReview();
  }
  $('qtyMinus').addEventListener('click', function () { changeQty(-1); });
  $('qtyPlus').addEventListener('click', function () { changeQty(1); });
  function openReview() {
    qty = 1;
    ack.checked = false; updateReview();
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

  if (wanted && tier(wanted[1])) selected = wanted[1];
  render();
})();

// Every <video> on the page: muted autoplay, pause/play, click-to-toggle, pointer shift.
// No network calls. Reduced motion keeps the poster until Play is pressed.
(function () {
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var fine = window.matchMedia('(hover: hover) and (pointer: fine)').matches;
  var videos = document.querySelectorAll('video');
  if (!videos.length) return;

  function paint(btn, paused) {
    if (!btn) return;
    btn.setAttribute('aria-pressed', paused ? 'true' : 'false');
    var label = btn.querySelector('[data-film-label]') || btn.querySelector('span');
    if (label) label.textContent = paused ? 'Play video' : 'Pause video';
    var icon = btn.querySelector('use');
    if (icon) icon.setAttribute('href', paused ? '#i-play' : '#i-pause');
  }

  function ensureButton(video) {
    if (!video.id) return null;
    var btn = document.querySelector('[data-film="' + video.id + '"]');
    if (btn || video.hasAttribute('controls')) return btn;
    var host = video.closest('figure, .reel-stage, .tech-media, .how-video') || video.parentElement;
    if (!host) return null;
    btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'hero-motion film-toggle';
    btn.setAttribute('data-film', video.id);
    var span = document.createElement('span');
    span.setAttribute('data-film-label', '');
    span.textContent = 'Pause video';
    btn.appendChild(span);
    host.appendChild(btn);
    return btn;
  }

  videos.forEach(function (video, index) {
    if (!video.id) video.id = 'film-' + index;
    video.muted = true;
    video.loop = true;
    video.playsInline = true;
    video.setAttribute('playsinline', '');
    video.autoplay = true;
    if (!video.getAttribute('preload') || video.getAttribute('preload') === 'none') video.preload = 'auto';

    var userPaused = !!reduce;
    var btn = ensureButton(video);

    // Phones may block autoplay (Low Power Mode, data saver). Try again on the first touch or scroll.
    var retrying = false;
    function retryOnGesture() {
      if (retrying) return;
      retrying = true;
      var evs = ['touchstart', 'pointerdown', 'scroll', 'keydown'];
      function go() {
        if (userPaused) return;
        evs.forEach(function (t) { window.removeEventListener(t, go, true); });
        retrying = false;
        play();
      }
      evs.forEach(function (t) { window.addEventListener(t, go, { capture: true, passive: true }); });
    }

    function play() {
      var pending = video.play();
      if (pending && typeof pending.catch === 'function') {
        pending.catch(function () {
          paint(btn, true);
          retryOnGesture();
        });
      }
      paint(btn, false);
    }

    function setPaused(paused) {
      userPaused = paused;
      if (paused) {
        video.pause();
        paint(btn, true);
      } else {
        play();
      }
    }

    if (btn) {
      btn.addEventListener('click', function (e) {
        e.stopPropagation();
        setPaused(!video.paused);
      });
    }

    var clickFrame = video.closest('figure, .reel-stage, .how-video, .tech-frame');
    if (clickFrame && !video.hasAttribute('controls')) {
      clickFrame.addEventListener('click', function (e) {
        if (e.target.closest('.steps, a, button, summary, input, select, textarea, label')) return;
        setPaused(!video.paused);
      });
    }

    var pointerFrame = video.closest('.page-bg') ? document.querySelector('.hero') : clickFrame;
    if (!reduce && fine && pointerFrame) {
      pointerFrame.addEventListener('mousemove', function (e) {
        var box = pointerFrame.getBoundingClientRect();
        if (!box.width || !box.height) return;
        var x = (e.clientX - box.left) / box.width - 0.5;
        var y = (e.clientY - box.top) / box.height - 0.5;
        video.style.transform = 'scale(1.05) translate(' + (x * -14).toFixed(1) + 'px,' + (y * -8).toFixed(1) + 'px)';
      });
      pointerFrame.addEventListener('mouseleave', function () {
        video.style.transform = '';
      });
    }

    video.addEventListener('playing', function () { paint(btn, false); });

    if (userPaused) {
      video.pause();
      paint(btn, true);
    } else {
      play();
    }

    document.addEventListener('visibilitychange', function () {
      if (document.hidden) video.pause();
      else if (!userPaused) play();
    });

    video.addEventListener('error', function (e) {
      if (e.target !== video) return;
      video.hidden = true;
      if (btn) btn.hidden = true;
    }, true);
  });
})();
