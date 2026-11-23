# Launch to-do

Open tasks before Earn It can go to TestFlight / the App Store. Tick them off as you go.

---

## 1. Terms of Use & Privacy Policy

Apple requires both links for apps with subscriptions (paywall + App Store listing). They're
currently placeholders (`https://example.com/...`).

- [ ] Write a **Privacy Policy** — what's collected: email + profile (Supabase, EU), purchases
      (Apple), on-device alarms; no tracking/ads. Mention account deletion in the app.
- [ ] Write **Terms of Use** — or use Apple's standard EULA:
      `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`
- [x] Shown in the app itself (Settings › About, paywall, sign-up, onboarding); no website links in the app.
- [ ] App Store Connect still requires a **Privacy Policy URL** field (Apple rule, can't be skipped).
      → [x] Public Gist (same text as `docs/legal/privacy.md`): https://gist.github.com/JorenAerts/3460dc0a39ace79cf4ab6e54f2b76a01
- [ ] Add both links in App Store Connect (App Information › Privacy Policy URL; Terms link in
      the app description or as custom EULA).

- [ ] Terms of Use: users may only use audio they have the rights to as alarm sounds; own sounds stay on their device (personal use, never shared through the app).

## 2. Own email sender for Supabase (removes "email rate limit exceeded")

Supabase's built-in mailer only sends a few emails per hour — fine for testing, not for users.

- [ ] Create an account at an email provider (e.g. **Resend**, Postmark or Brevo — all have a free tier).
- [ ] Verify a sending domain (e.g. `gloop.app`) — add the DNS records they give you (SPF, DKIM).
- [ ] Supabase › Project Settings › Authentication › **SMTP Settings** → enable custom SMTP,
      fill in host, port, username, password, sender `no-reply@<your-domain>`, sender name "Earn It".
- [ ] Supabase › Authentication › **Rate Limits** → raise the email limit (e.g. 100/hour).
- [ ] Supabase › Authentication › Sign In / Providers › Email → turn **Confirm email** back on
      (if it was switched off for testing).
- [ ] Optional: customise the email templates (Authentication › Email Templates) with Earn It branding.
- [ ] Test: create an account with a fresh email → confirmation mail arrives → link opens the app.

## 3. App Store Connect & real subscriptions

Needed for TestFlight, real purchases, "Manage subscription" and native Sign in with Apple.

### Account & agreements
- [ ] Enrol in the **Apple Developer Program** (€99/year).
- [x] Paid team = same Team ID `8QP9V26LXL` (now Individual, not free); App Group on (`GLOOP_DEVICE_APP_GROUPS = YES`).
- [x] Register App Group `group.be.gloop.app` (Xcode › Signing & Capabilities does it automatically) and add `GLOOP_DEVICE_APP_GROUPS = YES` to `Local.xcconfig` so the home-screen widgets get live data on device.
- [ ] App Store Connect › Business: accept the **Paid Applications Agreement**, add bank + tax info.

### App & products
- [ ] Create the app record — bundle ID `be.gloop.app`.
- [ ] Create subscription group **"Earn It Pro"** with the subscriptions from
      `Shared/Config/Pricing.json` — **same product IDs**:
  - [ ] `be.gloop.app.pro.weekly` (1 week)
  - [ ] `be.gloop.app.pro.monthly` (1 month)
  - [ ] `be.gloop.app.pro.quarterly` (3 months)
  - [ ] `be.gloop.app.pro.yearly` (1 year)
  - [ ] For each: price, display name, description, review screenshot, and an
        **introductory offer: free trial, 3 days**.
- [ ] Create `be.gloop.app.pro.lifetime` as a **non-consumable** in-app purchase.
- [ ] Keep `Pricing.json` prices in sync with App Store Connect (then run
      `python3 iOS/scripts/generate_storekit.py`).

### Testing
- [ ] Users and Access › Sandbox → create a **sandbox tester**.
- [ ] Upload a build to **TestFlight**, install it, buy a plan with the sandbox account.
- [ ] Check: trial starts → **Manage subscription** opens Apple's sheet → cancel → after expiry
      the app drops to Free and the downgrade notice appears (sandbox renewals take minutes).
- [ ] Check **Restore purchases** on a second device / after reinstall.

### Apple Music (needs the paid program)
- [ ] Developer portal › Identifiers › `be.gloop.app` › App Services: enable **MusicKit**.
- [ ] Test search + playback with an Apple Music subscription.

### Sign in with Apple (needs the paid program)
- [ ] Enable the Sign in with Apple capability for `be.gloop.app`.
- [ ] Create a Services ID + Sign in with Apple key, paste them in Supabase › Providers › **Apple**.
- [ ] Keep `"apple"` in `Shared/Config/Auth.json` → `providers`.

### Settings › Help & feedback
- [ ] Set `supportEmail` in `Shared/Config/Auth.json` (the Contact support row stays hidden while empty).
- [ ] Add `"shareURL"` to `Shared/Config/Auth.json` once there's a website or App Store page
      (`https://apps.apple.com/app/id<APP_ID>`). Until then there is no link: Settings › Share Earn It and
      Help › Share are hidden, and the onboarding invite sends the message without a link.
- [ ] Add your Supabase user UUID to `Shared/Config/Developer.json` so the 7-tap developer tools
      unlock on TestFlight builds (copy it in Settings › Developer tools › Info).

### Buddies
- [ ] Apply `Backend/supabase/migrations/20261115000000_buddies.sql` (SQL Editor) — see Backend/README.md.
- [ ] Deploy Edge Function `cleanup-morning-posts` and schedule it hourly (Integrations › Cron).
- [ ] Check reports daily (Table Editor › `reports`); App Review expects action within 24 h (Guideline 1.2).
- [ ] Privacy policy + App Privacy labels: photos, wake-up times, display name shared with club members.
- [ ] Age rating: user-generated content → answer "yes" for UGC (12+ likely).
- [ ] Universal links (`https://…/join/<code>`) once there's a website, so invites open the App Store if not installed.
- [ ] Push notifications (buddy woke up, nudges) — needs the paid program (APNs).

### Onboarding
- [ ] Apply `Backend/supabase/migrations/20261116000000_profile_onboarding.sql` (SQL Editor).
- [ ] `Shared/Config/SocialProof.json`: add stats / reviews only when they're real and current (reviews with permission). Never placeholders.
- [ ] App Privacy labels: age range + "where did you hear about us" are collected (linked to the account when signed in).

### App name
- [ ] App Store Connect › App Information › Name: **Gloop: Your Wake-Up Buddy** (26 of 30 characters).
      The home-screen name is already "Gloop" (`CFBundleDisplayName` in `project.yml`).
- [ ] Subtitle (30 max), e.g. "The alarm you can't snooze".
- [ ] Check "Gloop" is free as a trademark (EU/Benelux) and grab a domain for the share link / privacy pages.
- [ ] In-app purchase display names in App Store Connect: "Gloop Pro – Yearly" etc. (match `Config/Gloop.storekit`).

### Telemetry
- [ ] TelemetryDeck account + app "Gloop"; App ID into `Shared/Config/Telemetry.json` (see docs/Telemetry.md).
- [ ] Build the insights listed in docs/Telemetry.md (onboarding funnel, quit screens, revenue by paywall source, retention).
- [ ] Privacy policy: "anonymous usage statistics via TelemetryDeck (EU), opt-out in Settings › Privacy".
- [ ] App Privacy label: Usage Data › Product Interaction (+ Diagnostics if you add crash data) — not linked to you, not used for tracking. No ATT prompt needed.

### Legal (Privacy Policy, Terms, Health & Safety, Community Guidelines)
- [ ] Fill in `Shared/Config/Legal.json`: legal form, enterprise number (KBO), registered address, privacy + support email
      (shown as "[to be completed]" in the app until then). Also set `supportEmail` in `Shared/Config/Auth.json`.
- [ ] Re-run `python3 iOS/scripts/export_legal.py` and host `docs/legal/` (e.g. GitHub Pages); put the Privacy Policy
      URL in App Store Connect (required) and optionally the Terms URL (or use Apple's standard EULA).
- [ ] Recommended: have a lawyer review the documents once before launch.
- [ ] Process: check Buddies reports daily (24 h promise in Terms + Community Guidelines); answer data requests within 1 month.

### App Store listing (see docs/AppStore.md)
- [ ] Copy `iOS/fastlane/metadata/{en-US,en-GB}` into App Store Connect (or `fastlane deliver` once set up): name, subtitle, keywords, promotional text, description, release notes.
- [ ] Upload the 10 screenshots per size from `iOS/fastlane/screenshots/` (re-run `scripts/screenshots/make.sh` first).
- [ ] Categories Lifestyle + Productivity, age rating questionnaire (UGC → 12+), copyright, App Privacy answers as listed in docs/AppStore.md.
- [ ] Replace the placeholder URLs in `privacy_url.txt` / `support_url.txt` / `marketing_url.txt`.
- [ ] Add a `Shared/Config/WhatsNew.json` entry for every release (What's New sheet).

### Trial-ending reminder
- [ ] Notify users **1 day before their free trial ends** (in-app notice / push) that it turns into a paid plan.
  - [ ] Trial end dates in the database: App Store Server Notifications (iOS) / Play RTDN (Android) →
        Supabase function → `subscriptions` table (see "Later" below).
  - [ ] Daily Supabase cron + Edge Function: find trials ending in ~24 h → send the notice (push needs APNs / paid program).
  - [ ] Privacy policy + App Privacy labels if new data is stored (trial/subscription dates per user).

### Feedback board (Web/feedback + Help › Suggest a feature)
- [ ] Supabase › SQL Editor: apply `Backend/supabase/migrations/20261123000000_feedback.sql` (after the Buddies one).
- [ ] Supabase › Authentication › URL Configuration › Redirect URLs: add `https://jorenaerts.github.io/Earn-It/feedback/**`.
- [ ] GitHub › Settings › Pages › Source = **GitHub Actions** (a private repo needs GitHub Pro for Pages, or make the repo public).
- [ ] GitHub › Settings › Secrets and variables › Actions: add `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` (same as `iOS/Config/Supabase.xcconfig`).
- [ ] Run the "Web (GitHub Pages)" workflow, open the URL, sign in, post + vote once.
- [ ] Set `feedbackURL` in `Shared/Config/Auth.json` to that URL (the Help row stays hidden until then).
- [ ] Check feedback reports with the Buddies ones (Table Editor › `reports`, kind `feedback`).
- [ ] App Privacy labels: Other User Content (feedback ideas) linked to the account, App Functionality.
- [ ] Later: Android entry once accounts are ported (phase 4); status labels (Planned / Done) if wanted.

### Submission
- [ ] App privacy labels (email, user ID, purchases; no tracking).
- [ ] Review notes: explain AlarmKit alarm + background audio (keeps the alarm sounding until the
      mission is done), optional account, demo steps.
- [ ] Attach the in-app purchases to the first app version and submit.

### Later (recommended)
- [ ] App Store Server Notifications → Supabase function → `subscriptions` table
      (purchases already carry the Supabase user ID as `appAccountToken`).

## Languages (remaining)
- Translate the remaining 26 languages + App Store listing per language — steps and list in `docs/Localization/README.md`.
- Have a native speaker review at least Dutch, French, German, Spanish, Portuguese (incl. the legal documents) before launch; then set `"_reviewed": true` in their translation file.

## From TestFlight to the App Store

Do these before submitting version 1.0.0 for App Store review.

- [ ] **Change the contact email.** `joren.a@hotmail.com` is used as privacy + support email during TestFlight.
      Before the App Store release, switch to a dedicated address (e.g. `support@<your-domain>`):
  - [ ] `Shared/Config/Legal.json` → `privacyEmail`, `supportEmail`
  - [ ] `Shared/Config/Auth.json` → `supportEmail` (Help › Contact support)
  - [ ] Run `python3 iOS/scripts/export_legal.py` (updates `docs/legal/`)
  - [ ] Update the Privacy Policy Gist (below) with the new `docs/legal/privacy.md`
  - [ ] App Store Connect: App Review contact email, support URL / email, TestFlight feedback email
- [ ] **Complete the legal details** in `Legal.json`: full address (street + number, postcode, Peer),
      enterprise number as `1029.912.049`, legal form translated per language if wanted.
- [ ] **Privacy Policy URL** (required field in App Store Connect › App Information):
  - [x] Public Gist created: https://gist.github.com/JorenAerts/3460dc0a39ace79cf4ab6e54f2b76a01
  - [ ] After the email/address change: Gist › Edit › paste the new `docs/legal/privacy.md` (the link stays the same).
  - [ ] Paste the Gist URL in App Store Connect › App Information › Privacy Policy URL.
  - [ ] Terms: use Apple's standard EULA (no URL needed), or add a second Gist file with `docs/legal/terms.md`.


## Google Play (Android)

Roadmap and details: `docs/Android/PlayStore.md`.

- [ ] Android Studio first launch: **Standard** setup (installs the SDK in `~/Library/Android/sdk`),
      then Device Manager › create a Pixel emulator (latest Android version).
- [ ] Request a free **D-U-N-S number** for JA-Solutions (dnb.com) → needed for an Organization account.
- [ ] Create the **Google Play Console** account ($25 one-time), type **Organization**, and verify your identity.
- [ ] **Payments profile** with the same bank account (to sell subscriptions).
- [ ] Create the app "Gloop: Your Wake-Up Buddy" (free, with in-app purchases), Play App Signing on.
- [ ] Copy `Android/secrets.properties.example` → `Android/secrets.properties` with the same Supabase URL +
      **publishable** key as `iOS/Config/Supabase.xcconfig` (when accounts get ported, phase 4).
- [ ] Later (phase 3): products in Monetize › Products, as in the Play Billing table of `docs/Android/PlayStore.md`.
- [ ] Later (phase 5): Data safety, content rating, permission declarations (exact alarm, full-screen intent), store listing.
