# Earn It — iOS alarm + earn-your-apps

Alarm that keeps re-ringing until a mission is done. Later: Screen Time locks (FamilyControls).
Current milestone: **M1 (alarm + mission)**. Lock engine (M2) needs paid Apple team + App Group.

## Layout
- `Front-end/` — the whole iOS project (XcodeGen). `Backend/` — reserved (Supabase later), empty.
- `Front-end/project.yml` — source of truth. `EarnIt.xcodeproj` is generated & git-ignored: never edit it.
- `Front-end/App/` — app entry (`EarnItApp.swift`, `AppEnvironment`), App Intents (`Intents/`).
- `Front-end/Packages/` — local SwiftPM modules:
  - `Core` — models (`AlarmPlan`, `MissionConfig`, `SessionState`), `KeyValueStore` (JSON in UserDefaults), `DayLog` (SwiftData), `StreakCalculator`.
  - `AlarmEngine` — `AlarmCoordinator` (the re-arm loop), `ReArmPolicy` (pure), `AlarmScheduling` protocol, `AlarmKitScheduler` (live), `FakeScheduler` (tests).
  - `Missions` — `Mission` protocol + `MissionRegistry`, one folder per mission (`Math/`, `Shake/`, `QR/` (VisionKit scanner + printable code)). Optional `makeSetupView` for per-mission setup in the alarm editor.
  - `Features` — SwiftUI screens (`RootView`, Permission, Home, AlarmSetup, MissionRunner).
- `Front-end/Extensions/AlarmLiveActivity/` — WidgetKit extension: Live Activity for `AlarmAttributes<EarnItAlarmMetadata>` (alarm title + re-ring countdown on Lock Screen / Dynamic Island).
- `Purchases` package — `PricingCatalog` (reads `Config/Pricing.json`), `StoreService` (StoreKit 2), `EntitlementState`/`EntitlementResolver`, `FeatureGate` (free: 1 alarm, Math, Classic Beep), `DowngradePolicy`.
- `Account` package — optional login via **Supabase Auth** (`supabase-swift`): `AuthService` protocol, `SupabaseAuthService` (email+password, OAuth Apple/Google/Facebook/Microsoft via `earnit://auth-callback`), `UnavailableAuthService` (no config), `FakeAuthService`. Shown providers + legal URLs: `Config/Auth.json`.
- `Backend/supabase/` — Supabase CLI project: `profiles` migration (RLS own-row), `delete_own_account()` RPC for in-app deletion. Setup steps in `Backend/README.md`.
- `Coach` package — Sergeant Rise, the wake-up coach: `CoachMood` (proud, calm, suspicious, angry, disappointed), `CoachIntensity` (gentle / toughLove / savage), `MoodEngine` (pure rules: mission due → suspicious, re-rings → angry with `anger` 0…1; done → proud; fail-safe / broken streak → disappointed; else calm), `CoachLines` (reads `Config/CoachLines.json`, per context × tone, `{streak}` `{time}` `{rings}` placeholders), `CoachPreferences`. UI in `Features/Coach/CoachViews.swift` (`CoachAvatarView`, `CoachCard`, `CoachModel`).
- **Coach art = 5 images**: `App/Assets.xcassets/Coach/coach_<mood>.imageset/coach_<mood>.png` (placeholders are smileys). Replace the PNG with the same filename (square, transparent background, ≥512 px) to change the character — no code changes. Anger effects (red glow, shake, steam) are drawn on top in code.
- `Front-end/Tests/` — Swift Testing unit tests (logic only) + StoreKitTest flow tests.

## Commands (run from `Front-end/`)
```sh
xcodegen generate                                   # after any project.yml / new-file change
xcodebuild -project EarnIt.xcodeproj -scheme EarnIt \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
xcodebuild -project EarnIt.xcodeproj -scheme EarnIt \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build   # device-SDK compile check
```
Signing: `Front-end/Config/Local.xcconfig` (git-ignored) holds `DEVELOPMENT_TEAM`. Copy from `Local.xcconfig.example`.

## Pricing / purchases
- **Change plans or prices only in `Front-end/Config/Pricing.json`** (week / month / 3 months / year / lifetime: `price`, `enabled`, `badge`, `title`, `trialDays`, `defaultSelection`), then run `python3 Front-end/scripts/generate_storekit.py` to regenerate `Config/EarnIt.storekit`. Test `storekitFileMatchesPricingJSON` fails if you forget.
- App shows StoreKit's localized prices; Pricing.json decides which plans exist + order. Real prices must be mirrored in App Store Connect (same product IDs) once the paid program exists.
- Local purchases only work when the app is **run from Xcode** (scheme uses `EarnIt.storekit`). `devicectl` installs have no StoreKit config.
- Paywall: `Features/Paywall/PaywallView` (modes `.onboarding` / `.sheet`, `PaywallSheet` wrapper). Trial text from the product's intro offer; auto-renew disclosure (Guideline 3.1.2), Restore, Terms/Privacy (URLs in `Config/Auth.json`). Per-period math in `Purchases/PlanPeriod`.
- Free tier gating: `PaywallContext` injected via `.environment(\.paywall, …)` in `RootView`; any screen uses `.paywallSheet(isPresented:)`. Home gates add/enable alarm, editor gates Pro missions/sounds (sound preview stays free). `TierEnforcement.enforce` (DowngradePolicy + reschedule) runs only after `StoreService.hasLoadedEntitlement` (never on the cached value alone), never during a ringing mission, never before onboarding completes; changes become one-time Home notices (`DowngradeNotices`).
- The app shows nothing and starts no services when launched as the unit-test host (`XCTestConfigurationFilePath`), otherwise its StoreKit loading races `SKTestSession`.
- StoreKitTest gotchas: `Product.purchase()` of a *subscription* times out in the unit-test host (use `SKTestSession.buyProduct`); `expireSubscription` doesn't update `currentEntitlements` there — test expiry via `EntitlementResolver` + Xcode Transaction Manager.

## Secrets
- `Front-end/Config/Supabase.xcconfig` (git-ignored) holds `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` → Info.plist. **Only publishable keys in the app**; `AuthServiceFactory` refuses `sb_secret_…`. Without the file, accounts are hidden and the app still builds.

## Rules
- iOS 26.1 minimum, Swift 6 strict concurrency. Keep logic pure + testable; UI/framework glue thin.
- New mission = new folder in `Missions/`, conform to `Mission`, add a case to `MissionKind` + `MissionRegistry`, add logic tests.
- Wake loop rule: the alarm has **one control, the system X/Stop** (no secondary button — iOS can't hide X). `StopAlarmIntent` (`supportedModes = .foreground(.immediate)`) → `alarmEnded` → system alarm silenced, countdown follow-up at +reArmMinutes, app opens on mission. `AlarmCoordinator` drives `AlarmSoundPlayer` (AlarmEngine): sound plays whenever `needsMission` is true (set in `persist`/`reload`), from the X press until all missions succeed or fail-safe. `UIBackgroundModes: audio` keeps it going when the app is left or the phone locked; resumes after interruptions. Follow-up countdown remains a backup if the app is force-quit. Only `missionSucceeded()` cancels follow-ups. App also jumps to the mission when launched/active while any alarm is alerting or a follow-up countdown runs (`reload`, `observeSystemAlarms`), or via `earnit://mission` (Live Activity tap). Fail-safe after `maxReArms`.
- App opens straight into `MissionRunnerView` while `coordinator.needsMission` is true (wins over onboarding too).
- Main UI after onboarding: `MainTabView` — Alarms (`HomeView`), Progress (`StatsView`, from `DayLog`), Settings (`SettingsView`: account incl. sign in/out + delete, subscription status/upgrade/manage/restore, permissions, legal, version; DEBUG developer tools incl. `DebugSection`).
- Onboarding: `Features/Onboarding/` — `OnboardingFlow` (pure step logic: account skipped when accounts unavailable or signed in, paywall skipped for Pro), `OnboardingStore` (`earnit.onboarding`, resumes mid-flow; legacy `earnit.onboarded` = completed). Steps: welcome, howItWorks, goals, account (`AccountStepView`), permissions, firstAlarm, paywall. Debug › Replay onboarding.
- **Multiple alarms**: `KeyValueStore.loadPlans()` (`earnit.plans`, migrates legacy single `earnit.plan`). Main AlarmKit alarm id = `plan.id`. Follow-ups/test rings map to their plan via `earnit.alarmOwners`. Each ring cycle stores `SessionState.planID`; `coordinator.activePlan` drives missions, re-ring and sound. Old JSON decodes via tolerant `AlarmPlan.init(from:)` — keep new fields `decodeIfPresent`.
- **Session = one ring cycle, not one day.** An alarm ringing/ending after a finished cycle (mission done or fail-safe) starts a fresh session the same day (`ReArmPolicy.currentSession(newRing:)`). Bug found on-device: per-day sessions ignored every alarm after the first completed mission.
- State intents need lives in `KeyValueStore` (small JSON), not SwiftData — extensions in M2 will read it from an App Group.

## AlarmKit / platform gotchas (append every on-device finding)
- AlarmKit + Screen Time only really work on a physical iPhone; Simulator = unit tests + UI only.
- `AlarmPresentation.Alert(title:secondaryButton:secondaryButtonBehavior:)` (no stop button arg) is iOS 26.1+; system always shows a Stop slider.
- Don't store `AlarmManager.shared` in a `@MainActor` property — Swift 6 flags "sending risks data race". Call `AlarmManager.shared` inline.
- Alarm button intents must be `LiveActivityIntent`s defined in the app target; `supportedModes = .foreground(.immediate)` opens the app.
- Cold launch from an intent: `onChange(of: scenePhase)` doesn't fire for the initial value — `RootView.task` calls `reload()` on first appear.
- Changing the alarm layout/sound needs re-scheduling existing alarms: `refreshAlarms()` runs on launch.
- Alarm button intents must silence the alarm themselves (`AlarmManager.shared.stop(id:)`, done in `AlarmCoordinator.alarmEnded`). A `.custom` secondary button does NOT stop the alert. On mission success / fail-safe, sweep *all* alarms from `AlarmManager.shared.alarms` (not just tracked IDs): stop the main plan alarm (keeps weekly repeat), stop + cancel everything else.
- `AlarmPresentation.Alert` only has a `title` — no subtitle. Title = `AlarmPlan.alarmTitle` ("Earn It - Math Problem"). Re-ring info lives in the countdown: follow-ups are `AlarmConfiguration.timer(duration:)` with `AlarmPresentation.Countdown`, rendered by our Live Activity widget (required for countdown UI). Metadata type must stay in `AlarmEngine` so app + widget share it.
- No `UIRequiresFullScreen` (deprecated iOS 26, TN3192). App supports all orientations + has `UILaunchScreen`; layouts must adapt (no fixed frames).
- Alarm sounds: `AlarmSound` enum ↔ `App/Sounds/EarnIt_<raw>.caf` (30 s, 22 kHz mono LEI16, generated by a script — keep under 30 s). Per alarm: AlarmKit uses `.named(sound.fileName)`; `AlarmSoundPlayer` loops the same file during the mission. Adding a sound = new enum case + file (test `everySoundHasAFile` checks). iOS gives apps no access to the built-in alarm tones, so a custom file is the only way to match.
- Logs: subsystem `be.earnit.app`, category `alarm` — filter in Console.app with the iPhone selected.
- `Mission` protocol is not `@MainActor` (Identifiable conformance would cross isolation); only `makeView` is.
- Free personal team: provisioning expires after 7 days — re-run from Xcode. No App Groups / Family Controls until paid team.
