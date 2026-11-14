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
- [ ] Host both on a public URL (e.g. your website, Notion public page, GitHub Pages).
- [ ] Put the URLs in `Front-end/Config/Auth.json` → `termsURL`, `privacyURL`
      (used by the paywall and Settings › About).
- [ ] Add both links in App Store Connect (App Information › Privacy Policy URL; Terms link in
      the app description or as custom EULA).

- [ ] Terms of Use: users may only use audio they have the rights to as alarm sounds; own sounds stay on their device (personal use, never shared through the app).

## 2. Own email sender for Supabase (removes "email rate limit exceeded")

Supabase's built-in mailer only sends a few emails per hour — fine for testing, not for users.

- [ ] Create an account at an email provider (e.g. **Resend**, Postmark or Brevo — all have a free tier).
- [ ] Verify a sending domain (e.g. `earnit.app`) — add the DNS records they give you (SPF, DKIM).
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
- [ ] Update `Front-end/Config/Local.xcconfig` with the new paid **Team ID**.
- [ ] Register App Group `group.be.earnit.app` (Xcode › Signing & Capabilities does it automatically) and add `EARNIT_DEVICE_APP_GROUPS = YES` to `Local.xcconfig` so the home-screen widgets get live data on device.
- [ ] App Store Connect › Business: accept the **Paid Applications Agreement**, add bank + tax info.

### App & products
- [ ] Create the app record — bundle ID `be.earnit.app`.
- [ ] Create subscription group **"Earn It Pro"** with the subscriptions from
      `Front-end/Config/Pricing.json` — **same product IDs**:
  - [ ] `be.earnit.app.pro.weekly` (1 week)
  - [ ] `be.earnit.app.pro.monthly` (1 month)
  - [ ] `be.earnit.app.pro.quarterly` (3 months)
  - [ ] `be.earnit.app.pro.yearly` (1 year)
  - [ ] For each: price, display name, description, review screenshot, and an
        **introductory offer: free trial, 3 days**.
- [ ] Create `be.earnit.app.pro.lifetime` as a **non-consumable** in-app purchase.
- [ ] Keep `Pricing.json` prices in sync with App Store Connect (then run
      `python3 Front-end/scripts/generate_storekit.py`).

### Testing
- [ ] Users and Access › Sandbox → create a **sandbox tester**.
- [ ] Upload a build to **TestFlight**, install it, buy a plan with the sandbox account.
- [ ] Check: trial starts → **Manage subscription** opens Apple's sheet → cancel → after expiry
      the app drops to Free and the downgrade notice appears (sandbox renewals take minutes).
- [ ] Check **Restore purchases** on a second device / after reinstall.

### Apple Music (needs the paid program)
- [ ] Developer portal › Identifiers › `be.earnit.app` › App Services: enable **MusicKit**.
- [ ] Test search + playback with an Apple Music subscription.

### Sign in with Apple (needs the paid program)
- [ ] Enable the Sign in with Apple capability for `be.earnit.app`.
- [ ] Create a Services ID + Sign in with Apple key, paste them in Supabase › Providers › **Apple**.
- [ ] Keep `"apple"` in `Front-end/Config/Auth.json` → `providers`.

### Settings › Help & feedback
- [ ] Set `supportEmail` in `Front-end/Config/Auth.json` (the Contact support row stays hidden while empty).
- [ ] Set `shareURL` (website or App Store page, `https://apps.apple.com/app/id<APP_ID>`) — now a placeholder.
- [ ] Add your Supabase user UUID to `Front-end/Config/Developer.json` so the 7-tap developer tools
      unlock on TestFlight builds (copy it in Settings › Developer tools › Info).

### Submission
- [ ] App privacy labels (email, user ID, purchases; no tracking).
- [ ] Review notes: explain AlarmKit alarm + background audio (keeps the alarm sounding until the
      mission is done), optional account, demo steps.
- [ ] Attach the in-app purchases to the first app version and submit.

### Later (recommended)
- [ ] App Store Server Notifications → Supabase function → `subscriptions` table
      (purchases already carry the Supabase user ID as `appAccountToken`).
