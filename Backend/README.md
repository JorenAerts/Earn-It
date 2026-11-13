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
  functions/delete-account/index.ts   in-app account deletion (App Review 5.1.1(v))
```

## One-time setup (hosted project)
1. **Database** — apply the migration, either:
   - Dashboard › SQL Editor › paste `supabase/migrations/*_profiles.sql` › Run, or
   - CLI: `brew install supabase/tap/supabase`, `supabase login`, `supabase link --project-ref ttguwgmjvdrrmnsbavns`, `supabase db push`.
2. **Delete-account function** — `supabase functions deploy delete-account` (CLI, after `link`).
3. **Auth › URL Configuration** — Site URL `earnit://auth-callback`; Redirect URLs: add `earnit://auth-callback` and `earnit://**`.
4. **Auth › Providers › Email** — enabled, "Confirm email" on.
5. **OAuth providers** (Auth › Providers; callback URL for every provider console is
   `https://ttguwgmjvdrrmnsbavns.supabase.co/auth/v1/callback`):
   - **Google** — Google Cloud Console › APIs & Services › Credentials › OAuth client ID (type *Web application*), add the callback URL above, paste client ID + secret in Supabase.
   - **Apple** — needs the paid Apple Developer Program: Services ID + key for Sign in with Apple, paste in Supabase. Until then hide it by removing `"apple"` from `Front-end/Config/Auth.json`.
   - **Facebook** — developers.facebook.com › create app › Facebook Login, valid OAuth redirect = callback URL.
   - **Microsoft** — Azure Portal › App registrations › new (accounts in any org + personal), redirect = callback URL, create a client secret; provider in Supabase is called *Azure*.
6. Which buttons the app shows (and their order) is set in `Front-end/Config/Auth.json`.

## Later
- App Store Server Notifications → edge function → `subscriptions` table (server-side record of Pro, linked through the purchase's `appAccountToken` = user id).
- Buddies / challenges / leaderboards.
