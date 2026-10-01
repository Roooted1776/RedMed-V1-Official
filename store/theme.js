// Runs before paint. The store stays red and white.
(function () {
  document.documentElement.dataset.theme = 'light';
  var m = document.querySelector('meta[name="theme-color"]');
  if (m) m.setAttribute('content', '#ffffff');
})();
