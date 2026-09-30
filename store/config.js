// Store config. The ONLY file you edit to go live.
// 1. Square Dashboard > Payments > Payment Links > create one link per pack.
// 2. Paste each https://square.link/u/... URL into `link` below.
// 3. Make each price here match the price on its Square link.
// Publishable links only. Never put a Square access token in this repo.
window.REDMED_STORE = {
  tiers: [
    { id: 'solo',   name: 'Single Band',  bands: 1, price: 34, blurb: 'One blank NTAG216 band.',              link: '' },
    { id: 'pair',   name: 'Pair',         bands: 2, price: 59, blurb: 'Two bands. Wear one, keep a spare.',   link: '', badge: 'Most popular' },
    { id: 'family', name: 'Family Pack',  bands: 4, price: 109, blurb: 'Four bands for the whole household.', link: '' }
  ],
  currency: 'USD',
  supportEmail: 'help.RedMed@gmail.com'
};
