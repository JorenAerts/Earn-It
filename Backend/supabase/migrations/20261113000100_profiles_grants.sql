-- New Supabase projects don't expose new tables to the Data API roles automatically.
-- Signed-in users may read/write their own profile (RLS still limits them to their row);
-- anonymous clients get nothing.
grant usage on schema public to authenticated;
grant select, insert, update on table public.profiles to authenticated;
revoke all on table public.profiles from anon;
