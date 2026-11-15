#!/bin/sh
# Renders the app icons (see render_icons.swift). Run from Front-end/.
set -e
OUT="${TMPDIR:-/tmp}/gloop-render-icons"
swiftc -parse-as-library -O scripts/render_icons.swift \
  Packages/WidgetShared/Sources/WidgetShared/Slime/SlimeDrawing.swift -o "$OUT"
"$OUT"
