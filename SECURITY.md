# Security policy

RedMed has no profile server and no PHI database. The band profile lives only
in the URL `#d=` fragment (decoded in the browser) and, for the Owner app, in
the iOS Keychain on-device.

## Report a vulnerability

Use a private advisory: <https://github.com/Roooted1776/RedMed-V1-Official/security/advisories/new>.
Or email help.RedMed@gmail.com.

Do not open public issues containing live keys or real `#d=` payloads.

## In scope

- XSS or script injection via `#d=` rendering in `tapper/`
- Service worker cache poisoning or `#d=` reaching any HTTP log, cache key, or server
- Keychain bypass or Face ID gate bypass in `owner/`
- Universal Link / custom-scheme hijack of a band tap
- Sending Assist `#d=` or Owner ICE data through an MCP, Supabase, or VPS

Full policy text: Help → Policies → Security in the app, or `/Document/#security`.
