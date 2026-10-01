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

  set(0);
})();
