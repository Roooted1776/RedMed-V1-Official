// Band payloads stay in the URL fragment and open Assist.
// Never send #d= to the account portal or Supabase.
function forwardMedicalFragment() {
  if (/(?:^#|&)d=/.test(location.hash)) {
    location.replace('https://redmed.live/tapper/' + location.search + location.hash);
  }
}
forwardMedicalFragment();
addEventListener('hashchange', forwardMedicalFragment);

// Storefront header links here with ?auth=signin|signup — open that dialog.
function openAuthFromQuery() {
  const mode = new URLSearchParams(location.search).get('auth');
  if (mode !== 'signin' && mode !== 'signup') return;
  const tryClick = () => {
    const btn = document.querySelector('.account-trigger[data-mode="' + mode + '"]');
    if (!btn) return false;
    btn.click();
    return true;
  };
  const start = () => {
    if (tryClick()) return;
    let n = 0;
    const t = setInterval(() => {
      n += 1;
      if (tryClick() || n > 40) clearInterval(t);
    }, 50);
  };
  if (document.readyState === 'complete') start();
  else addEventListener('load', start);
}
openAuthFromQuery();
