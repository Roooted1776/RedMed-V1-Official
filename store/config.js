// Store config. The ONLY file you edit to go live.
// 1. Square Dashboard > Payments > Payment Links > create one link per pack.
// 2. Paste each https://square.link/u/... URL into `link` below.
// 3. Make each price here match the price on its Square link.
// Publishable links only. Never put a Square access token in this repo.
window.REDMED_STORE = {
  tiers: [
    { id: 'solo',   name: 'Single Band',  bands: 1, price: 40, blurb: 'One blank NTAG216 band.',              link: '' },
    { id: 'pair',   name: 'Pair',         bands: 2, price: 65, blurb: 'Two bands. Wear one, keep a spare.',   link: '', badge: 'Most popular' },
    { id: 'family', name: 'Family Pack',  bands: 3, price: 70, blurb: 'Three bands for the household.',      link: '' }
  ],
  currency: 'USD',
  supportEmail: 'help@redmed.live'
};
