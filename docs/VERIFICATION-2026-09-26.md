# Foundation verification

Scope: development-foundation patch based on main `a7740a2`. This evidence does not approve a production release.

## Automated results

- **Codec:** Node lockstep and behavioral suite passed with worker cache version v179.
- **Hardware contract:** all 51 static checks passed. These are not physical NFC tests.
- **Service worker:** all 26 assertions passed, including alternate URL fallback, invalid HTTP-200 pages, quota failure, invalid old cache entries and preservation of older caches after failed installation.
- **Worker/device:** Node suite passed.
- **MCP:** seven tests and syntax checks passed; dependency audit reported zero vulnerabilities at inspection.
- **Local HTTP smoke:** all checks passed against the local static server.
- **Public HTTP smoke:** failed against redmed.live; direct response inspection identified the Hostinger parked-domain page.
- **Diff and shell syntax:** `git diff --check` and `bash -n scripts/check-release.sh` passed.

The added cache regression tests were run before the fix and produced seven failing assertions. After the fix, the full service-worker suite passed.

## Browser results

Headless Chromium, local static server, synthetic data only. QA inventory covered new cache behavior, reader regression states and preview layout; clinical actions and physical-device behavior were outside this test.

| Case | Result |
|---|---|
| Online shell registration and activation | v179 present in Cache Storage and controlling the page |
| Empty card | Expected No Patient state; no JavaScript page errors observed |
| Warm offline reload | Shell and synthetic named card rendered |
| Aid tab | Click selected the Aid tab; return to medical tab worked |
| Malformed payload | Expected Couldn't Read This Band state |
| Previous-card leak regression | Synthetic name absent after malformed payload |
| Cold offline, new browser context | Network load failed as expected; no false offline guarantee |
| Mobile 390×844 | Screenshot inspected; no horizontal overflow or clipped initial card |
| Desktop 1440×900 | Screenshot inspected; no horizontal overflow or clipped initial card |

## Not verified or deployed

- **Supabase migration:** prepared, not applied; production approval required. The role/constraint test file has not been executed against the project.
- **VPS:** blocked by MCP 401; no infrastructure state or backup claims made.
- **iOS:** no Xcode build run for this patch in this session; the bundled worker changed and still needs the existing macOS CI gate.
- **Physical devices:** Safari, Android browsers, NFC write/read-back, QR, wet/curved band and large-text/screen-reader checks still required.
- **Clinical content:** no clinical review performed and no treatment instructions changed.
- **Public deployment:** no change to redmed.live, its DNS, or its production service worker.
- **Browser scope:** this is targeted regression QA, not complete UI, accessibility, security or clinical validation.
