# ADR: Keep emergency access independent of operations

Date: 2026-09-26. Status: preserves the current product boundary; new ops implementation awaits approval.

## Context

RedMed is intended to help a stranger access wearer-selected emergency information by tapping or scanning a band. The architecture must not turn an expired account, unavailable database, or failed automation into a barrier to reading that information.

## Decision

Keep two distinct paths. Do not move the public medical-card viewer onto the VPS or introduce Supabase into band decoding.

```text
Wearer → Owner iOS app → local Keychain
                      → NFC / QR payload on band
Responder → static Assist shell + local decode → displayed emergency card

Developer → GitHub tests / release gates → static deployment
Operator  → Hostinger operations, outside this repository
         → Supabase ops release evidence (no MCP component)
```

## Responsibilities

- **Assist, `tapper/`:** unauthenticated medical-card viewer, no ads, no tracking SDKs, no cloud profile lookup. Keep the permanent URL path for existing bands.
- **Owner, `owner/`:** editing, consent, local storage, preview, explicit NFC write and read-back. Do not enable parked capabilities without entitlement and physical-device verification.
- **MCP:** not a module of this repository. Operator tooling stays outside Assist, Owner, the static origin, and `redmed_ops`. Never send real band URLs or medical content to an MCP.
- **Supabase, `supabase/`:** bounded release evidence in `redmed_ops`, not patients, accounts for responders, or condition histories.
- **Hostinger VPS:** ops services and future synthetic monitoring. A VPS restart must not take down the Assist origin.
- **Hostinger static origin:** serve the emergency shell correctly over the stable production URL. DNS/SSL and content correctness are release requirements.

## Privacy and reliability limits

- **Publicly readable by design:** the wearer deliberately discloses selected information to anyone with the band payload. A shared client decoding key is not a confidentiality boundary; do not market it as making band data private from a scanner.
- **No first-visit offline guarantee:** a responder who has never loaded the shell cannot rely on a service worker being installed. Cache-based offline behavior depends on registration and cached resources; see [MDN's service-worker lifecycle](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API/Using_Service_Workers).
- **Cache loss:** browsers may lose cached content. Retain an honest failure state and a physical non-digital fallback as a product requirement, rather than treating prior loading as a permanent guarantee.
- **Independent copies:** changing or deleting the Owner profile does not remotely rewrite a band. The proposed release process must test and explain this distinction.
- **No authenticity claim:** wearer-entered notes are not automatically clinician-verified instructions. A future verification feature needs an explicit provenance and expiry design.
- **No certification claim:** this architecture record does not determine regulatory status or certify compliance. Any cloud-medical-data expansion requires a separate architecture, legal and clinical review.

## Alternatives rejected for V1

- **Cloud profile lookup on every scan:** creates an emergency-path availability dependency and changes privacy scope.
- **Responder login:** conflicts with immediate stranger access.
- **AI-generated emergency treatment at scan time:** introduces variable clinical output and network dependency. Approved content should be deterministic and available locally.
- **Repo-wide folder migration:** risks stable paths, Xcode references and deployment scripts without solving the immediate launch blockers.

## Revisit when

Reconsider only after a demonstrated product need for remote profile updates, clinician-signed plans, caregiver permissions or cross-device synchronization. Document disclosure, revocation, freshness, failure behavior and evidence before implementing that change.
