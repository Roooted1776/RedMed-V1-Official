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

## How it works video
The "How it works" section plays `assets/how-it-works.webm` / `.mp4` (poster `how-it-works-poster.jpg`), then shows the three
steps as horizontal cards (a swipe row on phones). To replace the film with your own Higgsfield video:
1. Download the video from Higgsfield (mp4).
2. `bash scripts/encode-store-video.sh ~/Downloads/your-video.mp4 4` (the `4` is the poster frame, in seconds).
3. Commit the three files in `store/assets/`, merge, redeploy the store container.
The caption in `index.html` says "concept film". Change it if the new video shows real product footage.
It autoplays muted and looping while on screen; reduced motion and Save-Data get the poster only.
