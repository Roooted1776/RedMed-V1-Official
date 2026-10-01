# Public site map

These are the only public pages. Add a page here before linking to it.

| Page | URL | Source in repo |
| --- | --- | --- |
| Main page | https://redmed.live/ | `home/index.html` (captured live build; see `home/README.md`) |
| How it works | https://redmed.live/#how | section of `home/index.html` |
| Technology | https://redmed.live/#technology | section of `home/index.html` |
| Sign in / log in | https://redmed.live/?auth=signin | portal bundle in `home/assets/` |
| Store | https://redmed.live/store/ | `store/index.html` (also `init.html`, see below) |
| Store FAQ | https://redmed.live/store/#questions | section of the store page |
| NFC tap page (emergency reader) | https://redmed.live/tapper/ | `tapper/`, stable path used by written bands. Do not move or rename. |

## Open items

- Two store sources exist and have drifted: `init.html` (root, used by `scripts/deploy-vps.sh`, which copies it to `index.html`) and `store/index.html` (served at `/store/`, listed in `_redirects`). Pick one as canonical before the next store deploy.
- The main page is the apex `redmed.live`. `www.redmed.live` is not confirmed to resolve or redirect. Verify DNS or add a redirect before using `www` anywhere.
- `?auth=signin` is a sign-in deep link. `#how` and `#technology` stay plain anchors on the main page, so they do not open the sign-in dialog.
