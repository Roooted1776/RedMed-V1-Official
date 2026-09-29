# Store (`/store/`)

Static page. No Shopify, no server, no database. Checkout is a Stripe Payment Link.

## Go live
1. Stripe Dashboard > Payment Links > New. One link per pack in `config.js`.
2. On each link turn on: collect shipping address, and (optional) adjustable quantity off.
3. Paste each `https://buy.stripe.com/...` into `config.js` and match the price.
4. Orders, receipts and refunds live in the Stripe Dashboard.

Card entry (debit or credit) and Apple Pay are on Stripe's hosted page. Do not add card
fields here: that needs a payment server and breaks the static-only rule in `AGENTS.md`.
Publishable links only. Never commit a Stripe secret key.
