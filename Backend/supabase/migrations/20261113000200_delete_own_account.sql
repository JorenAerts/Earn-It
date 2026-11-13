-- In-app account deletion (App Store Review Guideline 5.1.1(v)).
-- A signed-in user can delete ONLY their own account: the function deletes the row of
-- auth.uid() (the caller's JWT). Their profile goes with it (on delete cascade).
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;
