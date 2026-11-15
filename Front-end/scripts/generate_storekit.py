#!/usr/bin/env python3
"""Generate Config/Gloop.storekit (Xcode local StoreKit testing) from Config/Pricing.json.

Pricing.json is the single place to change plans and prices. After editing it run:
    python3 scripts/generate_storekit.py
Every subscription gets the free-trial introductory offer of `trialDays` days.
Real App Store prices must be mirrored in App Store Connect (same product IDs).
"""
import json
import pathlib
import uuid

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "Config" / "Pricing.json"
OUT = ROOT / "Config" / "Gloop.storekit"

def stable_id(*parts):
    """Deterministic IDs so regenerating doesn't churn the file."""
    return str(uuid.uuid5(uuid.NAMESPACE_URL, "gloop:" + ":".join(parts))).upper()

def localization(title, description):
    return [{"description": description, "displayName": title, "locale": "en_US"}]

def main():
    cfg = json.loads(SRC.read_text())
    products = [p for p in cfg["products"] if p["enabled"]]
    group_id = stable_id("group", cfg["subscriptionGroup"])
    trial = f"P{int(cfg['trialDays'])}D" if cfg.get("trialDays") else None

    # Longer period = higher service level (groupNumber 1 is the highest).
    order = {"P1Y": 1, "P6M": 2, "P3M": 3, "P2M": 4, "P1M": 5, "P1W": 6}
    subs, one_time = [], []
    for p in products:
        price = f"{p['price']:.2f}"
        if p["type"] == "subscription":
            subs.append({
                "adHocOffers": [], "codeOffers": [], "winbackOffers": [],
                "displayPrice": price,
                "familyShareable": False,
                "groupNumber": order.get(p["period"], 9),
                "internalID": stable_id("sub", p["id"]),
                "introductoryOffer": None if not trial else {
                    "internalID": stable_id("intro", p["id"]),
                    "paymentMode": "free",
                    "subscriptionPeriod": trial,
                },
                "localizations": localization(f"Gloop Pro – {p['title']}", "All alarms, missions and sounds."),
                "productID": p["id"],
                "recurringSubscriptionPeriod": p["period"],
                "referenceName": f"Pro {p['title']}",
                "subscriptionGroupID": group_id,
                "type": "RecurringSubscription",
            })
        elif p["type"] == "lifetime":
            one_time.append({
                "displayPrice": price,
                "familyShareable": False,
                "internalID": stable_id("lifetime", p["id"]),
                "localizations": localization("Gloop Pro – Lifetime", "Unlock Pro forever, one payment."),
                "productID": p["id"],
                "referenceName": "Pro Lifetime",
                "type": "NonConsumable",
            })

    storekit = {
        "identifier": stable_id("config"),
        "nonRenewingSubscriptions": [],
        "products": one_time,
        "settings": {"_storefront": cfg.get("storefront", "BEL"), "_locale": "en_BE"},
        "subscriptionGroups": [] if not subs else [{
            "id": group_id,
            "localizations": [],
            "name": cfg["subscriptionGroup"],
            "subscriptions": sorted(subs, key=lambda s: s["groupNumber"]),
        }],
        "version": {"major": 4, "minor": 0},
    }
    OUT.write_text(json.dumps(storekit, indent=2) + "\n")
    print(f"wrote {OUT.relative_to(ROOT)}: {len(subs)} subscriptions, {len(one_time)} one-time")

if __name__ == "__main__":
    main()
