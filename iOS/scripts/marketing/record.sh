#!/bin/sh
# Records a Simulator video of a demo scene for social posts → ../docs/marketing/videos/<name>.mov
# Uses the "Gloop Screenshots 6.9" simulator and the app installed by scripts/screenshots/make.sh.
#
#   cd iOS && scripts/marketing/record.sh <name> <seconds> <launch args…>
#   scripts/marketing/record.sh missions 8 -storeShot missionGrid
#   scripts/marketing/record.sh rering 10 -missionRunner math
#   scripts/marketing/record.sh success 6 -storeShot success -language nl
#   scripts/marketing/record.sh slimes 10 -slimeGallery
#   scripts/marketing/record.sh buddies 8 -buddiesSample -buddiesClub
# Interact with the Simulator while it records (tap through a mission, scroll). Vertical 9:16 video,
# ready for CapCut / TikTok. Run scripts/screenshots/make.sh once first so the app is installed.
set -e
[ $# -ge 2 ] || { sed -n '2,12p' "$0"; exit 1; }
cd "$(dirname "$0")/../.."
NAME=$1; SECONDS_LONG=$2; shift 2
UDID=$(xcrun simctl list devices | grep "Gloop Screenshots 6.9 (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$UDID" ] || { echo "Run scripts/screenshots/make.sh first (creates the simulator + installs the app)."; exit 1; }
xcrun simctl boot "$UDID" 2>/dev/null || true
open "$(xcode-select -p)/Applications/Simulator.app" || true
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
OUT=../docs/marketing/videos; mkdir -p "$OUT"
xcrun simctl terminate "$UDID" be.gloop.app 2>/dev/null || true
xcrun simctl launch "$UDID" be.gloop.app "$@" >/dev/null
sleep 2
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT/$NAME.mov" &
REC=$!
sleep "$SECONDS_LONG"
kill -INT $REC; wait $REC 2>/dev/null || true
xcrun simctl status_bar "$UDID" clear
echo "wrote docs/marketing/videos/$NAME.mov"
