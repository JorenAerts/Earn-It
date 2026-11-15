#!/usr/bin/env python3
"""Writes the in-app legal documents (Config/Legal/*.md, filled with Config/Legal.json) to
docs/legal/ at the repo root, ready to host (e.g. GitHub Pages) for the App Store Privacy Policy URL.

    python3 Front-end/scripts/export_legal.py
"""
import json, pathlib, re

front = pathlib.Path(__file__).resolve().parent.parent
values = {k: v for k, v in json.loads((front / "Config/Legal.json").read_text()).items() if not k.startswith("_")}
out = front.parent / "docs" / "legal"
out.mkdir(parents=True, exist_ok=True)

def fill(text):
    return re.sub(r"\{\{\s*(\w+)\s*\}\}", lambda m: (values.get(m.group(1)) or "").strip() or "[to be completed]", text)

for md in sorted((front / "Config/Legal").glob("*.md")):
    (out / md.name).write_text(fill(md.read_text()))
    print("wrote", (out / md.name).relative_to(front.parent))
