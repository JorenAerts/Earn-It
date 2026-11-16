#!/bin/sh
# Generates the App Store screenshots from the real app (DEBUG scenes with demo data).
#   cd iOS && scripts/screenshots/make.sh
# Output: fastlane/screenshots/{en-US,en-GB}/<id>-6.9.png (1320×2868) and -6.5.png (1284×2778),
# plus ../docs/screenshots.html to review them.
set -e
cd "$(dirname "$0")/../.."
ROOT=$(pwd)
WORK="${TMPDIR:-/tmp}/gloop-screenshots"
RAW="$WORK/raw"; mkdir -p "$RAW"
DEVICE="Gloop Screenshots 6.9"
TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"

UDID=$(xcrun simctl list devices | grep "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
if [ -z "$UDID" ]; then UDID=$(xcrun simctl create "$DEVICE" "$TYPE"); fi
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 --operatorName ""

echo "Building…"
xcodebuild -project Gloop.xcodeproj -scheme Gloop -destination "id=$UDID" -derivedDataPath "$WORK/dd" build -quiet
xcrun simctl install "$UDID" "$WORK/dd/Build/Products/Debug-iphonesimulator/Gloop.app"

echo "Compiling composer…"
swiftc -parse-as-library -O scripts/screenshots/compose.swift -o "$WORK/compose"

python3 - "$UDID" "$RAW" "$WORK/compose" "$ROOT" <<'PY'
import json, subprocess, sys, time, pathlib
udid, raw, compose, root = sys.argv[1:5]
root = pathlib.Path(root)
scenes = json.loads((root / "scripts/screenshots/scenes.json").read_text())["scenes"]
sizes = {"6.9": (1320, 2868), "6.5": (1284, 2778)}
html = ['<!doctype html><meta charset="utf-8"><title>Gloop screenshots</title>',
        '<style>body{font-family:-apple-system;background:#222;color:#eee;margin:24px}'
        '.row{display:flex;gap:16px;overflow-x:auto}img{height:520px;border-radius:12px}</style>']
for locale in ["en-US", "en-GB"]:
    out = root / "fastlane/screenshots" / locale
    out.mkdir(parents=True, exist_ok=True)
    html.append(f"<h2>{locale}</h2><div class=row>")
    for s in scenes:
        shot = pathlib.Path(raw) / f"{s['id']}.png"
        if locale == "en-US":
            subprocess.run(["xcrun", "simctl", "terminate", udid, "be.gloop.app"], capture_output=True)
            subprocess.run(["xcrun", "simctl", "launch", udid, "be.gloop.app", *s["args"]], check=True, capture_output=True)
            time.sleep(9)
            subprocess.run(["xcrun", "simctl", "io", udid, "screenshot", str(shot)], check=True, capture_output=True)
            print("captured", s["id"])
        headline = s.get("headline_" + locale.replace("-", "_"), s["headline"])
        for name, (w, h) in sizes.items():
            target = out / f"{s['id']}-{name}.png"
            subprocess.run([compose, str(shot), str(target), str(w), str(h), headline, s.get("accent", "")], check=True)
        rel = (out / f"{s['id']}-6.9.png").relative_to(root.parent)
        html.append(f'<img src="../{rel}">')
    html.append("</div>")
(root.parent / "docs/screenshots.html").write_text("\n".join(html))
print("wrote fastlane/screenshots and docs/screenshots.html")
PY
xcrun simctl status_bar "$UDID" clear
