-- In-app account deletion (App Store Review Guideline 5.1.1(v)).
--
-- Contract with owner/RedMed/OwnerSupabaseClient.swift `deleteAccount()`:
--   POST /rest/v1/rpc/delete_my_account   Content-Profile: redmed_owner
--
-- Deletes the caller's own auth.users row. profiles and band_writes go with it
-- through `on delete cascade`. The caller can only ever name itself: the
-- function takes no arguments and reads auth.uid() from the JWT.
--
-- SECURITY DEFINER because `authenticated` has no rights on auth.users. The
-- body is one statement keyed on auth.uid(), search_path is pinned empty, and
-- execute is revoked from public/anon.
--
-- Idempotent: safe to re-run.

create or replace function redmed_owner.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
begin
  if caller is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  delete from auth.users where id = caller;
end;
$$;

revoke all on function redmed_owner.delete_my_account() from public, anon;
grant execute on function redmed_owner.delete_my_account() to authenticated;
