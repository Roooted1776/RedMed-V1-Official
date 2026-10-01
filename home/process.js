// "See it in action": the step list follows the film. Click a step to jump to it.
// No network calls. Works with hero.js, which owns play/pause for every video.
(function () {
  var v = document.getElementById('process-film');
  var steps = [].slice.call(document.querySelectorAll('.process-step'));
  if (!v || !steps.length) return;
  var times = steps.map(function (s) { return [parseFloat(s.dataset.start), parseFloat(s.dataset.end)]; });
  var current = -1;
  var raf = 0;

  function set(t) {
    var i = 0;
    for (var k = 0; k < times.length; k++) if (t >= times[k][0]) i = k;
    if (i !== current) {
      steps.forEach(function (s, j) {
        s.classList.toggle('on', j === i);
        if (j === i) s.setAttribute('aria-current', 'step'); else s.removeAttribute('aria-current');
        s.style.removeProperty('--p');
      });
      current = i;
    }
    var a = times[i];
    var p = Math.max(0, Math.min(1, (t - a[0]) / (a[1] - a[0])));
    steps[i].style.setProperty('--p', p.toFixed(3));
  }

  function tick() {
    set(v.currentTime);
    raf = (!v.paused && !v.ended) ? requestAnimationFrame(tick) : 0;
  }

  v.addEventListener('playing', function () { if (!raf) raf = requestAnimationFrame(tick); });
  ['timeupdate', 'seeked', 'loadedmetadata'].forEach(function (e) {
    v.addEventListener(e, function () { set(v.currentTime); });
  });

  steps.forEach(function (s) {
    s.addEventListener('click', function () {
      v.currentTime = parseFloat(s.dataset.start) + 0.01;
      set(v.currentTime);
      if (v.paused) {
        var toggle = document.querySelector('[data-film="process-film"]');
        if (toggle) toggle.click(); else v.play();
      }
    });
  });

  // The portal's file server does not answer byte-range requests, so a streamed video cannot seek.
  // The film is small: load it whole and play it from memory, which makes every step clickable.
  if (window.fetch && window.URL && URL.createObjectURL) {
    var type = v.canPlayType('video/webm; codecs="vp9"') ? 'video/webm' : 'video/mp4';
    var source = v.querySelector('source[type="' + type + '"]');
    if (source) {
      fetch(source.getAttribute('src')).then(function (r) {
        if (!r.ok) throw new Error('video ' + r.status);
        return r.blob();
      }).then(function (blob) {
        var wasPaused = v.paused;
        v.removeAttribute('src');
        [].slice.call(v.querySelectorAll('source')).forEach(function (n) { v.removeChild(n); });
        v.src = URL.createObjectURL(new Blob([blob], { type: type }));
        v.load();
        if (!wasPaused) { var p = v.play(); if (p && p.catch) p.catch(function () {}); }
      }).catch(function () { /* keep the streamed source; steps still follow the film */ });
    }
  }

  set(0);
})();
