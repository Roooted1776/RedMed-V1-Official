-- Advisor 0011: pin search_path on the wearer updated_at trigger.
alter function redmed_owner.touch_updated_at() set search_path = pg_catalog;
