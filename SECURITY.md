# Security policy

A band tap still has no lookup server. The rescuer copy is only the URL `#d=`
fragment, decoded in the browser. The Owner app keeps the same profile in the
iOS Keychain and, when account sync is on, in Supabase schema `redmed_owner`
for that signed-in wearer. That account is not a HIPAA certification. The tap
page does not read it.

## Report a vulnerability

Use a private advisory: <https://github.com/Roooted1776/RedMed-V1-Official/security/advisories/new>.
Or email help.RedMed@gmail.com.

Do not open public issues containing live keys or real `#d=` payloads.

## In scope

- XSS or script injection via `#d=` rendering in `tapper/`
- Service worker cache poisoning or `#d=` reaching any HTTP log, cache key, or server
- Keychain bypass or Face ID gate bypass in `Roooted1776/RedMed-iOS`
- Universal Link / custom-scheme hijack of a band tap
- Assist `#d=` or wearer rows through an MCP or the VPS, or a tap-page read of Supabase

Full policy text: Help → Policies → Security in the app, or `/Document/#security`.
