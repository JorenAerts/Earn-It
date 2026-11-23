#!/bin/sh
# Generates the App Store screenshots from the real app (DEBUG scenes with demo data): one panoramic
# banner of 4 shots per language (compose.swift), for every App Store locale in scenes.json.
#   cd iOS && scripts/screenshots/make.sh
#   LANGS="en nl" scripts/screenshots/make.sh     # only these app languages
#   SKIP_CAPTURE=1 scripts/screenshots/make.sh    # re-compose from the last captures (design tweaks)
# Output (PNG, git-ignored): fastlane/screenshots/<locale>/<id>-6.9.png (1320×2868), -6.5.png (1284×2778), -6.3.png (1206×2622),
# plus ../docs/screenshots.html to review them.
set -e
cd "$(dirname "$0")/../.."
ROOT=$(pwd)
WORK="${TMPDIR:-/tmp}/gloop-screenshots"
RAW="$WORK/raw"; mkdir -p "$RAW"
DEVICE="Gloop Screenshots 6.9"
TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"

UDID=$(xcrun simctl list devices | grep "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
if [ -z "$SKIP_CAPTURE" ]; then
  if [ -z "$UDID" ]; then UDID=$(xcrun simctl create "$DEVICE" "$TYPE"); fi
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  xcrun simctl ui "$UDID" appearance light
  xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 --operatorName ""

  echo "Building…"
  xcodebuild -project Gloop.xcodeproj -scheme Gloop -destination "id=$UDID" -derivedDataPath "$WORK/dd" build -quiet
  xcrun simctl install "$UDID" "$WORK/dd/Build/Products/Debug-iphonesimulator/Gloop.app"
fi

echo "Compiling composer…"
swiftc -parse-as-library -O scripts/screenshots/compose.swift \
  Packages/WidgetShared/Sources/WidgetShared/Slime/SlimeDrawing.swift -o "$WORK/compose"

python3 - "$UDID" "$RAW" "$WORK/compose" "$ROOT" "${LANGS:-}" "${SKIP_CAPTURE:-}" <<'PY'
import json, subprocess, sys, time, pathlib, shutil, tempfile
udid, raw, compose, root, only, skip_capture = sys.argv[1:7]
root, raw = pathlib.Path(root), pathlib.Path(raw)
config = json.loads((root / "scripts/screenshots/scenes.json").read_text())
scenes, locales = config["scenes"], config["locales"]
languages = sorted(set(locales.values()), key=list(locales.values()).index)
if only:
    languages = [l for l in languages if l in only.split()]
sizes = {"6.9": (1320, 2868), "6.5": (1284, 2778), "6.3": (1206, 2622)}  # 6.3 = App Store Connect "medium display"
catalog = json.loads((root / "App/Localizable.xcstrings").read_text())["strings"]

def tr(key, lang):
    """The app's own translation of `key` (falls back to English)."""
    unit = catalog.get(key, {}).get("localizations", {}).get(lang, {}).get("stringUnit", {})
    return unit.get("value") or key

for lang in languages:
    if not skip_capture:
        for s in scenes:
            shot = raw / f"{lang}-{s['id']}.png"
            subprocess.run(["xcrun", "simctl", "terminate", udid, "be.gloop.app"], capture_output=True)
            subprocess.run(["xcrun", "simctl", "launch", udid, "be.gloop.app", *s["args"], "-language", lang],
                           check=True, capture_output=True)
            time.sleep(9)
            subprocess.run(["xcrun", "simctl", "io", udid, "screenshot", str(shot)], check=True, capture_output=True)
            print("captured", lang, s["id"])
    spec = [{"id": s["id"], "raw": str(raw / f"{lang}-{s['id']}.png"),
             "headline": s["headline"][lang], "accent": s["accent"][lang],
             "cards": [{"symbol": c["symbol"], "tint": c.get("tint", "orange"), "title": tr(c["key"], lang)}
                       for c in s.get("cards", [])]} for s in scenes]
    for s in spec:
        assert s["accent"] in s["headline"], f"{lang} {s['id']}: accent not in headline"
    spec_file = pathlib.Path(tempfile.mkstemp(suffix=".json")[1])
    spec_file.write_text(json.dumps(spec, ensure_ascii=False))
    for locale, l in locales.items():
        if l != lang:
            continue
        out = root / "fastlane/screenshots" / locale
        shutil.rmtree(out, ignore_errors=True)
        out.mkdir(parents=True)
        for name, (w, h) in sizes.items():
            subprocess.run([compose, str(spec_file), str(out), name, str(w), str(h)], check=True)
        print("composed", locale)
    # Product page header (App Store Connect › Header): fastlane/header/<locale>/header-<w>x<h>.png
    hd = config.get("header")
    if hd:
        hspec = pathlib.Path(tempfile.mkstemp(suffix=".json")[1])
        hspec.write_text(json.dumps({"headline": hd["headline"][lang], "accent": hd["accent"][lang],
                                     "raws": [str(raw / f"{lang}-{i}.png") for i in hd["phones"]]}, ensure_ascii=False))
        for locale, l in locales.items():
            if l != lang:
                continue
            hout = root / "fastlane/header" / locale
            shutil.rmtree(hout, ignore_errors=True)
            hout.mkdir(parents=True)
            # header-*: product page header; search-*: search results (3:2).
            for (name, w, h) in [("header", 5244, 2950), ("header", 3840, 1646), ("search", 3840, 2560)]:
                subprocess.run([compose, "header", str(hspec), str(hout / f"{name}-{w}x{h}.png"), str(w), str(h)], check=True)

html = ['<!doctype html><meta charset="utf-8"><title>Gloop screenshots</title>',
        '<style>body{font-family:-apple-system;background:#222;color:#eee;margin:24px}'
        '.row{display:flex;gap:6px;overflow-x:auto}img{height:520px;border-radius:12px}</style>']
for locale in locales:
    out = root / "fastlane/screenshots" / locale
    if not out.exists():
        continue
    html.append(f"<h2>{locale}</h2><div class=row>")
    for s in scenes:
        rel = (out / f"{s['id']}-6.9.png").relative_to(root.parent)
        html.append(f'<img src="../{rel}">')
    html.append("</div>")
(root.parent / "docs/screenshots.html").write_text("\n".join(html))
print("wrote fastlane/screenshots and docs/screenshots.html")
PY
[ -z "$SKIP_CAPTURE" ] && xcrun simctl status_bar "$UDID" clear || true
