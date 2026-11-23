-- Feedback board: signed-in users post ideas (with a category) and up/downvote them.
-- Shown on the web page `Web/feedback/` (GitHub Pages), opened from the app via
-- Settings › Help & feedback › Suggest a feature. Authors stay anonymous to other users.
-- Everything goes through security-definer RPCs; the tables have no direct grants.

-- ---------------------------------------------------------------------------------------------
-- Tables

create table public.feedback_posts (
  id          uuid primary key default gen_random_uuid(),
  author_id   uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title       text not null check (char_length(btrim(title)) between 3 and 80),
  body        text not null default '' check (char_length(body) <= 1000),
  category    text not null default 'feature'
              check (category in ('feature', 'bug', 'mission', 'sound', 'other')),
  -- Set by moderation (dashboard) or automatically after 3 reports.
  hidden      boolean not null default false,
  created_at  timestamptz not null default now()
);
create index feedback_posts_author_idx on public.feedback_posts (author_id, created_at desc);
create index feedback_posts_created_idx on public.feedback_posts (created_at desc);

create table public.feedback_votes (
  post_id     uuid not null references public.feedback_posts (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  value       smallint not null check (value in (-1, 1)),
  created_at  timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index feedback_votes_user_idx on public.feedback_votes (user_id);

alter table public.feedback_posts enable row level security;
alter table public.feedback_votes enable row level security;
revoke all on public.feedback_posts, public.feedback_votes from anon, authenticated;

-- Reports (Buddies table) also cover feedback posts.
alter table public.reports drop constraint if exists reports_kind_check;
alter table public.reports add constraint reports_kind_check
  check (kind in ('post', 'club', 'user', 'feedback'));

-- ---------------------------------------------------------------------------------------------
-- RPCs

-- sort: 'top' (score, then newest) or 'new'. cat (category) / search optional.
create or replace function public.feedback_list(
  sort text default 'top', cat text default null, search text default null,
  lim int default 50, off int default 0
) returns table (
  id uuid, title text, body text, category text, created_at timestamptz,
  up int, down int, score int, my_vote int, is_mine boolean
) language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := public.require_user();
  pattern text := nullif(btrim(coalesce(search, '')), '');
begin
  if pattern is not null then
    pattern := '%' || replace(replace(replace(pattern, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  end if;
  return query
  with tallies as (
    select p.id, p.title, p.body, p.category, p.created_at, p.author_id,
           coalesce(sum(case when v.value = 1 then 1 else 0 end), 0)::int as up,
           coalesce(sum(case when v.value = -1 then 1 else 0 end), 0)::int as down
    from public.feedback_posts p
    left join public.feedback_votes v on v.post_id = p.id
    where not p.hidden
      and (cat is null or p.category = cat)
      and (pattern is null or p.title ilike pattern or p.body ilike pattern)
      and (p.author_id = uid or not public.is_blocked(p.author_id))
    group by p.id
  )
  select t.id, t.title, t.body, t.category, t.created_at, t.up, t.down, (t.up - t.down)::int,
         coalesce((select v.value from public.feedback_votes v
                   where v.post_id = t.id and v.user_id = uid), 0)::int,
         t.author_id = uid
  from tallies t
  order by case when sort = 'new' then 0 else t.up - t.down end desc, t.created_at desc
  limit least(greatest(lim, 1), 100) offset greatest(off, 0);
end $$;

-- Returns the new post id. The author's own upvote is added straight away.
create or replace function public.feedback_submit(title text, body text, category text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public.require_user();
  t text := btrim(coalesce(title, ''));
  b text := btrim(coalesce(body, ''));
  new_id uuid;
begin
  if char_length(t) < 3 then
    raise exception 'Give your idea a title of at least 3 characters.' using errcode = 'P0001';
  end if;
  if char_length(t) > 80 or char_length(b) > 1000 then
    raise exception 'That''s a bit long — keep the title under 80 and the description under 1000 characters.'
      using errcode = 'P0001';
  end if;
  if category not in ('feature', 'bug', 'mission', 'sound', 'other') then
    raise exception 'Pick a category.' using errcode = 'P0001';
  end if;
  if (select count(*) from public.feedback_posts p
      where p.author_id = uid and p.created_at > now() - interval '24 hours') >= 5 then
    raise exception 'You''ve posted a lot today — try again tomorrow.' using errcode = 'P0001';
  end if;
  insert into public.feedback_posts (author_id, title, body, category)
  values (uid, t, b, category) returning id into new_id;
  insert into public.feedback_votes (post_id, user_id, value) values (new_id, uid, 1);
  return new_id;
end $$;

-- value: 1 = up, -1 = down, 0 = remove my vote.
create or replace function public.feedback_vote(post uuid, value int)
returns void language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public.require_user();
begin
  if value not in (-1, 0, 1) then
    raise exception 'Invalid vote.' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.feedback_posts p where p.id = post and not p.hidden) then
    raise exception 'This idea isn''t available any more.' using errcode = 'P0001';
  end if;
  if value = 0 then
    delete from public.feedback_votes v where v.post_id = post and v.user_id = uid;
  else
    insert into public.feedback_votes (post_id, user_id, value) values (post, uid, value)
    on conflict (post_id, user_id) do update set value = excluded.value, created_at = now();
  end if;
end $$;

create or replace function public.feedback_delete_own(post uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public.require_user();
begin
  delete from public.feedback_posts p where p.id = post and p.author_id = uid;
end $$;

-- Reviewed in the dashboard (reports, kind 'feedback'). 3 different reporters hide the post;
-- unhide with feedback_posts.hidden = false.
create or replace function public.feedback_report(post uuid, reason text default '')
returns void language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public.require_user();
begin
  if not exists (select 1 from public.feedback_posts p where p.id = post) then
    return;
  end if;
  if not exists (select 1 from public.reports r
                 where r.kind = 'feedback' and r.target_id = post and r.reporter_id = uid) then
    insert into public.reports (reporter_id, kind, target_id, reason)
    values (uid, 'feedback', post, left(coalesce(reason, ''), 500));
  end if;
  if (select count(distinct r.reporter_id) from public.reports r
      where r.kind = 'feedback' and r.target_id = post) >= 3 then
    update public.feedback_posts p set hidden = true where p.id = post;
  end if;
end $$;

-- RPCs callable by signed-in users only.
revoke all on function public.feedback_list(text, text, text, int, int),
  public.feedback_submit(text, text, text), public.feedback_vote(uuid, int),
  public.feedback_delete_own(uuid), public.feedback_report(uuid, text)
  from public, anon;
grant execute on function public.feedback_list(text, text, text, int, int),
  public.feedback_submit(text, text, text), public.feedback_vote(uuid, int),
  public.feedback_delete_own(uuid), public.feedback_report(uuid, text)
  to authenticated;
