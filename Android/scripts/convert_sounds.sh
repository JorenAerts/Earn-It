#!/bin/sh
# Converts the alarm tones generated for iOS (iOS/App/Sounds/Gloop_<name>.caf, made by
# iOS/scripts/generate_sounds.py) into AAC files for Android: res/raw/gloop_<snake_name>.m4a.
# One generator, the same tones on both platforms. Needs macOS (afconvert). Run from Android/:
#   scripts/convert_sounds.sh
set -e
src=../iOS/App/Sounds
out=app/src/main/res/raw
mkdir -p "$out"
for caf in "$src"/Gloop_*.caf; do
  name=$(basename "$caf" .caf | sed 's/^Gloop_//' | sed 's/\([A-Z]\)/_\1/g' | tr '[:upper:]' '[:lower:]')
  afconvert -f m4af -d aac "$caf" "$out/gloop_$name.m4a"
  echo "wrote $out/gloop_$name.m4a"
done
