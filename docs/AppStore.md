# App Store listing & growth

Everything for the App Store page lives in `iOS/fastlane/` (fastlane `deliver` layout, so it can
be uploaded automatically later, or copied by hand into App Store Connect).

## Listing (en-US + en-GB)
| Field | Limit | Value / file |
|---|---|---|
| Name | 30 | **Gloop: Your Wake-Up Buddy** (25) |
| Subtitle | 30 | **Stop Snoozing: Do a Mission** (27) |
| Keywords US | 100 | `alarm,clock,heavy,sleeper,loud,math,puzzle,shake,qr,code,oversleep,morning,routine,get,bed,deep` (95) |
| Keywords UK | 100 | `habit,streak,early,riser,motivation,friends,challenge,discipline,pet,cute,slime,timer,tracker,fun` (97) |
| Promotional text | 170 | `promotional_text.txt`, changeable any time without a review |
| Description | 4000 | `description.txt` (~2,550; UK spelling in en-GB) |
| What's New | 4000 | `release_notes.txt` |
| URLs | — | `privacy_url.txt`, `support_url.txt`, `marketing_url.txt` (placeholders until docs/legal is hosted) |

**Positioning:** anti-snooze. Gloop is not the alarm clock, he's the buddy that gets you up, because you
have to *do* something to stop the alarm.

**Keyword rules** (tested in `Tests/GrowthTests.swift`): no spaces, no words already in name/subtitle
(Apple indexes those already), singular only (plurals match automatically), no competitor brand names,
US and UK fields don't overlap. It's widely reported that the US store also indexes the en-GB keyword
field, giving ~200 characters for the US; verify with App Store Connect's search data after launch.
Revisit keywords every 4–6 weeks using App Store Connect › App Analytics › Sources (search terms).

## App Store Connect settings
- **Privacy Policy URL:** https://gist.github.com/JorenAerts/3460dc0a39ace79cf4ab6e54f2b76a01 (public Gist; update it whenever `docs/legal/privacy.md` changes, the link stays the same). Terms: Apple's standard EULA.
- **Primary category:** Lifestyle. **Secondary:** Productivity.
- **Age rating:** answer "Yes" to user-generated content (Buddies) with reporting/blocking → 12+.
- **Copyright:** `© 2026 JA-Solutions`.
- **App Privacy** (must match the Privacy Policy):
  - Contact Info › Email (account, optional): linked to you, app functionality.
  - User Content › Photos (Buddies morning photos, 24 h) and Other User Content (club names, reactions): linked, app functionality.
  - Identifiers › User ID (account): linked, app functionality.
  - Usage Data › Product Interaction (TelemetryDeck): **not** linked, analytics.
  - Purchases: handled by Apple (not collected by us beyond entitlement).
  - Tracking: **No**.
- **Subscriptions:** group "Gloop Pro" with the product IDs from `Shared/Config/Pricing.json`; display names
  "Gloop Pro – Yearly" etc.; 3-day free trial as introductory offer on each subscription.

## Screenshots
`iOS/scripts/screenshots/make.sh` generates all 10 shots from the real app (DEBUG demo scenes)
in 6.9" (1320×2868) and 6.5" (1284×2778) for en-US and en-GB → `iOS/fastlane/screenshots/`.
Review them in `docs/screenshots.html`. Headlines, order and scenes: `scripts/screenshots/scenes.json`.
Re-run after any UI change.

1. Stop snoozing. · 2. Do a mission to stop it · 3. Math, shake or scan · 4. Snooze, and Gloop droops ·
5. Wake up with friends · 6. Scan your mug to stop it · 7. Evolve Gloop to King · 8. Your streak on
your Home Screen · 9. Wake up to your own sound · 10. Make Gloop yours

Ideas to A/B test later (Product Page Optimization in App Store Connect): Gloop-first first shot
("Meet your wake-up buddy"), a night→morning colour story, a 15–30 s app preview video.

## Promotional text calendar
| When | Text idea |
|---|---|
| Launch | "New: meet Gloop, the wake-up buddy who bounces when you get up and melts when you snooze…" |
| Late December | "New year, new mornings. Start a 7-day streak with Gloop before January." |
| Late August | "Back to school (or work)? Gloop gets you out of bed on the first ring." |
| End of March / October | "Clocks change this weekend. Gloop makes sure the first morning still starts on time." |
| Any update | Mention the newest feature in one line. |

## In-app growth
- **Rating prompt** (`Features/Growth`, `RatingPolicy`): Apple's prompt only at happy moments
  (3rd/10th first-ring morning, 7/30/100-day streak, evolution), on the success screen after 2.5 s;
  never after a fail-safe, never in the first 3 days, max once per 60 days and per version
  (Apple caps at 3/year anyway). Telemetry `Rate.prompted`.
- **What's New sheet**: once per version after an update, from `Shared/Config/WhatsNew.json`
  (add an entry for every release). Telemetry `WhatsNew.shown`.
- **Share streak card**: 1080×1920 image (Gloop at your stage + streak + stickers) from the success
  screen and Progress tab. Telemetry `Share.streakCard`. Add the store link once `shareURL` exists.

## Localisation
The app is translated (see `docs/Localization/README.md`). The store listing per language
(`fastlane/metadata/<locale>/` with local keywords, and screenshots with `-language <code>` +
`headline_<locale>` in scenes.json) is phase 5 of the language plan.
