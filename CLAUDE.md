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
  - `Missions` — `Mission` protocol + `MissionRegistry`, one folder per mission (`Math/`, `Shake/`, `QR/` (VisionKit scanner + printable code), `Steps/` (CMPedometer)). Optional `makeSetupView` for per-mission setup in the alarm editor.
  - `Features` — SwiftUI screens (`RootView`, Permission, Home, AlarmSetup, MissionRunner).
- `Front-end/Extensions/AlarmLiveActivity/` — WidgetKit extension: Live Activity for `AlarmAttributes<EarnItAlarmMetadata>` (alarm title + re-ring countdown on Lock Screen / Dynamic Island).
- `Front-end/Tests/` — Swift Testing unit tests (logic only).

## Commands (run from `Front-end/`)
```sh
xcodegen generate                                   # after any project.yml / new-file change
xcodebuild -project EarnIt.xcodeproj -scheme EarnIt \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
xcodebuild -project EarnIt.xcodeproj -scheme EarnIt \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build   # device-SDK compile check
```
Signing: `Front-end/Config/Local.xcconfig` (git-ignored) holds `DEVELOPMENT_TEAM`. Copy from `Local.xcconfig.example`.

## Rules
- iOS 26.1 minimum, Swift 6 strict concurrency. Keep logic pure + testable; UI/framework glue thin.
- New mission = new folder in `Missions/`, conform to `Mission`, add a case to `MissionKind` + `MissionRegistry`, add logic tests.
- Wake loop rule: the alarm has **one control, the system X/Stop** (no secondary button — iOS can't hide X). `StopAlarmIntent` (`supportedModes = .foreground(.immediate)`) → `alarmEnded` → system alarm silenced, countdown follow-up at +reArmMinutes, app opens on mission. `AlarmCoordinator` drives `AlarmSoundPlayer` (AlarmEngine): sound plays whenever `needsMission` is true (set in `persist`/`reload`), from the X press until all missions succeed or fail-safe. `UIBackgroundModes: audio` keeps it going when the app is left or the phone locked; resumes after interruptions. Follow-up countdown remains a backup if the app is force-quit. Only `missionSucceeded()` cancels follow-ups. App also jumps to the mission when launched/active while any alarm is alerting or a follow-up countdown runs (`reload`, `observeSystemAlarms`), or via `earnit://mission` (Live Activity tap). Fail-safe after `maxReArms`.
- App opens straight into `MissionRunnerView` while `coordinator.needsMission` is true.
- **Session = one ring cycle, not one day.** An alarm ringing/ending after a finished cycle (mission done or fail-safe) starts a fresh session the same day (`ReArmPolicy.currentSession(newRing:)`). Bug found on-device: per-day sessions ignored every alarm after the first completed mission.
- State intents need lives in `KeyValueStore` (small JSON), not SwiftData — extensions in M2 will read it from an App Group.

## AlarmKit / platform gotchas (append every on-device finding)
- AlarmKit + Screen Time only really work on a physical iPhone; Simulator = unit tests + UI only.
- `AlarmPresentation.Alert(title:secondaryButton:secondaryButtonBehavior:)` (no stop button arg) is iOS 26.1+; system always shows a Stop slider.
- Don't store `AlarmManager.shared` in a `@MainActor` property — Swift 6 flags "sending risks data race". Call `AlarmManager.shared` inline.
- Alarm button intents must be `LiveActivityIntent`s defined in the app target; `supportedModes = .foreground(.immediate)` opens the app.
- Cold launch from an intent: `onChange(of: scenePhase)` doesn't fire for the initial value — `RootView.task` calls `reload()` on first appear.
- Changing the alarm layout needs re-scheduling existing alarms: `refreshMainAlarm()` runs on launch.
- Alarm button intents must silence the alarm themselves (`AlarmManager.shared.stop(id:)`, done in `AlarmCoordinator.alarmEnded`). A `.custom` secondary button does NOT stop the alert. On mission success / fail-safe, sweep *all* alarms from `AlarmManager.shared.alarms` (not just tracked IDs): stop the main plan alarm (keeps weekly repeat), stop + cancel everything else.
- `AlarmPresentation.Alert` only has a `title` — no subtitle. Title = `AlarmPlan.alarmTitle` ("Earn It - Math Problem"). Re-ring info lives in the countdown: follow-ups are `AlarmConfiguration.timer(duration:)` with `AlarmPresentation.Countdown`, rendered by our Live Activity widget (required for countdown UI). Metadata type must stay in `AlarmEngine` so app + widget share it.
- No `UIRequiresFullScreen` (deprecated iOS 26, TN3192). App supports all orientations + has `UILaunchScreen`; layouts must adapt (no fixed frames).
- One alarm sound everywhere: `App/Sounds/EarnItAlarm.caf` (30 s, 22 kHz mono LEI16, generated). AlarmKit uses `.named("EarnItAlarm.caf")`; `AlarmSoundPlayer` loops the same file during the mission. iOS gives apps no access to the built-in alarm tones, so a custom file is the only way to match.
- Logs: subsystem `be.earnit.app`, category `alarm` — filter in Console.app with the iPhone selected.
- `Mission` protocol is not `@MainActor` (Identifiable conformance would cross isolation); only `makeView` is.
- Free personal team: provisioning expires after 7 days — re-run from Xcode. No App Groups / Family Controls until paid team.
