# RedMed development control center

Prepared 2026-09-26 against `a7740a2405b222d87772b55450cc04ec4ea3dba8`. The immediate goal is a reliable, testable emergency-information product, not a larger backend.

## Executive decision

Keep medical information on the existing Owner/band path. The product, website, database, and repository structure do not depend on an MCP.

**Launch is blocked.** The live product URL returned a Hostinger parking page during this inspection; the response was HTTP 200 but lacked the medical-shell marker. The existing smoke test failed at the public origin.

## Verified baseline

| Area | Observation | Meaning |
|---|---|---|
| Repository | Assist `Roooted1776/RedMed-V1-Official`; Owner `Roooted1776/RedMed-iOS` | Web and iOS are separate gits. Codec lockstep is `contracts/d-codec-fixtures.json` |
| GitHub CI | Gates passed on `a7740a2` | Local code checks are not proof of live hosting |
| Public Assist | Parking page at `https://redmed.live/tapper/` | P0; do not approve new encoded-band launch |
| Supabase | `RedMed Secure Data` active; no public tables or migration history at inspection | Ops ledger is a new, explicitly scoped change |
| Supabase advisor | No security findings on the inspected baseline | Not a health-data compliance assessment |
| Owner capabilities | NFC and associated-domain features remain parked in configuration | Physical write/read-back remains a pilot gate |
| Project context | File repo was empty; no knowledge index materialized after sync | This control-center pack seeds durable project structure |

## Implemented locally in this pass

- **Offline readiness:** worker v179 only completes installation after successfully storing a validated shell. Invalid HTTP-200 content, cache failures and invalid old cache entries no longer count as success.
- **Regression coverage:** seven previously failing cache assertions now pass; service-worker copies remain in lockstep. Older valid shell recovery remains supported.
- **Cache persistence:** background refresh promises include cache writes, including navigation-preload persistence.
- **Developer commands:** `make setup`, `make check`, `make release-check`, `make stage`.
- **Strict release workflow:** a manual, read-only GitHub workflow tests the actual product origin; a parked host fails.
- **Architecture and runbook:** emergency/ops boundary, failure modes, deployment, rollback and clinical-review requirements are documented.
- **Supabase preparation:** versioned private-schema release ledger and transactional role/constraint tests. Production application awaits explicit approval.

These changes are not yet merged into GitHub main or deployed to redmed.live. A private preview, if supplied, is for inspection only and is not a band write destination.

## Project structure

Retain the current physical layout; do not relocate the iOS project or stable web paths. Add explicit ownership and gates around the existing modules.

| Path | Responsibility | Review owner |
|---|---|---|
| `tapper/`, root `sw.js` | Responder card, offline shell, decode | Product engineering; clinical review when content changes |
| `Roooted1776/RedMed-iOS` | Wearer profile, consent, NFC, account sync | iOS engineering |
| `supabase/migrations/` | Versioned ops schema, never medical profiles, no MCP | Backend/operations |
| `supabase/tests/` | Privilege and data-contract tests | Backend/security |
| `scripts/`, `.github/workflows/` | Repeatable checks and release gates | Backend/operations |
| `docs/adr/` | Architecture decisions | Max |
| `docs/RELEASE-RUNBOOK.md` | Deploy, rollback, incident response | Max plus an assigned backup |

Max can initially hold several engineering roles. Independent clinical review should not be replaced by an engineering self-review.

## Ordered delivery backlog

| ID | Priority | Work | Acceptance criteria | Owner / dependency |
|---|---|---|---|---|
| RM-001 | P0 | Restore live static origin | Actual medical shell, policy and SW served over correct HTTPS URL; strict smoke and clean-device scan pass | Ops; Hostinger/DNS access |
| RM-003 | P0 | Land offline-readiness patch | Automated gates, browser warm-offline test and iOS bundle build pass on candidate | Engineering; review |
| RM-004 | P0 | Clinical-content inventory | Every condition-specific action has reviewer, provenance, version and review date; unresolved instructions block pilot | Max appoints qualified reviewer |
| RM-005 | P0 | Prove physical band path | Blank NTAG216 write, verified read-back and independent iPhone/Android scan demonstrated; QR independently tested | iOS + hardware; capabilities |
| RM-006 | P1 | Apply ops release ledger | Exact migration approved; role/constraint tests and advisor checks pass; no patient columns | Backend; schema approval |
| RM-007 | P1 | Recovery and monitoring | Fixed-path external synthetic monitoring, alert recipient, restore drill and documented response; no scan telemetry | Ops; Hostinger access |
| RM-008 | P1 | Real-browser regression suite | Online, warm offline, cold offline, cache eviction, old worker upgrade, bad payload, no previous-card leak | Engineering |
| RM-009 | P1 | Owner automated tests | XCTest target for profile persistence, codec failures, write/read-back states and erase semantics | iOS engineering |
| RM-010 | P1 | Emergency usability | Representative helpers can find action, urgency and contact in a proposed 10-second task; test large text, screen reader and low light | Product + clinical reviewer |
| RM-011 | P2 | Controlled pilot | Predefined participants/consent, escalation owner, incident stop rules, and explicit launch approval | Max |
| RM-012 | P2 | Scale decisions | Review actual pilot evidence before adding cloud medical profiles, subscriptions or care-team access | Max + engineering + legal |

## Milestones, not calendar promises

### Foundation

Close RM-001 and RM-003 and approve or defer RM-006. Exit evidence: genuine public shell, green candidate tests and documented remaining limits.

### Safe pilot candidate

Close RM-004, RM-005 and the relevant P1 work. Exit evidence: physical-device matrix, clinically reviewed content, recovery drill, accessible scan experience and release sign-off.

### Controlled learning

Run a small, explicitly approved pilot before broad distribution. Gather usability and reliability observations without collecting medical payloads into operational analytics.

## Product contract to refine next

- **What:** prominently show wearer-selected relevant information and reviewed emergency actions.
- **Who:** make the intended helper audience and contact order clear; distinguish emergency services from personal contacts.
- **When:** reviewed escalation language must make urgency clear without requiring a layperson to diagnose a rare condition.
- **Trust:** label wearer-entered information accurately; define freshness and provenance rather than implying verification.
- **Failure:** provide honest empty, malformed, unsupported, offline and outdated-information states. Never silently reuse the previous patient's card.
- **Physical fallback:** decide the minimum information printed on the band for situations where neither NFC nor QR can load.

These are requirements, not new medical instructions. No treatment advice was generated or changed in this pass.

## Metrics and launch evidence

Use synthetic monitoring and consented usability tests, not tracking on the emergency page. Proposed pilot metrics are scan-to-card success, task completion time, decoder failure rate on synthetic fixtures, update/rollback success and physical write/read-back success.

Define device/network cohorts before accepting targets. No current uptime, outcome benefit, diagnostic accuracy or lives-saved metric is claimed.

## Approval and access boundary

Approval is needed for the prepared production database migration and publication of the code patch to the public GitHub repository. Production deployment, DNS changes, firewall changes and secret rotation remain separate from that approval.

## Engineering principle

Fail closed for release approval, but keep the emergency reader independent of operational failures. A reachable host is not a working product, and a completed worker install is not useful unless it actually saved the shell.

The implementation follows the `install`/`waitUntil` lifecycle described by [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API/Using_Service_Workers). The proposed database uses separate grants and RLS as described in [Supabase's API security guidance](https://supabase.com/docs/guides/api/securing-your-api).
