// Band payloads stay in the URL fragment and open Assist.
// Never send #d= to the account portal or Supabase.
function forwardMedicalFragment() {
  if (/(?:^#|&)d=/.test(location.hash)) {
    location.replace('https://redmed.live/tapper/' + location.search + location.hash);
  }
}
forwardMedicalFragment();
addEventListener('hashchange', forwardMedicalFragment);
