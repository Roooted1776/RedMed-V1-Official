// Runs before paint. Saved choice wins, then system preference, else light.
(function () {
  var t = 'light';
  try { var s = localStorage.getItem('redmed-theme'); if (s === 'dark' || s === 'light') t = s; else if (window.matchMedia && matchMedia('(prefers-color-scheme: dark)').matches) t = 'dark'; } catch (e) {}
  document.documentElement.dataset.theme = t;
  var m = document.querySelector('meta[name="theme-color"]');
  if (m) m.setAttribute('content', t === 'dark' ? '#141011' : '#ffffff');
})();
