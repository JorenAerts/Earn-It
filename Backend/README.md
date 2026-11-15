# Backend — Supabase

Accounts are **optional** in Earn It: alarms work fully on-device. The backend handles login
(email + password, Apple, Google, Facebook, Microsoft), the user profile and account deletion.

Hosted project: `ttguwgmjvdrrmnsbavns` (EU). The iOS app reads the URL + **publishable** key
from `Front-end/Config/Supabase.xcconfig` (git-ignored). **Never put a secret key (`sb_secret_…`)
in the app or the repo** — it bypasses all security rules.

## Layout
```
supabase/
  config.toml                         CLI config (local dev, provider placeholders)
  migrations/*_profiles.sql           profiles table + RLS + auto-create on sign-up
  migrations/*_profiles_grants.sql    table access for signed-in users
  migrations/*_delete_own_account.sql delete_own_account() RPC: in-app account deletion (App Review 5.1.1(v))
  migrations/*_buddies.sql            clubs, members, wake reports, morning photos (bucket `morning`),
                                      reactions, blocks, reports + RPCs; delete_own_account hands clubs over
  migrations/*_profile_onboarding.sql profiles.onboarding jsonb (age range, where they heard of us, …)
  functions/cleanup-morning-posts     hourly: deletes photos older than 24 h + files of deleted users
```

## Buddies setup
1. SQL Editor › paste `migrations/20261115000000_buddies.sql` › Run (creates the `morning` storage bucket too).
2. Edge Functions › Deploy a new function › Via Editor › name `cleanup-morning-posts` › paste
   `functions/cleanup-morning-posts/index.ts` › Deploy.
3. Integrations › Cron › enable › Create job › type "Supabase Edge Function" › `cleanup-morning-posts`,
   schedule `0 * * * *` (every hour).
4. Moderation: Table Editor › `reports` (newest first). To remove a photo: delete its `morning_posts` row
   (+ file in Storage › morning). To ban someone: Authentication › Users › delete user.

## One-time setup (hosted project)
1. **Database** — apply the migration, either:
   - Dashboard › SQL Editor › paste each file in `supabase/migrations/` (in name order) › Run, or
   - CLI: `brew install supabase/tap/supabase`, `supabase login`, `supabase link --project-ref ttguwgmjvdrrmnsbavns`, `supabase db push`.
2. **Auth › URL Configuration** — Site URL `earnit://auth-callback`; Redirect URLs: add `earnit://auth-callback` and `earnit://**`.
3. **Auth › Providers › Email** — enabled, "Confirm email" on.
4. **OAuth providers** (Auth › Providers; callback URL for every provider console is
   `https://ttguwgmjvdrrmnsbavns.supabase.co/auth/v1/callback`):
   - **Google** — Google Cloud Console › APIs & Services › Credentials › OAuth client ID (type *Web application*), add the callback URL above, paste client ID + secret in Supabase.
   - **Apple** — needs the paid Apple Developer Program: Services ID + key for Sign in with Apple, paste in Supabase. Until then hide it by removing `"apple"` from `Front-end/Config/Auth.json`.
   - **Facebook** — developers.facebook.com › create app › Facebook Login, valid OAuth redirect = callback URL.
   - **Microsoft** — Azure Portal › App registrations › new (accounts in any org + personal), redirect = callback URL, create a client secret; provider in Supabase is called *Azure*.
5. Which buttons the app shows (and their order) is set in `Front-end/Config/Auth.json`.

## Later
- App Store Server Notifications → edge function → `subscriptions` table (server-side record of Pro, linked through the purchase's `appAccountToken` = user id).
- Push notifications for Buddies (APNs, paid program).
