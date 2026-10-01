# Store (`/store/`)

Static page. No Shopify, no server, no database. Checkout is a Square Payment Link.

## Go live
1. Square Dashboard > Payments > Payment Links > Create. One link per pack (single, pair, family).
2. On each link turn on: collect shipping address (fulfillment > shipping) and email receipt.
3. Paste each `https://square.link/u/...` into `config.js` and match the price.
4. Orders, receipts and refunds live in the Square Dashboard.

Debit or credit card entry and Apple Pay are on Square's hosted page (enable Apple Pay in
Square's checkout settings). Do not add card fields here: that needs a payment server and
breaks the static-only rule in `AGENTS.md`. Publishable links only. Never commit a Square
access token.

## Pages, films and images
- The page is `store/index.html`. `scripts/deploy-vps.sh` ships it as `init.html` (the live nginx opens that name for `/store/`).
- Films and images are shared with the home page and load from `/assets/`: `hero-hd.mp4` / `hero-mobile.mp4`
  (phones), `Band.webp`, `band-spin-poster.jpg`, `how-it-works-poster.jpg`. Deploy the home page first, because it ships them.
- Films autoplay muted and loop. They start just before they scroll into view and rest when far off screen.
  Reduced motion and Low Power Mode keep the poster until Play is pressed.
- To replace a film: `bash scripts/encode-store-video.sh ~/Downloads/your-video.mp4 4` (the `4` is the poster frame in seconds),
  keep the same file names in `assets/`, then deploy home, then the store.
- The three steps live in their own "How it works" section below the films.
- Theme: first visit is dark; the header switch saves the choice. `theme.js` runs before paint.
