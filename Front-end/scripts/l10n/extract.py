#!/usr/bin/env python3
"""Collects every localizable string from the app + all local packages into App/Localizable.xcstrings.

    python3 scripts/l10n/extract.py            # build with extraction, merge new keys
    python3 scripts/l10n/extract.py --no-build # reuse the last extraction build
    python3 scripts/l10n/extract.py --report   # also list UI-looking literals that are NOT translatable

Keys come from the Swift compiler (SWIFT_EMIT_LOC_STRINGS): `Text("…")`, `Button("…")`, `L10n.tr("…")`,
`String(localized:)`, LocalizedStringKey parameters, with `%@`/`%lld` for interpolations.
Keys are stored with extractionState "manual" so Xcode never marks package strings as stale.
Keys that disappeared from the code are removed (with their translations) unless --keep-stale.
"""
import json, os, re, subprocess, sys, glob

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CATALOG = os.path.join(ROOT, "App", "Localizable.xcstrings")
DD = os.environ.get("L10N_DERIVED_DATA", "/tmp/gloop-l10n-dd")
MODULES = ["Gloop", "AlarmLiveActivity", "Features", "Missions", "Core", "Coach", "Permissions", "Buddies",
           "Purchases", "Account", "WidgetShared", "AlarmEngine", "Localization"]
# Not user-facing (telemetry, identifiers): never translated.
SKIP_DIRS = ("/Telemetry/",)
# Only developers see these: kept in the catalog but marked shouldTranslate = false.
DEV_ONLY = ("DeveloperView.swift", "SlimeGallery.swift", "WidgetPreviewsView.swift", "DebugSection.swift")


def build():
    cmd = ["xcodebuild", "-project", os.path.join(ROOT, "Gloop.xcodeproj"), "-scheme", "Gloop",
           "-destination", "generic/platform=iOS Simulator", "-derivedDataPath", DD,
           "SWIFT_EMIT_LOC_STRINGS=YES", "build"]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout[-4000:])
        sys.exit("build failed")


LOCATIONS = set()  # (relative source path, line) of every extracted literal


def collect():
    keys = {}
    for module in MODULES:
        for f in glob.glob(f"{DD}/Build/Intermediates.noindex/**/{module}.build/**/*.stringsdata", recursive=True):
            if "ExtractedAppShortcutsMetadata" in f:
                continue
            data = json.load(open(f))
            src = data.get("source", "")
            if any(s in src for s in SKIP_DIRS) or "/.build/" in src or "/StoreShots/" in src:
                continue
            for table, entries in data.get("tables", {}).items():
                if table != "Localizable":
                    continue
                for e in entries:
                    k = e["key"]
                    if not k.strip() or not re.search(r"[A-Za-z]", k):
                        continue
                    if " " not in k and re.search(r"[a-z][A-Z]", k) and "%" not in k:  # identifiers
                        continue
                    keys.setdefault(k, set()).add(os.path.relpath(src, ROOT))
                    LOCATIONS.add((os.path.relpath(src, ROOT), e["location"]["startingLine"], e["location"]["startingColumn"]))
    return keys


def merge(keys, keep_stale):
    cat = json.load(open(CATALOG)) if os.path.exists(CATALOG) else {"sourceLanguage": "en", "strings": {}, "version": "1.0"}
    strings = cat["strings"]
    added = [k for k in keys if k not in strings]
    for k in added:
        strings[k] = {}
    removed = []
    if not keep_stale:
        for k in list(strings):
            if k not in keys and not strings[k].get("comment", "").startswith("[keep]"):
                removed.append(k)
                del strings[k]
    for k, v in strings.items():
        v["extractionState"] = "manual"
        files = keys.get(k, set())
        if files and all(f.endswith(DEV_ONLY) for f in files):
            v["shouldTranslate"] = False
        else:
            v.pop("shouldTranslate", None)
    cat["strings"] = dict(sorted(strings.items(), key=lambda kv: kv[0]))
    with open(CATALOG, "w") as f:
        json.dump(cat, f, ensure_ascii=False, indent=2, separators=(",", " : "))
        f.write("\n")
    print(f"{len(keys)} keys in code, {len(added)} added, {len(removed)} removed")
    for k in removed[:40]:
        print("  - removed:", repr(k))


LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')


def report(keys):
    """UI-looking literals that the compiler did not extract (likely passed as String)."""
    out = {}
    for path in glob.glob(f"{ROOT}/Packages/*/Sources/**/*.swift", recursive=True) + glob.glob(f"{ROOT}/App/**/*.swift", recursive=True):
        if any(s in path for s in SKIP_DIRS) or "/.build/" in path or "/StoreShots/" in path:
            continue
        rel = os.path.relpath(path, ROOT)
        for n, line in enumerate(open(path), 1):
            s = line.strip()
            if s.startswith("//") or s.startswith("///") or "Logger" in s or "log." in s or "print(" in s \
                    or "forKey" in s or "systemImage" in s or "systemName" in s or "Telemetry" in s \
                    or "trackScreen" in s or "Image(" in s or "#Preview" in s or "rawValue" in s:
                continue
            for m in LITERAL.finditer(line):
                t = m.group(1)
                if "\\(" in t:
                    t2 = re.sub(r"\\\([^)]*\)", "", t)
                else:
                    t2 = t
                t2 = t2.strip().lstrip(".,:;—–- ")
                capital = re.match(r"^[A-Z¿¡\"'][a-z]", t2) is not None
                phrase = re.match(r"^[a-z]+ [a-z]+", t2) is not None
                if not (capital or phrase) or re.search(r"[./:_]", t2) and " " not in t2:
                    continue
                if re.match(r"^[a-z]+\.[a-z]", t) or t.startswith("http") or "_" in t and " " not in t:
                    continue
                if any((rel, n, m.start() + d) in LOCATIONS for d in (0, 1, 2)) or "L10n." in line[max(0, m.start() - 16):m.start()]:
                    continue
                out.setdefault(os.path.relpath(path, ROOT), []).append((n, t))
    total = 0
    for f in sorted(out):
        print(f"\n{f}")
        for n, t in out[f]:
            print(f"  {n}: {t}")
            total += 1
    print(f"\n{total} candidate literals not translatable")


if __name__ == "__main__":
    if "--no-build" not in sys.argv:
        build()
    keys = collect()
    if "--dry" not in sys.argv:
        merge(keys, "--keep-stale" in sys.argv)
    if "--report" in sys.argv:
        report(keys)
