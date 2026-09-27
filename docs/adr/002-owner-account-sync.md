# ADR: Wearer account sync, rescuer path stays on the band

Date: 2026-09-26. Status: accepted. Supersedes the “no medical rows” line in [001-emergency-path-and-ops.md](001-emergency-path-and-ops.md) for the signed-in wearer only.

## Context

The Owner app and the Assist shell lived in one git. The wearer asked for a separate iOS git and for profile data to stay consistent across phones by writing it to the existing Supabase project (`mohxobgyjkcmkqxijgeg`). A database lookup on every band tap would make a rescuer depend on login, RLS, and uptime.

## Decision

Two copies, two jobs.

- **Wearer source of truth:** schema `redmed_owner` in that Supabase project. One `profiles` row per `auth.uid()`. `band_writes` stores the time, codec version, sha256, and byte length of a verified pack. It does not store the raw `#d=` string.
- **Rescuer copy:** `https://redmed.live/tapper/#d=…` on a factory-blank NTAG216. [tapper/index.html](../../tapper/index.html) decodes the fragment on the phone. It does not call Supabase. Editing the cloud row does not rewrite a band.
- **Ops ledger:** `redmed_ops` stays release evidence with no patient columns. MCP and the VPS must not read or write `redmed_owner` rows or `#d=` fragments.
- **Repo split:** the Xcode app lives in public `Roooted1776/RedMed-iOS`. This repo keeps Assist, deploy, AASA, and ops. Shared wire format is [contracts/d-codec-fixtures.json](../../contracts/d-codec-fixtures.json). The iOS app pins `Vendor/tapper/index.html` for Preview.

Account sync ships behind `AppConfig.profileSyncEnabled` (default `false`) and only when a publishable key is present. The key is not committed. `service_role` is not in the app. This is not a HIPAA certification.

## Consequences

- A second signed-in iPhone can load the wearer profile. The band updates only on an explicit verified write.
- A Supabase outage leaves an already-written band readable.
- Privacy copy in Document must describe the Supabase wearer copy, the public fragment, and that the tap page does not look the profile up, before the flag is turned on.
