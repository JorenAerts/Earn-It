#!/bin/sh
# Gloop stickers (transparent PNGs) for social posts → ../docs/marketing/gloop/. Run from iOS/.
set -e
cd "$(dirname "$0")/../.."
OUT="${TMPDIR:-/tmp}/gloop-render-stickers"
swiftc -parse-as-library -O scripts/marketing/render_gloop.swift \
  Packages/WidgetShared/Sources/WidgetShared/Slime/SlimeDrawing.swift -o "$OUT"
"$OUT" ../docs/marketing/gloop
