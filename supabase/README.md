# RedMed operations database

`redmed_ops` is a release-evidence ledger. It has no patient columns. Assist does not read it. The signed-in wearer copy is a different schema, `redmed_owner` (`docs/adr/002-owner-account-sync.md`). The public tap page does not query either schema. Nothing here is written or read by an MCP.

## Contract

- `redmed_ops.release_candidates`: component and Git commit identity.
- `redmed_ops.gate_runs`: append-only pass/fail/blocked evidence, keyed to a candidate.
- No free-form notes, URLs, JSON payloads, IP addresses, contact details or patient identifiers.
- The schema stays outside the Data API exposed schemas. Neither anonymous nor signed-in app users receive access.
- `service_role` receives SELECT and INSERT only on these tables. It bypasses RLS, so its credential remains server-side.
- No runtime writer is deployed by this migration. Use an authenticated ops connection; do not expose the schema just to make browser access easier.
- Passing one gate never automatically approves a release. Repeated results are preserved; launch decisions require all applicable gates and human sign-off.

The grants and RLS design follows [Supabase's API security guidance](https://supabase.com/docs/guides/api/securing-your-api). The role bypass limitation is documented in [Supabase's RLS guide](https://supabase.com/docs/guides/database/postgres/row-level-security).

`config.toml` is what the Supabase GitHub integration opens. The Data API schemas in that file stay `public` and `graphql_public`. `redmed_owner` and `redmed_ops` are not exposed there.

## Apply and verify

Apply the versioned SQL through the Supabase migration tool, not an ad hoc application startup hook. Then run `tests/release-ledger.sql` with the same administrative test connection; fixture writes roll back.

After applying, inspect the schema's grants and run the security advisor. A clean advisor result is not a compliance certification or proof that the whole application is secure.

## Owner schema (`redmed_owner`)

`20260926193000` / `20260926194500` created the live wearer schema. `20260927120000` adds `delete_my_account()` (the Owner app's in-app account deletion RPC) and `20260927120100` brings the tables to the app contract: own-row `*_own` policies, no anon schema or table access, append-only `band_writes` (no UPDATE; delete stays for Erase All User Data), and a server-stamped `updated_at` on insert and update. Both are idempotent.

- `scripts/test-cloud-sync.mjs` checks the contract statically (CI).
- `scripts/test-supabase-rls.sh` applies the owner migrations to a throwaway local Postgres and runs `tests/redmed_owner_rls.sql`. Never point it at a Supabase project.
- `tests/owner-profiles.sql` checks grants and isolation with an administrative connection after the migrations are applied; fixtures roll back.

Applying these to the live project needs the owner's explicit approval.

## Lifecycle

Keep release evidence through the pilot. Before automated monitoring begins, define retention, a dedicated writer role, and a tested backup/restore procedure; do not give a long-lived VPS process a project-wide admin connection.

For rollback, first stop any future writer and export required non-medical evidence. Removal of the schema is destructive and requires explicit approval; no automatic down migration is supplied.
