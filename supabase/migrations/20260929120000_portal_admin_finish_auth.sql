-- portal_admin_finish used to update any open admin event by UUID.
-- The event's actor must still be a confirmed, non-banned admin, matching
-- portal_admin_begin. Execute stays service_role only.

create or replace function redmed_private.portal_admin_finish(
  p_event uuid,
  p_outcome text,
  p_target uuid default null::uuid
)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  actor uuid;
begin
  if p_outcome is null
    or char_length(btrim(p_outcome)) = 0
    or char_length(p_outcome) > 200
    or p_outcome = 'requested' then
    raise exception 'Invalid outcome' using errcode = '22023';
  end if;

  select e.actor_id into actor
  from redmed_private.admin_events e
  where e.id = p_event and e.outcome = 'requested';

  if actor is null then
    raise exception 'Admin event not open' using errcode = 'P0002';
  end if;

  if not exists (
    select 1
    from redmed_private.admin_members a
    join auth.users u on u.id = a.user_id
    where a.user_id = actor
      and u.email_confirmed_at is not null
      and (u.banned_until is null or u.banned_until <= now())
  ) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  if p_target is not null and (
    p_target = actor
    or exists (select 1 from redmed_private.admin_members where user_id = p_target)
  ) then
    raise exception 'Administrator accounts are protected';
  end if;

  update redmed_private.admin_events
  set outcome = p_outcome,
      target_id = coalesce(p_target, target_id)
  where id = p_event and outcome = 'requested';
end;
$function$;

revoke all on function redmed_private.portal_admin_finish(uuid, text, uuid) from public, anon, authenticated;
grant execute on function redmed_private.portal_admin_finish(uuid, text, uuid) to service_role;

revoke all on function public.portal_admin_finish(uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.portal_admin_finish(uuid, text, uuid) to service_role;
