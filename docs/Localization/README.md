# Localization

Gloop's app language can be changed in onboarding (🌐 button on the welcome screen) and in
Settings › Look & feel › Language. "Automatic" follows the iPhone's language when Gloop has it,
otherwise English. Switching is instant (no restart).

## How it works
- **One catalog:** `iOS/App/Localizable.xcstrings` (Bundle.main) holds every string from the app
  and all packages. Keys are the English text. The widget extension compiles the same file.
- **SwiftUI literals** (`Text("…")`, `Button("…")`, `.navigationTitle("…")`) follow
  `.environment(\.locale)`, set at the root by `LanguageEnvironment` (also right-to-left for ar/he).
- **Everything that is a `String`** (model names, errors, notifications, alarm titles, values passed to
  custom views) goes through `L10n.tr("…")` (package `Localization`). Interpolation works:
  `L10n.tr("Solve \(n) problems in a row.")` becomes the key `Solve %lld problems in a row.`.
- A language switch redraws everything (`.id(language)` in `RootView`), re-registers alarms (iOS alarm
  title), reschedules coach notifications and reloads widgets. It also sets `AppleLanguages`, so iOS
  texts (permission prompts) follow from the next launch.
- **Dates/times:** `date.localized(...)` instead of `date.formatted(...)` in strings.
- **Content files:** `Shared/Config/Translations/{CoachLines,Help,WhatsNew}.<code>.json` and
  `Shared/Config/Legal/<doc>.<code>.md` (+ `"<key>.<code>"` values in `Shared/Config/Legal.json`). Missing parts fall
  back to English. Translated legal documents say the English version applies, with "Read in English".
- **Not translated:** telemetry, developer tools (`shouldTranslate: false`), stored values
  (`Rank.englishTitle` in Buddies reports).

## Workflow
```sh
cd iOS
python3 scripts/l10n/extract.py --report   # build with string extraction, merge keys into the catalog,
                                           # list UI-looking literals that are NOT translatable
# translate: scripts/l10n/translations/<code>.json  ({"English key": "…" | {"one": …, "other": …}})
python3 scripts/l10n/apply.py -v           # merge into the catalog, check placeholders, list missing
```
- New language: add its code to `CFBundleLocalizations` in `project.yml` (app + widget extension),
  add `translations/<code>.json`, the content files and the store listing. `AppLanguage.all` already
  lists 34 languages; the picker only shows languages that ship.
- AI translations are stored as "needs review". Set `"_reviewed": true` in a translation file after a
  native speaker checked it.
- Tests (`LocalizationTests`) check: every key in every shipped language, matching placeholders,
  Info.plist strings, coach lines / help / What's New / legal per language, and Dutch end to end.
- Screenshots in a language: launch argument `-language <code>` (this launch only).

## Languages
| Status | Languages |
|---|---|
| Done (AI, needs native review) | English, Dutch, French, German, Spanish, Italian, Portuguese (Brazil), Portuguese (Portugal) |
| To do | Japanese, Korean, Chinese (Simplified), Chinese (Traditional), Polish, Turkish, Russian, Ukrainian, Swedish, Danish, Norwegian, Finnish, Czech, Slovak, Hungarian, Romanian, Croatian, Greek, Catalan, Arabic, Hebrew (right-to-left), Hindi, Thai, Vietnamese, Indonesian, Malay |
| To do | App Store listing + screenshots per language (`fastlane/metadata/<locale>/`, `-language <code>`) |

### Adding one of the remaining languages
Per language (see `fr` as the example):
1. `scripts/l10n/translations/<code>.json` — every key in the catalog (plural forms for the keys that have them in `nl.json`).
2. `Shared/Config/Translations/{CoachLines,Help,WhatsNew}.<code>.json`.
3. `Shared/Config/Legal/{privacy,terms,health-safety,community}.<code>.md` (or a shared base, e.g. `pt` for pt-BR + pt-PT) + `"country.<code>"` / `"effectiveDate.<code>"` in `Shared/Config/Legal.json`.
4. Info.plist texts in `scripts/l10n/infoplist.json`.
5. `python3 scripts/l10n/apply.py <code>`, add the code to `CFBundleLocalizations` (app + widget, `project.yml`), `xcodegen generate`, run the tests.
Arabic/Hebrew: check the hand-drawn layouts (chart, comparison) in right-to-left.
