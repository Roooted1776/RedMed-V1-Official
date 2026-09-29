# RedMed release runbook

This is an operational gate, not medical or regulatory approval. A release must carry separate evidence for code, public hosting, hardware and content safety.

## Prepare

- **Scope:** use a short-lived branch from current `main`; do not mix clinical wording changes with infrastructure refactors.
- **Data:** synthetic fixtures only. Never paste real band fragments into GitHub, MCP tools, logs, test reports or screenshots.
- **Dependencies:** run `make setup`; use committed lockfiles and do not run install lifecycle scripts with credentials present.
- **Verification:** run `make check` and `git diff --check`. Review the complete diff, including generated service-worker copies.
- **iOS:** run the existing macOS build for changes affecting the bundled shell; an unsigned simulator build does not prove physical NFC.

## Gate the public URL

Run `make release-check` from the exact candidate revision. The command fails on the live-origin smoke test rather than converting DNS or parking failures into a pass.

Verify separately on clean physical iPhone and Android browsers. Use synthetic cards; inspect the actual card content, not just a 200 response.

- **Fresh online phone:** NFC and QR each open the intended card without account, app install, or modal consent gate.
- **Warm offline phone:** after successful installation, airplane mode plus a second tap shows the synthetic card.
- **Cold offline phone:** record the limitation honestly; do not claim the cached-shell fallback is reachable before a service worker exists.
- **Bad payload:** malformed, oversized, tampered and unsupported payloads never show a previous person's card.
- **Old band:** legacy supported payload versions still decode after deploying a new shell.
- **QR:** size, print contrast, wear and curved-band scanning must be physically tested. Do not assume NFC tests cover it.

## Clinical-content gate

Require a named qualified clinical reviewer for condition-specific action content before pilot use. Record an immutable content version, source, intended audience, locale, review date, next-review date and sign-off in the controlled clinical-content process.

No runtime AI diagnosis, medication dosing generation or autonomous treatment rewriting. Display wearer-entered instructions as wearer-entered unless an actual verification workflow exists.

## Deploy with approval

- **Evidence:** record the commit, build result, strict origin result and applicable hardware/content approvals. If the ops ledger is approved, store only its enumerated metadata.
- **Artifact:** run `make stage`; review the static bundle. Keep a checksum manifest and a known-good previous bundle outside the public web root.
- **Approval:** obtain authorization for the exact production deployment and any DNS change. Do not apply raw shell fixes to bypass an MCP authentication failure.
- **Upload:** use the existing Hostinger deploy script and approved credential channel. Never change the band URL to a preview host.
- **Verify:** rerun the live smoke immediately after upload, then check a physical synthetic band and inspect the service-worker version.

## Rollback

Stop rollout if the shell, decoder or public route fails. Restore the known-good static bundle through the approved deployment path, rerun live smoke and test an existing band.

Service-worker rollback needs special care: an already active bad worker may keep serving its cache. Ship the restored code under a new, higher cache version, sync all three copies, and test its update from the previous version; do not rely only on re-uploading an older worker.

Do not delete operations evidence during rollback. Schema removal, firewall changes, secret rotation, infrastructure rebuilds and band rewriting are separate actions requiring their own approval.

## Incidents and monitoring

- **P0:** public origin parks, fails TLS, or cannot display a valid card. Pause new band encoding/fulfillment tied to that URL; restore availability and validate before resuming.
- **P0:** wrong person's data or unsafe content appears. Stop the affected release and involve the clinical owner; do not collect a real payload in ordinary logs.
- **P1:** MCP or ops database unavailable. Suspend automation and recover operations; the emergency path should continue independently.
- **Proposed monitoring:** independent synthetic checks of fixed paths, TLS and shell markers; no scan telemetry, payload URLs or patient identifiers. Implement alert delivery, retention and a tested response owner before calling monitoring operational.

Owner: Max for release decisions and escalation. Clinical and operations backup owners must be assigned before pilot.
