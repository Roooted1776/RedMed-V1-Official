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
