# Store checkout: Square setup (about 20 minutes)

The Store page (`https://redmed.live/store/`) does not take payments itself. When a buyer clicks
**Continue to Square**, they go to a **Square payment link**. Square's own page takes the card,
debit card, Apple Pay and Google Pay. This keeps card data off redmed.live and needs no server.

You make **three links**, one per pack, then paste them into `store/config.js`.

| Pack | Price | Bands |
| --- | --- | --- |
| Single Band | $34 | 1 |
| Pair | $59 | 2 |
| Family Pack | $109 | 4 |

The price on each Square link must match the price in `store/config.js`. Square charges its own price, not ours.

## Step 1. Create each link (repeat 3 times)

1. Sign in at https://squareup.com/dashboard.
2. Go to **Payments** > **Payment links** > **Create link** (menu names can change; look for "Payment links" or "Checkout links").
3. Choose **Sell an item** (this is the only type that shows a **quantity selector**, per Square's help).
4. Item name: `RedMed Band, Single Band` (or Pair / Family Pack). Price: 34 / 59 / 109 USD.
5. Turn **on**: shipping (set your rate or free shipping), collect the buyer's **email**, quantity selector.
6. Payment methods: leave **card** on. Turn **on** Apple Pay and Google Pay if Square shows a toggle. Square's help says the buyer's browser then shows the best button for their device.
7. Save. Square gives you a link that looks like `https://square.link/u/AbC123`.

Apple Pay and Google Pay only appear on phones and browsers that support them. **Unverified:** whether Apple Pay needs extra setup on your Square account. Test it (Step 3).

## Step 2. Paste the links

In `store/config.js`, put each link between the quotes after `link:`:

```js
{ id: 'solo',   name: 'Single Band', ..., link: 'https://square.link/u/AbC123' },
```

Only paste the `https://square.link/u/...` address. **Never paste an access token or password**: they are secret, and `scripts/test-store-config.mjs` fails if it sees one.
Then commit, and redeploy the Store container (ask Claude: "redeploy the store").

## Step 3. Test one real order

1. Open `https://redmed.live/store/` on your iPhone.
2. Tap **Buy Single Band**, tick the box, tap **Continue to Square**.
3. Check: the price is $34, shipping and email are asked for, Apple Pay shows.
4. Place a real order with your own card, then **refund it** in the Square Dashboard.

## Until the links exist

The button says **Order by email** and opens an email to `help@redmed.live` with the pack and price filled in. Nothing breaks.

## Rules that stay in force

- No card fields on redmed.live. Card entry stays on Square's page.
- No Square access token anywhere in this repo (`AGENTS.md`, `store/README.md`).
- Store copy must not claim the band is written or HIPAA certified.
