#!/usr/bin/env python3
"""Merges scripts/l10n/translations/<code>.json into App/Localizable.xcstrings.

    python3 scripts/l10n/apply.py          # all languages
    python3 scripts/l10n/apply.py nl fr    # some

Translation file: {"<English key>": "<translation>" | {"one": …, "few": …, "many": …, "other": …}}.
Keys starting with "_" are comments. Keys not (or no longer) in the catalog are reported and skipped.
AI translations are stored with state "needs_review" (shown as such in Xcode) unless the file has
"_reviewed": true. Run extract.py first so the catalog has every key.
"""
import json, os, re, sys, glob

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CATALOG = os.path.join(ROOT, "App", "Localizable.xcstrings")
DIR = os.path.join(ROOT, "scripts", "l10n", "translations")
PLACEHOLDER = re.compile(r"%(?:\d\$)?(?:lld|ld|d|@|lf|f|%)")


def unit(value, state):
    return {"stringUnit": {"state": state, "value": value}}


def placeholders(s):
    return sorted(p for p in PLACEHOLDER.findall(s) if p != "%%")


def apply(code, cat):
    data = json.load(open(os.path.join(DIR, f"{code}.json")))
    state = "translated" if data.get("_reviewed") or code == "en" else "needs_review"
    strings = cat["strings"]
    unknown, bad = [], []
    for key, value in data.items():
        if key.startswith("_"):
            continue
        if key not in strings:
            unknown.append(key)
            continue
        forms = value if isinstance(value, dict) else {"other": value}
        expected = placeholders(key)
        for form, text in forms.items():
            got = placeholders(text)
            # "one" may drop the number ("every day"); otherwise placeholders must match.
            if got != expected and not (form in ("one", "zero") and set(got) <= set(expected)):
                bad.append((key, form, text))
        loc = strings[key].setdefault("localizations", {})
        if isinstance(value, dict):
            loc[code] = {"variations": {"plural": {f: unit(t, state) for f, t in value.items()}}}
        else:
            loc[code] = unit(value, state)
    return unknown, bad


def main():
    codes = [a for a in sys.argv[1:] if not a.startswith("-")] or sorted(os.path.splitext(os.path.basename(f))[0] for f in glob.glob(f"{DIR}/*.json"))
    cat = json.load(open(CATALOG))
    ok = True
    for code in codes:
        unknown, bad = apply(code, cat)
        missing = [k for k, v in cat["strings"].items() if code != "en" and v.get("shouldTranslate", True) and code not in v.get("localizations", {})]
        print(f"{code}: {len(missing)} missing, {len(unknown)} unknown keys, {len(bad)} placeholder mismatches")
        for k in unknown[:20]:
            print("   unknown:", repr(k))
        for k, f, t in bad:
            print("   PLACEHOLDERS:", repr(k), f, repr(t))
            ok = False
        if code != "en" and "-v" in sys.argv[1:]:
            for k in missing:
                print("   missing:", repr(k))
    with open(CATALOG, "w") as f:
        json.dump(cat, f, ensure_ascii=False, indent=2, separators=(",", " : "))
        f.write("\n")
    # Info.plist texts (permission prompts): scripts/l10n/infoplist.json → App/InfoPlist.xcstrings
    info_path = os.path.join(ROOT, "App", "InfoPlist.xcstrings")
    info = json.load(open(info_path))
    for code, values in json.load(open(os.path.join(ROOT, "scripts", "l10n", "infoplist.json"))).items():
        if code.startswith("_"):
            continue
        for key, value in values.items():
            if key in info["strings"]:
                info["strings"][key]["localizations"][code] = unit(value, "needs_review")
    for key in ("CFBundleName",):  # added by Xcode; the app name is never translated
        if key in info["strings"]:
            info["strings"][key]["shouldTranslate"] = False
    with open(info_path, "w") as f:
        json.dump(info, f, ensure_ascii=False, indent=2, separators=(",", " : "))
        f.write("\n")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
