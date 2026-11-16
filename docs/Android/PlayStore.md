# Gloop on Android / Google Play

The Android app is a native Kotlin + Jetpack Compose app in `Android/`, next to the iOS app in `iOS/`.
Both apps share the backend (`Backend/`, Supabase) and the content (`Shared/Config`: prices, coach lines,
quiz, tips, help, legal documents, translations). Logic is ported rule-for-rule from the Swift packages,
together with their test cases.

## Phases

| # | Phase | What | Done when |
|---|---|---|---|
| 1 | **Foundation** ✅ | Repo layout (`iOS/` · `Android/` · `Shared/`), Gradle project, `:core` + `:app`, shared assets, first port (`PricingCatalog`) | `:core:test` green, app shows the plans from `Pricing.json` |
| 2a | **Alarms + missions** ✅ | Exact alarms (`setAlarmClock`), full-screen mission over the lock screen, ringing in a foreground service until every mission is done (no Stop button), fail-safe after `maxReArms × reArmMinutes`, reboot/update restore. Home (alarms, permissions, test ring), editor (time, days, label, missions, sound with preview), missions Math, Shake, Memory, Quiz, Typing, success screen (streak + morning tip), 8 languages from the iOS catalog | Emulator: rings over the lock screen, can't be escaped, stops after the missions, resumes after an app update |
| 2b | **Onboarding + Progress + Settings** | ✅ Onboarding (same 20 steps as iOS; account/paywall/invite return with phases 3–4), slime + legal ported. Still open: Progress tab (XP, ranks, stickers), Settings, Gloop the slime (Compose Canvas port of `SlimeRenderer`), confetti, coach lines | A new user is guided from install to a first alarm |
| 3 | **Play Billing** | Google Play Billing Library: the plans from `Pricing.json`, 3-day trial, restore, the same free tier (`FeatureGate`) | Test purchase on the internal track |
| 4 | **Extra** | ✅ Camera missions (QR, item, sky, bed, colour hunt; CameraX + ML Kit + MediaPipe, flashlight with auto). Still open: Supabase accounts (Google/email) + Buddies, Glance widgets, own sounds, TelemetryDeck (Android SDK, same app ID) | Feature parity with iOS 1.0 |
| 5 | **Release** | Store listing, screenshots, Data safety, review | Live on Google Play |

### Porting order (phase 2, 2a done)
1. `:core`: models (`AlarmPlan`, `MissionConfig`, `SessionState`), `ReArmPolicy`, `StreakCalculator`, `XPRules`, `Rank`, `MedalRules`, `SlimeVitality`, `MoodEngine`, `CoachLines`, mission logic (`MathProblem`, `MemoryGame`, `QuizSession`, `TypingCheck`). Port the Swift tests with them.
2. `:app`: storage (DataStore with the same `gloop.*` keys/JSON), alarm engine, mission screens, the rest of the UI.
3. **UI strings:** one source of truth. A script generates `Android/app/src/main/res/values*/strings.xml` from `iOS/App/Localizable.xcstrings`, so the 8 languages carry over without translating again.
4. **Sounds:** extend `iOS/scripts/generate_sounds.py` to also write `.ogg` files for `Android/app/src/main/res/raw/`.

### Android-specific attention points
- **Battery optimisation** on Samsung/Xiaomi/OnePlus/… can kill alarms. Ask for the battery-optimisation exemption in onboarding (like the iOS permission steps) and test on at least one Samsung device.
- **Exact-alarm permission:** use `USE_EXACT_ALARM`, which is granted automatically for alarm-clock apps but needs a Play Console declaration. `SCHEDULE_EXACT_ALARM` would ask the user.
- **Notifications** (Android 13+) and **full-screen intent** (Android 14+) need runtime checks, like `PermissionCenter` on iOS.
- **Help/FAQ** (`Shared/Config/Help.json`) mentions iOS settings paths. Android needs its own answers; add platform-specific FAQ entries when porting Settings.
- **Pro is per store** for now: buying on iPhone does not unlock Android. Sharing Pro across platforms (via the Supabase account, or RevenueCat) is a later decision.

## Play Billing mapping
Google groups subscriptions differently from Apple. Proposed:

| Pricing.json | Google Play |
|---|---|
| weekly / monthly / quarterly / yearly | **One subscription** `be.gloop.app.pro` with 4 **base plans**: `weekly` (P1W), `monthly` (P1M), `quarterly` (P3M), `yearly` (P1Y), auto-renewing |
| `trialDays: 3` | An **offer** "free-trial" (3 days free, new customers only) on each base plan |
| lifetime | **One-time product** `be.gloop.app.pro.lifetime` |

Prices in EUR as in `Pricing.json` (€1.99 / €3.99 / €9.99 / €29.99 / €59.99). Let Google convert them for other countries.
When phase 3 starts, add the Google ids to `Pricing.json` (e.g. `"play": {"product": "be.gloop.app.pro", "basePlan": "yearly"}`) so both apps keep reading one file.

## Google Play Console checklist (you)
1. **Developer account** (one-time $25) at play.google.com/console.
   - **Organization (recommended):** JA-Solutions. Needs a free **D-U-N-S number** (request at dnb.com; takes days to 2 weeks). You can publish to production directly.
   - Personal: new personal accounts must run a **closed test with at least 12 testers for 14 days in a row** before production access.
   - Identity verification + a public developer email/address (EU trader rules, like on Apple).
2. **Payments profile** (merchant account) with the same bank account, to sell subscriptions.
3. **Create the app:** name "Gloop: Your Wake-Up Buddy", default language English (US), App, Free (with in-app purchases).
4. **App signing:** keep **Play App Signing** on. We create an **upload key** (`upload.jks`, never in git; the password goes in `Android/keystore.properties`). Back it up in a password manager.
5. **App content** (Policy › App content):
   - Privacy policy URL: the Gist (as for Apple).
   - **Data safety:** camera frames are analysed on the phone only; item/bed scans are stored on the phone as numbers + a thumbnail (same as iOS). Mirror `iOS/App/PrivacyInfo.xcprivacy` + `Shared/Config/Legal/privacy.md` (email, name, user ID, photos, user content, app interactions; no data sold; encrypted in transit; deletion in the app).
   - Ads: no. Content rating questionnaire (IARC). Target audience: 13+ (as the iOS age rating and Buddies require).
   - **Permission declarations:** exact alarm (`USE_EXACT_ALARM`, "alarm clock app"), full-screen intent (alarm), foreground service type (media playback for the ringing alarm), camera.
6. **Store listing:** short description (80 characters), full description (4000), icon 512×512, feature graphic 1024×500, at least 2 phone screenshots. Reuse the texts from `iOS/fastlane/metadata`.
7. **Products** (Monetize › Products) once the first build with Billing is uploaded: the subscription + base plans + trial offer, and the one-time product, as in the table above.
8. **Testing tracks:** Internal testing (up to 100 testers, instant) → Closed testing → Production. Uploads are **AAB** files (`./gradlew :app:bundleRelease`).
9. **Target API level:** new apps and updates must target a recent Android version (Google raises it every August). Keep `targetSdk` current in `app/build.gradle.kts`.

## Commands
```sh
cd Android
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
./gradlew :core:test           # JVM unit tests (no SDK)
./gradlew :app:assembleDebug   # debug APK (needs the Android SDK)
./gradlew :app:bundleRelease   # AAB for Play (needs the upload key, phase 5)
```
