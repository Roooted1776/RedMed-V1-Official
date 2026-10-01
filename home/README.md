# Homepage (`https://redmed.live/`)

Captured from the live site on 2026-10-01. The source project for this page was not in the repo, so this
directory is the live build, saved so it is no longer only on the server.

## What is here
| File | Notes |
| --- | --- |
| `index.html` | Live HTML plus the changes below |
| `assets/index-B1ncWDwK.css` | Live, unchanged |
| `assets/index-persist-admin.js` | Live, unchanged. Minified Vite bundle (no source map, no source) |
| `legacy.js` | Live, unchanged. Forwards a `#d=` band link to `/tapper/` |
| `hero.js` | Autoplay, pause / play, click-to-toggle, and pointer shift for every film on the page. No network calls. |
| `band-hero.webp`, `nfc-detail.webp`, `favicon.svg` | Poster and stills. `band-hero.webp` is the hero poster. |
| `theme.js` | Dark by default on first visit; the header switch saves the choice. Loaded before and after the bundle. |
| `process.js` | "See it in action": the step list follows the film. Jumping to a step needs a seekable video (the portal server has no range support, so it only follows). |
| `../assets/hero-hd.mp4`, `hero-mobile.mp4` | Hero film (muted loop), full size and a phone size. |
| `../assets/how-it-works.webm` / `.mp4`, `how-it-works-poster.jpg` | The "See it in action" film. |

## Changes from live (HTML only)
- Header nav: new `Store` link to `/store/`. The `Open tap page` link is removed.
- Member area: the `Open the no-login tap page` button is removed. `legacy.js` still forwards old `#d=` band links.
- Hero: new `Shop the band` button to `/store/`.
- Hero block plays `assets/hero-hd.mp4` (`hero-mobile.mp4` on phones), muted, looping, autoplay, as a full-width background. Pause / play and click the frame. Reduced motion keeps the poster until Play.
- Header: a day / night switch. The old light-only override in `red-white.css` now follows the theme.
- New section "See it in action" between the privacy section and the FAQ.
- Removed wording: "concept" captions and "in development". The demo opener stays in the page, hidden, because the bundle binds to it.
- All buttons and controls are 44px tall; headings capitalise every word.
- The CSP header on this page has no `media-src`, so `blob:` video is blocked. Keep video files same-origin.
- `<style>`: lets the hero buttons wrap on screens 900px wide or less (the extra button pushed the third one off a phone screen).

## Read before deploying
- This page is a member portal, not only a landing page. The bundle carries the Supabase client (project
  `mohxobgyjkcmkqxijgeg`, publishable key only, no service-role key): Sign in / Create account, a band registry,
  password change, an email-link verify panel, and an Administration dialog (account list, search, invite).
- Owner rule (2026-10-01): keep Sign in on redmed.live. Creating an account stores that account identity
  (email / auth) — plus optional non-medical band inventory metadata later — never medical `#d=` profiles.
  `AGENTS.md` matches this.
- The Administration dialog is public markup. Access must be enforced by Supabase (RLS and role checks), not by the page.
- The bundle cannot be edited sensibly. To change portal behavior, rebuild it from source or remove the bundle.
- `index.html` here is the home page. `https://redmed.live/` and `/index.html` serve it, and this file may be updated as the home page. The store page is `store/index.html`; the VPS serves it as `init.html` for `/store/`. Do not copy this home page over the store page, or the reverse.
- Deploy: `DOCROOT=/opt/redmed-portal/site MODE=home CONFIRM_HOMEPAGE=yes scripts/deploy-vps.sh deploy` (after `discover`). Deploy home before the store; the store reads shared media from `/assets/`.
  `scripts/stage-site.sh` also stages this directory as `/`. Find the docroot first
  (`docker inspect redmed-portal-live --format '{{json .Mounts}}'`).
