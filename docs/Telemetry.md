# Telemetry (TelemetryDeck)

Anonymous usage statistics to see where people drop off, how they decide on the paywall, and
whether they keep getting up with Gloop. Code: `iOS/Packages/Telemetry` (catalog in
`TelemetryEvent.swift`), hooks in `Features`.

## Setup (once)
1. Create an account at telemetrydeck.com → **New app** "Gloop".
2. Copy the **App ID** into `Shared/Config/Telemetry.json` → `"appID": "…"`. Empty = nothing is sent.
   Also set `"namespace"` to your organisation's namespace (Organisation settings; ours: `com.jasolutions`).
   **Without the right namespace the signals are accepted but never show up in the dashboard.**
3. Run from Xcode → Settings › tap Version 7× → Developer tools → **Send test signal**.
   In TelemetryDeck switch the dashboard to **Test mode** to see it (Xcode builds are always test
   signals; TestFlight/App Store builds are live).

## Privacy rules
- Random installation ID (`gloop.telemetry.id`), not the account ID. TelemetryDeck hashes it again.
- Only enums, counts, durations and buckets. Never names, emails, alarm labels, club names, photos
  or typed text. `Telemetry.sanitized` drops anything with `@`, UUIDs, and cuts values at 64 chars.
- Opt-out: Settings › Privacy. Off = stop immediately + forget the ID.
- Every signal also carries: `plan` (free/trial/pro/lifetime), `onboarded`, `daysSinceInstall`
  (bucket), plus TelemetryDeck's defaults (app version, OS, device, locale).

## Event catalog
| Signal | Parameters |
|---|---|
| App.launched | source (cold / alarm / link) |
| App.foregrounded | — |
| App.backgrounded | screen, secondsOnScreen, sessionSeconds, sessionLength |
| Screen.viewed | screen (Home, Progress, Buddies, Club, Settings[.x], Paywall, Mission, Success, Help, Onboarding.<step>) |
| Onboarding.stepViewed | step, index |
| Onboarding.stepCompleted | step, seconds, + answer (ageRange, heardFrom, reaction, getUpTime, struggles, goal, wakeHour, weekdaysCount, mission, difficulty, target, sound, gaveName) |
| Onboarding.back | from |
| Onboarding.permission | kind, granted |
| Onboarding.inviteShared | completed |
| Onboarding.signIn | method (provider / email / skipped) |
| Onboarding.completed | totalSeconds, duration, outcome (free / trial / pro) |
| Paywall.shown / plansUnavailable | source |
| Paywall.planSelected | plan, source |
| Purchase.started / cancelled / failed | plan, source |
| Purchase.completed | plan, source, trial |
| Purchase.restored | found |
| Paywall.dismissed | source, secondsShown, purchased |
| Entitlement.changed | from, to (renewals, expiries, refunds) |
| Alarm.created / edited | missions, soundKind, weekdaysCount, wakeHour, reRingMinutes, alarmCount |
| Alarm.toggled / deleted | on |
| Alarm.rang / stopped | attempt |
| Mission.started | missions, attempt |
| Mission.completed | missions, rings, secondsFromFirstRing, wakeDuration, firstTry |
| Mission.backupUsed | mission |
| Morning.failSafe | rings |
| Streak.milestone | days (3, 7, 14, 30, 60, 100, 365) |
| Gloop.evolved | stage |
| Sticker.earned | sticker |
| Pause.set / resumed | option |
| Buddies.* | clubCreated(public), joined(via), photoPosted(clubCount), photoSkipped, reacted, reported(kind), blocked |
| Sound.* | imported, recorded, appleMusicPicked |
| Appearance.changed / Icon.changed | mode / icon |
| Camera.flashlight | mode (auto/on/off), auto (true = Auto switched it on in the dark), mission (qr, object, bed, colorHunt, objectSetup, bedSetup, qrSetup) |
| Coach.toneChanged / Reminders.toggled | tone / on |
| Help.opened / faqOpened | question (index in Help.json) |
| Rate.requested, Account.signedOut, Account.deleted, Permission.denied(kind), Telemetry.test | |
| Error.shown | area, code |

Paywall sources: onboarding, settings, homeBanner, addAlarm, enableAlarm, lockedMission, lockedSound,
createClub, widget, downgradeNotice, developer, other.

## Insights to build in TelemetryDeck
1. **Onboarding funnel**: Onboarding.stepViewed filtered by step, in flow order (welcome → … → paywall)
   → see the biggest drop. Add "Onboarding.completed".
2. **Where people quit**: App.backgrounded, breakdown by `screen` (filter `onboarded = false` for
   onboarding drop-off, `true` for the main app).
3. **Answers**: Onboarding.stepCompleted, breakdown by each answer (heardFrom → marketing, reaction,
   getUpTime, goal) and `seconds` per step (confusing steps take long).
4. **Revenue funnel**: Paywall.shown → Paywall.planSelected → Purchase.started → Purchase.completed,
   broken down by `source` (which locked feature sells Pro) and `plan`.
5. **Trial → paid**: Entitlement.changed with from=trial (to=pro = converted, to=free = churned).
6. **Retention**: TelemetryDeck's built-in retention (users seen day 1 / 7 / 30) + Mission.completed per
   `daysSinceInstall`.
7. **Mornings**: Mission.completed by `missions` and `firstTry`; Morning.failSafe rate;
   Mission.backupUsed by mission (too hard?).
8. **Features**: Screen.viewed and Buddies.* / Sound.* counts; Icon.changed, Appearance.changed.
9. **Errors**: Error.shown by area/code; Paywall.plansUnavailable.
