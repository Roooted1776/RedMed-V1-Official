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

    // Phones often refuse autoplay until a video is on screen: start it when visible, rest it when not.
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (entries) {
        entries.forEach(function (x) {
          if (x.isIntersecting) { if (!userPaused && video.paused) play(); }
          else if (!video.paused) video.pause();
        });
      }, { threshold: 0.01, rootMargin: '300px 0px' }).observe(video);
    }

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
