# Public site map

These are the only public pages. Add a page here before linking to it.

| Page | URL | Source in repo |
| --- | --- | --- |
| Main page | https://redmed.live/ | `home/index.html` (captured live build; see `home/README.md`) |
| How it works | https://redmed.live/#how | section of `home/index.html` |
| Technology | https://redmed.live/#technology | section of `home/index.html` |
| Sign in / log in | https://redmed.live/?auth=signin | portal bundle in `home/assets/` |
| Store | https://redmed.live/store/ | `store/index.html`, deployed as `init.html` on the VPS by `scripts/deploy-vps.sh` (root `init.html` is an older copy kept for the GitHub Pages backup) |
| Store FAQ | https://redmed.live/store/#questions | section of the store page |
| NFC tap page (emergency reader) | https://redmed.live/tapper/ | `tapper/`, stable path used by written bands. Do not move or rename. |

## Open items

- Store source: `store/index.html` is canonical for the VPS. Root `init.html` / `store.css` / `store.js` are an older copy used only by the Pages backup scripts; update or retire them together.
- The main page is the apex `redmed.live`. `www.redmed.live` resolves and serves the same pages (checked 2026-10-01).
- `?auth=signin` is a sign-in deep link. `#how` and `#technology` stay plain anchors on the main page, so they do not open the sign-in dialog.
