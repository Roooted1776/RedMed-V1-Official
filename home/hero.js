// Hero film: assets/herovideo.MP4. Muted loop. No network calls.
(function () {
  var video = document.getElementById('hero-video');
  var button = document.getElementById('hero-motion');
  var label = document.getElementById('hero-motion-label');
  if (!video || !button || !label) return;

  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var saveData = navigator.connection && navigator.connection.saveData;
  var userPaused = !!(reduce || saveData);
  var figure = video.closest('.hero-product');

  function paint(paused) {
    button.setAttribute('aria-pressed', paused ? 'true' : 'false');
    label.textContent = paused ? 'Play video' : 'Pause video';
  }

  function play() {
    video.preload = 'auto';
    var pending = video.play();
    if (pending && typeof pending.catch === 'function') {
      pending.catch(function () {
        userPaused = true;
        paint(true);
      });
    }
    paint(false);
  }

  function setPaused(paused) {
    userPaused = paused;
    if (paused) {
      video.pause();
      paint(true);
    } else {
      play();
    }
  }

  if (userPaused) {
    video.pause();
    paint(true);
  } else {
    play();
  }

  button.addEventListener('click', function () {
    setPaused(!userPaused);
  });

  document.addEventListener('visibilitychange', function () {
    if (document.hidden) video.pause();
    else if (!userPaused) play();
  });

  video.addEventListener('error', function () {
    video.hidden = true;
    button.hidden = true;
  }, true);

  if (!reduce && window.matchMedia('(hover: hover) and (pointer: fine)').matches && figure) {
    figure.addEventListener('mousemove', function (e) {
      var box = figure.getBoundingClientRect();
      if (!box.width || !box.height) return;
      var x = (e.clientX - box.left) / box.width - 0.5;
      var y = (e.clientY - box.top) / box.height - 0.5;
      video.style.transform = 'scale(1.06) translate(' + (x * -16).toFixed(1) + 'px,' + (y * -10).toFixed(1) + 'px)';
    });
    figure.addEventListener('mouseleave', function () {
      video.style.transform = '';
    });
  }
})();
