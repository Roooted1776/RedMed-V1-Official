# RedMed account portal

Browser sign-in for the same Supabase account the iOS app's Help → Account
sync uses (email one-time code, no password). This is a **separate surface**
from `tapper/`:

- Never imports from or shares CSS/JS with `tapper/`.
- Never reads, writes, or references a `#d=` fragment.
- Never touches `redmed_ops` or any ops/admin schema.
- Talks directly to Supabase (`redmed_owner.profiles`) with the publishable
  (anon) key in `supabase-config.js` — that key is meant to be public; RLS on
  the table is what actually scopes access to the signed-in user's own row.

Field-for-field, this mirrors `owner/RedMed/OwnerSupabaseClient.swift`'s
`OwnerProfileRecord` and its `/auth/v1/otp` → `/auth/v1/verify` flow. Editing
a profile here syncs to the same row the iPhone app reads — it does **not**
rewrite the physical NFC band; that still requires the app's own NFC tab.

`bracelet_linked` is intentionally never read or written by this portal — per
the iOS client's own comment, that flag means "verified by this device's
CoreNFC," and a browser session has no business claiming it.

## Local testing

```
cd portal
python3 -m http.server 8000
```

Open `http://localhost:8000/`, sign in with a real email you can read, and
confirm the code round-trip and profile save/reload work. Cross-check the
same account in the iOS Simulator afterward to confirm real sync, not just a
local echo.

## Deploying

This directory is a genuinely separate static site from `tapper/` — per
`AGENTS.md`'s "Surfaces (do not mix)" rule, it should be served by its own
container/route (e.g. `account.redmed.live`), not folded into the existing
`redmed-portal` container that serves `tapper/`. See
`docs/release/OPS.md` and `docs/domain.md` for the VPS/Traefik/DNS steps that
happen outside this repo.
