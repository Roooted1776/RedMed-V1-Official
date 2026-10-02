# Associated Domains (Universal Links)

## Problem this solves

The wearer's band on their wrist must not **Safari-hijack their own iPhone**
when the phone is nearby (pocket / clasp / Background Tag Reading), and it
must not arm SOS. The tap still opens tapper.html inside the app.

**Fix:** Associated Domains. Hosted `/tapper/` is a Universal Link. With
RedMed installed, iOS opens the **app** (bundled tapper.html) instead of
Safari. The band URL stays on the VPS. The owner database is not part of
this open.

| Phone | Band tap |
| --- | --- |
| RedMed installed, decodable `#d=` (own band or someone else's) | Ungated in-app tapper.html above ConsentGate — no Face ID, no Before You Continue, no Keychain write, no SOS. Band URL stays on the VPS. Owner database is not read here. |
| RedMed installed, missing or undecodable `#d=` | App foreground only — no card sheet, no SOS |
| RedMed **not** installed | Safari Assist medical card only — band tap does **not** arm SOS (SOS is toggle or US Crash Detection collision) |

AASA is live (`apple-app-site-association` + `.well-known/`, paths
`/tapper`, `/tapper/`, `/tapper/*`, plus `components` / `appIDs`). After
restore + merge, re-run Publish tapper / `scripts/publish-github-io.sh` so
github.io picks up the widened AASA.

**No custom-scheme fallback.** Assist used to jump to `redmed://band#d=`
after painting. Removed: custom URL schemes are not exclusive on iOS, so any
installed app registering `redmed` received the tapped patient's profile
(the `#d=` key is public), and Safari errors on phones without RedMed. The
app no longer ingests `redmed://band` either. Universal Links are the only
band-tap path into the app. SOS never auto-arms from band tap.

**Ship rule:** NFC write (`nfcHardwareEnabled`) and Associated Domains need
the same paid Program, so they ship together. In `owner/RedMed`,
`scripts/test-nfc-hardware.mjs` fails if `nfcHardwareEnabled` is true without
`associatedDomainsEnabled` + `applinks:` in the entitlements.

## In git

`AppConfig.associatedDomainsEnabled = true` and `RedMed.entitlements` has
`applinks:redmed.live`. NFC Tag Reading stays parked. A personal / free
Apple Developer team cannot provision Associated Domains, so Automatic
Signing fails while this entitlement is present. Build with a paid team
and enable Associated Domains on App ID `com.redmed.app`.

Leave `onContinueUserActivity` in place. Without a signed build that
includes the entitlement, a band tap still opens Safari.

## Rejected: local-network / BLE band ranging

Do **not** add Bonjour, Multipeer, Wi‑Fi Aware, CoreBluetooth, or "find bands
nearby." NTAG216 is **passive** — no battery, no radio. It never appears on a
local network. HF NFC physics + Universal Links are the controls.

## Restore (paid Program)

1. Put `com.apple.developer.associated-domains` → `applinks:redmed.live`
   back in `RedMed.entitlements` (`redmed.live` is the live custom domain per
   `docs/domain.md` and the host bands are written with —
   `AppConfig.medicalCardBaseURL` = `https://redmed.live/tapper/`). Do not
   swap it back to the old `roooted1776.github.io` backup host.
   `test-nfc-hardware.mjs` fails if `applinks:redmed.live` is missing.
   Optional extra: `applinks:roooted1776.github.io` as a second entry, only
   so bands written before the cutover also open the app (github.io still
   serves them). `redmed.live` must serve the AASA over valid HTTPS with no
   redirect (staged by `scripts/stage-site.sh`).
2. Set `AppConfig.associatedDomainsEnabled = true`.
3. Developer portal → App ID `com.redmed.app` → enable **Associated Domains**.
4. Xcode → Signing & Capabilities → **Associated Domains** (same `applinks:`).
5. Build with a paid Apple Developer Program team (not a personal / free team).
6. Confirm both AASA files (`apple-app-site-association` and
   `.well-known/apple-app-site-association`) are still serving from
   `redmed.live` — they already are (`docs/domain.md`); this step is only a
   re-check, not a pending migration. If the write base ever moves, update
   `medicalCardBaseURL`, the `applinks:` host and both AASA files together.

## Device tests

1. RedMed installed + tap **own** wrist band → bundled tapper.html, **no
   Safari**, no SOS, no Face ID, no Keychain write.
2. RedMed installed + tap **another** RedMed band → same ungated in-app
   tapper.html (no Face ID / Before You Continue / login), no Keychain
   write, no SOS.
3. RedMed **not** installed + tap any band → Safari Assist medical card only
   (no login, no biometrics, no start screen). SOS arms only via SOS · Locate
   Me toggle or US Crash Detection collision — never from band tap alone.
4. Confirm `applinks:` in the entitlements and both AASA files agree on
   `redmed.live` (custom domain cutover already landed, `docs/domain.md`).
5. Tap an `https://redmed.live/tapper/#d=…` band with RedMed installed and
   confirm the in-app card appears for someone else's band. `onOpenURL` and
   `NSUserActivity.userInfo` are checked as well as `webpageURL`, because
   Universal Links sometimes omit the fragment on one of those paths.
   `redmed://` is still never ingested. If every path arrives without `#d=`,
   the app stays quiet (no guessed card, no SOS) — do not ship NFC write
   until a device tap shows the fragment on at least one of those paths.

## Park again (personal team only)

1. Remove `com.apple.developer.associated-domains` from `RedMed.entitlements`
   (leave an empty `<dict></dict>` if NFC / HealthKit are also parked).
2. Set `AppConfig.associatedDomainsEnabled = false`.
3. Leave `onContinueUserActivity` in place — no-op without the entitlement.
4. Without the entitlement, wrist proximity can Safari-open again on a phone
   that has RedMed installed.
