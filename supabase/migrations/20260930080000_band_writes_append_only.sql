-- RM-04: Make redmed_owner.band_writes append-only for application roles.
--
-- Problem: authenticated and anon roles had DELETE on band_writes, allowing
-- an owner to erase their own write history through the REST API. If these
-- rows are used as audit or write-verification evidence, they must be
-- append-only.
--
-- Fix:
--   1. Revoke DELETE from authenticated and anon on the table.
--   2. Add a SECURITY DEFINER function so the account-deletion flow
--      (redmed_owner.delete_account or similar) can still purge rows
--      for a deleted user without touching the table directly.
--
-- What is NOT changed:
--   INSERT   — still permitted via existing RLS (user_id = auth.uid())
--   SELECT   — unchanged
--   UPDATE   — unchanged (sync upsert semantics preserved)
--   profiles — not touched
--   member_bands — not touched
--   Any other table — not touched

-- 1. Revoke direct DELETE from application roles.
REVOKE DELETE ON redmed_owner.band_writes FROM authenticated;
REVOKE DELETE ON redmed_owner.band_writes FROM anon;

-- 2. Privileged erasure path for account deletion only.
--    The invoker must be postgres or service_role (enforced by GRANT).
--    search_path locked to redmed_owner to prevent schema-injection.
CREATE OR REPLACE FUNCTION redmed_owner.purge_band_writes_for_user(
    target_user_id uuid
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = redmed_owner
AS $$
    DELETE FROM redmed_owner.band_writes
    WHERE user_id = target_user_id;
$$;

-- Only postgres and service_role may call this function.
-- authenticated and anon are explicitly excluded.
REVOKE ALL ON FUNCTION redmed_owner.purge_band_writes_for_user(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION redmed_owner.purge_band_writes_for_user(uuid) FROM authenticated;
REVOKE ALL ON FUNCTION redmed_owner.purge_band_writes_for_user(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION redmed_owner.purge_band_writes_for_user(uuid) TO service_role;
