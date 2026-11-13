-- Profiles: one row per auth user, readable/writable only by that user.
create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  wake_goal    jsonb,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles: read own"   on public.profiles for select using ((select auth.uid()) = id);
create policy "profiles: insert own" on public.profiles for insert with check ((select auth.uid()) = id);
create policy "profiles: update own" on public.profiles for update using ((select auth.uid()) = id)
                                                                with check ((select auth.uid()) = id);

-- Keep updated_at fresh.
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

-- Create the profile row automatically on sign-up.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();
