-- Fix: buddies couldn't open each other's morning photos (endless loading on device, 17 Nov 2026).
--
-- The storage read policy checked `exists (select … from public.morning_posts …)`. Storage
-- policies run as the caller, and morning_posts RLS only lets a user read their OWN rows
-- ("morning_posts: own read"), so another member's post was never found and signing the photo
-- URL was always refused. The check now runs in a security-definer function (like the other
-- Buddies RPCs); the rule itself is unchanged: own photos, or posts `can_see_post` allows
-- (same club, not expired, not blocked, unlocked by posting/skipping today).

create or replace function public.can_see_image(path text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.morning_posts p
    where p.image_path = path and public.can_see_post(p.id));
$$;

revoke all on function public.can_see_image(text) from public, anon;
grant execute on function public.can_see_image(text) to authenticated;

drop policy if exists "morning: read visible posts" on storage.objects;
create policy "morning: read visible posts" on storage.objects for select to authenticated
  using (bucket_id = 'morning' and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.can_see_image(name)));
