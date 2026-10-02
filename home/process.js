// "See it in action": the step list follows the film. Click a step to jump to it.
// No network calls. Works with hero.js, which owns play/pause for every video.
(function () {
  var v = document.getElementById('process-film');
  var steps = [].slice.call(document.querySelectorAll('.process-step'));
  if (!v || !steps.length) return;
  var times = steps.map(function (s) { return [parseFloat(s.dataset.start), parseFloat(s.dataset.end)]; });
  var current = -1;
  var raf = 0;
  var detail = document.getElementById('process-detail');
  var section = document.getElementById('process');
  if (section) section.classList.add('live');

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
      if (detail) {
        var text = steps[i].querySelector('p');
        detail.classList.remove('show');
        // swap the words while invisible, then fade in: opacity only, so nothing on the page moves
        setTimeout(function () { if (current === i) { detail.textContent = text ? text.textContent : ''; detail.classList.add('show'); } }, 140);
      }
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

  // Jumping to a step needs a seekable video (a server that answers byte-range requests).
  // Where the video is not seekable the list simply follows the film.
  function seekable(to) { return v.seekable.length > 0 && v.seekable.end(v.seekable.length - 1) >= to; }
  function mark() {
    var ok = seekable(times[times.length - 1][0]);
    steps.forEach(function (s) { s.classList.toggle('follow-only', !ok); });
  }
  ['progress', 'loadedmetadata', 'canplaythrough'].forEach(function (e) { v.addEventListener(e, mark); });

  steps.forEach(function (s) {
    s.addEventListener('click', function () {
      var to = parseFloat(s.dataset.start) + 0.01;
      if (!seekable(to)) return;
      v.currentTime = to;
      set(v.currentTime);
      if (v.paused) {
        var toggle = document.querySelector('[data-film="process-film"]');
        if (toggle) toggle.click(); else v.play();
      }
    });
  });

  set(0);
})();
