-- Buddies: clubs, wake-up reports, weekly leaderboard, 24 h morning photos, reactions,
-- reports and blocks. Everything social goes through security-definer RPCs that check
-- membership; tables are only directly readable/writable for the caller's own rows.

-- ---------------------------------------------------------------------------------------------
-- Profiles: opt-out of showing the wake-up time to clubs.
alter table public.profiles add column if not exists share_wake_time boolean not null default true;

-- ---------------------------------------------------------------------------------------------
-- Tables

create table public.clubs (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (char_length(btrim(name)) between 2 and 40),
  description  text not null default '' check (char_length(description) <= 200),
  emoji        text not null default '⏰' check (char_length(emoji) between 1 and 8),
  is_public    boolean not null default false,
  invite_code  text not null unique,
  owner_id     uuid not null references auth.users (id) on delete cascade,
  created_at   timestamptz not null default now()
);

create table public.club_members (
  club_id    uuid not null references public.clubs (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  role       text not null default 'member' check (role in ('owner', 'member')),
  joined_at  timestamptz not null default now(),
  primary key (club_id, user_id)
);
create index club_members_user_idx on public.club_members (user_id);

-- One row per user per (local) day with a finished mission.
create table public.wake_reports (
  user_id       uuid not null references auth.users (id) on delete cascade,
  day           date not null,
  completed_at  timestamptz,
  alarm_time    text,
  rings         int not null default 0 check (rings >= 0),
  xp            int not null default 0 check (xp between 0 and 1000),
  streak        int not null default 0 check (streak >= 0),
  rank          text,
  photo_state   text not null default 'none' check (photo_state in ('none', 'posted', 'skipped')),
  updated_at    timestamptz not null default now(),
  primary key (user_id, day)
);

create table public.morning_posts (
  id          uuid primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  day         date not null,
  image_path  text not null,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '24 hours'
);
create index morning_posts_expiry_idx on public.morning_posts (expires_at);

create table public.morning_post_clubs (
  post_id  uuid not null references public.morning_posts (id) on delete cascade,
  club_id  uuid not null references public.clubs (id) on delete cascade,
  primary key (post_id, club_id)
);
create index morning_post_clubs_club_idx on public.morning_post_clubs (club_id);

create table public.post_reactions (
  post_id     uuid not null references public.morning_posts (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  emoji       text not null check (emoji in ('🔥', '💪', '😴', '⏰', '👏')),
  created_at  timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table public.blocks (
  blocker_id  uuid not null references auth.users (id) on delete cascade,
  blocked_id  uuid not null references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

-- Reviewed in the dashboard (Table Editor › reports). Nobody can read them from the app.
create table public.reports (
  id           uuid primary key default gen_random_uuid(),
  reporter_id  uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind         text not null check (kind in ('post', 'club', 'user')),
  target_id    uuid not null,
  reason       text not null default '' check (char_length(reason) <= 500),
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------------------------
-- Helpers (security definer so RLS policies can use them without recursion)

create or replace function public.is_club_member(club uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.club_members m where m.club_id = club and m.user_id = auth.uid());
$$;

create or replace function public.is_club_owner(club uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.club_members m
                 where m.club_id = club and m.user_id = auth.uid() and m.role = 'owner');
$$;

-- Either user blocked the other.
create or replace function public.is_blocked(other uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.blocks b
                 where (b.blocker_id = auth.uid() and b.blocked_id = other)
                    or (b.blocker_id = other and b.blocked_id = auth.uid()));
$$;

-- 8 characters without look-alikes (no 0/O, 1/I/L).
create or replace function public.gen_invite_code() returns text
language plpgsql volatile set search_path = '' as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  code text;
begin
  loop
    code := '';
    for i in 1..8 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.clubs c where c.invite_code = code);
  end loop;
  return code;
end $$;

create or replace function public.require_user() returns uuid
language plpgsql stable set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  return auth.uid();
end $$;

-- ---------------------------------------------------------------------------------------------
-- Row level security

alter table public.clubs              enable row level security;
alter table public.club_members       enable row level security;
alter table public.wake_reports       enable row level security;
alter table public.morning_posts      enable row level security;
alter table public.morning_post_clubs enable row level security;
alter table public.post_reactions     enable row level security;
alter table public.blocks             enable row level security;
alter table public.reports            enable row level security;

create policy "clubs: members or public" on public.clubs for select
  using (is_public or public.is_club_member(id));
create policy "clubs: owner updates" on public.clubs for update
  using (public.is_club_owner(id)) with check (public.is_club_owner(id));
create policy "clubs: owner deletes" on public.clubs for delete
  using (public.is_club_owner(id));

create policy "club_members: fellow members" on public.club_members for select
  using (public.is_club_member(club_id));

create policy "wake_reports: own" on public.wake_reports for all
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "morning_posts: own read" on public.morning_posts for select
  using ((select auth.uid()) = user_id);
create policy "morning_posts: own delete" on public.morning_posts for delete
  using ((select auth.uid()) = user_id);

create policy "morning_post_clubs: own" on public.morning_post_clubs for select
  using (exists (select 1 from public.morning_posts p where p.id = post_id and p.user_id = (select auth.uid())));

create policy "post_reactions: own" on public.post_reactions for select
  using ((select auth.uid()) = user_id);

create policy "blocks: own" on public.blocks for all
  using ((select auth.uid()) = blocker_id) with check ((select auth.uid()) = blocker_id);

create policy "reports: insert own" on public.reports for insert
  with check ((select auth.uid()) = reporter_id);

grant select, delete on public.clubs to authenticated;
grant update (name, description, emoji, is_public) on public.clubs to authenticated;
grant select on public.club_members to authenticated;
grant select, insert, update on public.wake_reports to authenticated;
grant select, delete on public.morning_posts to authenticated;
grant select on public.morning_post_clubs to authenticated;
grant select on public.post_reactions to authenticated;
grant select, insert, delete on public.blocks to authenticated;
grant insert on public.reports to authenticated;
revoke all on public.clubs, public.club_members, public.wake_reports, public.morning_posts,
              public.morning_post_clubs, public.post_reactions, public.blocks, public.reports from anon;

-- ---------------------------------------------------------------------------------------------
-- Clubs

create or replace function public.create_club(p_name text, p_description text, p_emoji text, p_is_public boolean)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public.require_user();
  new_id uuid;
begin
  if (select count(*) from public.clubs c where c.owner_id = uid) >= 10 then
    raise exception 'You can own up to 10 clubs.' using errcode = 'P0001';
  end if;
  insert into public.clubs (name, description, emoji, is_public, invite_code, owner_id)
  values (btrim(p_name), coalesce(btrim(p_description), ''), coalesce(nullif(btrim(p_emoji), ''), '⏰'),
          p_is_public, public.gen_invite_code(), uid)
  returning id into new_id;
  insert into public.club_members (club_id, user_id, role) values (new_id, uid, 'owner');
  return new_id;
end $$;

create or replace function public.join_club_by_id(club uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public.require_user();
begin
  if exists (select 1 from public.club_members m where m.club_id = club and m.user_id = uid) then
    return;
  end if;
  if (select count(*) from public.club_members m where m.club_id = club) >= 100 then
    raise exception 'This club is full (100 members).' using errcode = 'P0001';
  end if;
  insert into public.club_members (club_id, user_id, role) values (club, uid, 'member');
end $$;
revoke all on function public.join_club_by_id(uuid) from public, anon, authenticated;

create or replace function public.join_club(code text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  club uuid;
begin
  perform public.require_user();
  select c.id into club from public.clubs c where c.invite_code = upper(replace(btrim(code), '-', ''));
  if club is null then
    raise exception 'No club found with this code.' using errcode = 'P0001';
  end if;
  perform public.join_club_by_id(club);
  return club;
end $$;

create or replace function public.join_public_club(club uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_user();
  if not exists (select 1 from public.clubs c where c.id = club and c.is_public) then
    raise exception 'This club is private. Ask a member for the invite code.' using errcode = 'P0001';
  end if;
  perform public.join_club_by_id(club);
end $$;

-- Leaving as owner hands the club to the longest-standing member, or deletes an empty club.
create or replace function public.leave_club_for(club uuid, uid uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  was_owner boolean;
  heir uuid;
begin
  delete from public.club_members m where m.club_id = club and m.user_id = uid
  returning m.role = 'owner' into was_owner;
  if coalesce(was_owner, false) then
    select m.user_id into heir from public.club_members m where m.club_id = club
    order by m.joined_at limit 1;
    if heir is null then
      delete from public.clubs c where c.id = club;
    else
      update public.club_members m set role = 'owner' where m.club_id = club and m.user_id = heir;
      update public.clubs c set owner_id = heir where c.id = club;
    end if;
  end if;
end $$;
revoke all on function public.leave_club_for(uuid, uuid) from public, anon, authenticated;

create or replace function public.leave_club(club uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.leave_club_for(club, public.require_user());
end $$;

create or replace function public.remove_member(club uuid, member uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_user();
  if not public.is_club_owner(club) then
    raise exception 'Only the club owner can remove members.' using errcode = '42501';
  end if;
  if member = auth.uid() then
    raise exception 'Use Leave club instead.' using errcode = 'P0001';
  end if;
  delete from public.club_members m where m.club_id = club and m.user_id = member;
end $$;

create or replace function public.regenerate_invite(club uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare
  code text := public.gen_invite_code();
begin
  perform public.require_user();
  if not public.is_club_owner(club) then
    raise exception 'Only the club owner can change the code.' using errcode = '42501';
  end if;
  update public.clubs c set invite_code = code where c.id = club;
  return code;
end $$;

-- The caller's clubs with member count and how many are up today.
create or replace function public.my_clubs(today date)
returns table (id uuid, name text, description text, emoji text, is_public boolean, invite_code text,
               role text, member_count int, up_today int, owner_id uuid)
language sql stable security definer set search_path = '' as $$
  select c.id, c.name, c.description, c.emoji, c.is_public, c.invite_code, me.role,
         (select count(*)::int from public.club_members m where m.club_id = c.id),
         (select count(*)::int from public.club_members m
            join public.wake_reports w on w.user_id = m.user_id and w.day = today
           where m.club_id = c.id and w.completed_at is not null),
         c.owner_id
  from public.clubs c
  join public.club_members me on me.club_id = c.id and me.user_id = auth.uid()
  order by me.joined_at;
$$;

create or replace function public.search_public_clubs(query text)
returns table (id uuid, name text, description text, emoji text, member_count int, is_member boolean)
language sql stable security definer set search_path = '' as $$
  select c.id, c.name, c.description, c.emoji,
         (select count(*)::int from public.club_members m where m.club_id = c.id) as member_count,
         public.is_club_member(c.id)
  from public.clubs c
  where c.is_public
    and (coalesce(btrim(query), '') = '' or c.name ilike '%' || btrim(query) || '%')
    and auth.uid() is not null
  order by member_count desc, c.created_at desc
  limit 30;
$$;

-- ---------------------------------------------------------------------------------------------
-- Today, leaderboard

create or replace function public.club_today(club uuid, today date)
returns table (user_id uuid, display_name text, role text, completed_at timestamptz, shares_time boolean,
               rings int, streak int, rank text, photo_state text, is_me boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_club_member(club) then
    raise exception 'Not a member of this club.' using errcode = '42501';
  end if;
  return query
  select m.user_id, p.display_name, m.role,
         case when p.share_wake_time or m.user_id = auth.uid() then w.completed_at
              when w.completed_at is not null then date_trunc('day', w.completed_at) end,
         coalesce(p.share_wake_time, true) or m.user_id = auth.uid(),
         w.rings, coalesce(w.streak, 0), w.rank, coalesce(w.photo_state, 'none'),
         m.user_id = auth.uid()
  from public.club_members m
  left join public.profiles p on p.id = m.user_id
  left join public.wake_reports w on w.user_id = m.user_id and w.day = today
  where m.club_id = club and not public.is_blocked(m.user_id);
end $$;

create or replace function public.club_leaderboard(club uuid, week_start date)
returns table (user_id uuid, display_name text, week_xp int, total_xp int, streak int, rank text, is_me boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_club_member(club) then
    raise exception 'Not a member of this club.' using errcode = '42501';
  end if;
  return query
  select m.user_id, p.display_name,
         coalesce((select sum(w.xp) from public.wake_reports w
                   where w.user_id = m.user_id and w.day >= week_start and w.day < week_start + 7), 0)::int,
         coalesce((select sum(w.xp) from public.wake_reports w where w.user_id = m.user_id), 0)::int,
         coalesce((select w.streak from public.wake_reports w where w.user_id = m.user_id
                   order by w.day desc limit 1), 0),
         (select w.rank from public.wake_reports w where w.user_id = m.user_id order by w.day desc limit 1),
         m.user_id = auth.uid()
  from public.club_members m
  left join public.profiles p on p.id = m.user_id
  where m.club_id = club and not public.is_blocked(m.user_id);
end $$;

-- ---------------------------------------------------------------------------------------------
-- Morning photos

-- The caller posted or skipped today: others' photos unlock (BeReal rule).
create or replace function public.has_unlocked(today date) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.wake_reports w
                 where w.user_id = auth.uid() and w.day = today and w.photo_state in ('posted', 'skipped'));
$$;

create or replace function public.create_morning_post(post_id uuid, today date, path text, clubs uuid[])
returns void language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public.require_user();
  club uuid;
begin
  if path not like uid::text || '/%' then
    raise exception 'Invalid photo path.' using errcode = '42501';
  end if;
  if coalesce(array_length(clubs, 1), 0) = 0 then
    raise exception 'Pick at least one club.' using errcode = 'P0001';
  end if;
  insert into public.morning_posts (id, user_id, day, image_path) values (post_id, uid, today, path);
  foreach club in array clubs loop
    if public.is_club_member(club) then
      insert into public.morning_post_clubs (post_id, club_id) values (post_id, club) on conflict do nothing;
    end if;
  end loop;
  insert into public.wake_reports (user_id, day, photo_state) values (uid, today, 'posted')
  on conflict (user_id, day) do update set photo_state = 'posted', updated_at = now();
end $$;

create or replace function public.skip_morning_post(today date) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public.require_user();
begin
  insert into public.wake_reports (user_id, day, photo_state) values (uid, today, 'skipped')
  on conflict (user_id, day) do update
    set photo_state = case when public.wake_reports.photo_state = 'posted' then 'posted' else 'skipped' end,
        updated_at = now();
end $$;

-- Today's photos in a club. Locked (no path) until the caller posted or skipped.
create or replace function public.club_feed(club uuid, today date)
returns table (id uuid, user_id uuid, display_name text, image_path text, created_at timestamptz,
               locked boolean, reactions jsonb, my_reaction text, is_me boolean)
language plpgsql stable security definer set search_path = '' as $$
declare
  unlocked boolean := public.has_unlocked(today);
begin
  if not public.is_club_member(club) then
    raise exception 'Not a member of this club.' using errcode = '42501';
  end if;
  return query
  select p.id, p.user_id, pr.display_name,
         case when unlocked or p.user_id = auth.uid() then p.image_path end,
         p.created_at,
         not (unlocked or p.user_id = auth.uid()),
         coalesce((select jsonb_object_agg(r.emoji, r.n) from
                     (select x.emoji, count(*) as n from public.post_reactions x
                       where x.post_id = p.id group by x.emoji) r), '{}'::jsonb),
         (select x.emoji from public.post_reactions x where x.post_id = p.id and x.user_id = auth.uid()),
         p.user_id = auth.uid()
  from public.morning_posts p
  join public.morning_post_clubs pc on pc.post_id = p.id and pc.club_id = club
  left join public.profiles pr on pr.id = p.user_id
  where p.expires_at > now() and p.day = today and not public.is_blocked(p.user_id)
  order by p.created_at;
end $$;

-- Can the caller see this post? (shared to one of their clubs, not expired, not blocked, unlocked)
create or replace function public.can_see_post(post uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.morning_posts p
    join public.morning_post_clubs pc on pc.post_id = p.id
    where p.id = post and p.expires_at > now()
      and public.is_club_member(pc.club_id)
      and not public.is_blocked(p.user_id)
      and (p.user_id = auth.uid() or public.has_unlocked(p.day)));
$$;

create or replace function public.react_to_post(post uuid, emoji text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public.require_user();
begin
  if not public.can_see_post(post) then
    raise exception 'This photo is no longer available.' using errcode = 'P0001';
  end if;
  if emoji is null then
    delete from public.post_reactions r where r.post_id = post and r.user_id = uid;
  else
    insert into public.post_reactions (post_id, user_id, emoji) values (post, uid, emoji)
    on conflict (post_id, user_id) do update set emoji = excluded.emoji, created_at = now();
  end if;
end $$;

create or replace function public.blocked_users()
returns table (user_id uuid, display_name text, blocked_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select b.blocked_id, p.display_name, b.created_at
  from public.blocks b left join public.profiles p on p.id = b.blocked_id
  where b.blocker_id = auth.uid()
  order by b.created_at desc;
$$;

-- RPCs callable by signed-in users only.
revoke all on function public.create_club(text, text, text, boolean), public.join_club(text),
  public.join_public_club(uuid), public.leave_club(uuid), public.remove_member(uuid, uuid),
  public.regenerate_invite(uuid), public.my_clubs(date), public.search_public_clubs(text),
  public.club_today(uuid, date), public.club_leaderboard(uuid, date),
  public.create_morning_post(uuid, date, text, uuid[]), public.skip_morning_post(date),
  public.club_feed(uuid, date), public.react_to_post(uuid, text), public.blocked_users()
  from public, anon;
grant execute on function public.create_club(text, text, text, boolean), public.join_club(text),
  public.join_public_club(uuid), public.leave_club(uuid), public.remove_member(uuid, uuid),
  public.regenerate_invite(uuid), public.my_clubs(date), public.search_public_clubs(text),
  public.club_today(uuid, date), public.club_leaderboard(uuid, date),
  public.create_morning_post(uuid, date, text, uuid[]), public.skip_morning_post(date),
  public.club_feed(uuid, date), public.react_to_post(uuid, text), public.blocked_users()
  to authenticated;

-- ---------------------------------------------------------------------------------------------
-- Storage: private bucket `morning`, files at <user_id>/<post_id>.jpg

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('morning', 'morning', false, 1048576, array['image/jpeg'])
on conflict (id) do nothing;

create policy "morning: upload own folder" on storage.objects for insert to authenticated
  with check (bucket_id = 'morning' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "morning: delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'morning' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "morning: read visible posts" on storage.objects for select to authenticated
  using (bucket_id = 'morning' and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or exists (select 1 from public.morning_posts p where p.image_path = name and public.can_see_post(p.id))));

-- ---------------------------------------------------------------------------------------------
-- Account deletion: hand owned clubs over (or delete them) before the user row goes.

create or replace function public.delete_own_account()
returns void language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  club uuid;
begin
  if uid is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  for club in select m.club_id from public.club_members m where m.user_id = uid and m.role = 'owner' loop
    perform public.leave_club_for(club, uid);
  end loop;
  delete from auth.users where id = uid;
end;
$$;
revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;
