// Saved choice wins; first visit starts in dark mode. Safe to load twice (home re-applies after its bundle).
(function () {
  var root = document.documentElement;
  var meta = document.querySelector('meta[name="theme-color"]');
  var saved = null;
  try { saved = localStorage.getItem('redmed-theme'); } catch (e) {}
  var dark = saved ? saved === 'dark' : true;
  function paint() {
    var on = root.dataset.theme === 'dark';
    if (meta) meta.setAttribute('content', on ? '#141011' : '#ffffff');
    var sw = document.getElementById('theme-toggle');
    if (sw) sw.setAttribute('aria-checked', on ? 'true' : 'false');
  }
  root.dataset.theme = dark ? 'dark' : 'light';
  paint();
  if (window.__rmTheme) return;
  window.__rmTheme = true;
  new MutationObserver(paint).observe(root, { attributes: true, attributeFilter: ['data-theme'] });
  document.addEventListener('DOMContentLoaded', paint);
  document.addEventListener('click', function (e) {
    if (!e.target.closest || !e.target.closest('#theme-toggle')) return;
    try { localStorage.setItem('redmed-theme', root.dataset.theme); } catch (err) {}
  });
})();
