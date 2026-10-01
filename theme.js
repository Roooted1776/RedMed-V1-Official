// Runs before paint. Same idea as the main page (system default, data-theme on <html>) plus remembered choice.
(function () {
  var t;
  try { t = localStorage.getItem('redmed-theme'); } catch (e) {}
  if (t !== 'dark' && t !== 'light') t = matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  document.documentElement.dataset.theme = t;
})();
