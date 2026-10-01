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
| `band-hero.webp`, `nfc-detail.webp`, `favicon.svg` | Live, unchanged |

## Changes from live (HTML only)
- Header nav: new `Store` link to `/store/`.
- Hero: new `Shop the band` button to `/store/`.
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
- Deploy: `MODE=home CONFIRM_HOMEPAGE=yes scripts/deploy-vps.sh deploy` (after `discover`).
  `scripts/stage-site.sh` also stages this directory as `/`. Find the docroot first
  (`docker inspect redmed-portal-live --format '{{json .Mounts}}'`).
