#!/usr/bin/env python3
"""Build the Champions-legal held-item allowlist from the game's own data.

Champions ships a restricted item roster (166 held items as of v1.2.0 —
no Choice Band / Specs, no Assault Vest, …). projectpokemon/champout
dumps the ROM's item table as masterdata/item.json (numeric ids, no
names) and the item-name text as rom-txt/usa/itemname.json
(`ITEMNAME_<id>` → English), so joining the two gives the exact roster
and it updates the same day a patch lands.

Output: assets/champions_items.json
  {
    "_meta": { "source": ..., "updatedAt": ..., "count": N },
    "items": ["absorb-bulb", "aguav-berry", ...]   // items.json slugs, sorted
  }

Usage:
    python3 tools/fetch_champions_items.py

ROM names are matched to assets/items.json by English name (apostrophes
normalised — the ROM writes King’s Rock with a curly quote), falling
back to the slug form. Unmatched names are reported and omitted; an
implausibly short roster aborts rather than shipping a truncated list
that would hide legal items from the pickers.
"""
from __future__ import annotations

import json
import re
import sys
import time
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ITEMS_PATH = REPO / "assets" / "items.json"
OUT_PATH = REPO / "assets" / "champions_items.json"

BASE = "https://raw.githubusercontent.com/projectpokemon/champout/main/"
MASTER_URL = BASE + "masterdata/item.json"
NAMES_URL = BASE + "rom-txt/usa/itemname.json"
MIN_PLAUSIBLE = 100


def fetch_json(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": "damage-calc/1"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def norm(s: str) -> str:
    return s.replace("’", "'").strip().lower()


def slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", norm(s).replace("'", "")).strip("-")


def rom_item_names() -> dict[int, str]:
    """id → English name for every item in the ROM's item table."""
    master = fetch_json(MASTER_URL)
    names: dict[int, str] = {}
    for e in fetch_json(NAMES_URL)["mSDataSet"]:
        m = re.match(r"ITEMNAME_(\d+)$", e.get("LabelName", ""))
        if m:
            names[int(m.group(1))] = e["OriginalText"]
    out: dict[int, str] = {}
    for it in master:
        i = int(it["id"])
        if i in names:
            out[i] = names[i]
        else:
            print(f"WARN ROM item id {i} has no English name entry")
    return out


def main() -> int:
    print(f"fetching {MASTER_URL} + {NAMES_URL} …")
    rom = rom_item_names()
    print(f"ROM item roster: {len(rom)}")
    if len(rom) < MIN_PLAUSIBLE:
        print(f"ABORT: only {len(rom)} items (< {MIN_PLAUSIBLE}) — "
              "file format likely changed, not overwriting.")
        return 1

    ours = json.loads(ITEMS_PATH.read_text(encoding="utf-8"))
    by_en = {norm(i["nameEn"]): i["name"] for i in ours if i.get("nameEn")}
    by_slug = {i["name"]: i["name"] for i in ours}

    matched: set[str] = set()
    unmatched: list[str] = []
    for _id, name in sorted(rom.items()):
        key = by_en.get(norm(name)) or by_slug.get(slug(name))
        if key:
            matched.add(key)
        else:
            unmatched.append(f"{_id}\t{name}")
    if unmatched:
        print(f"WARN {len(unmatched)} ROM items not in assets/items.json (omitted):")
        for u in unmatched:
            print(f"  {u}")

    payload = {
        "_meta": {
            "source": "projectpokemon/champout masterdata/item.json + "
                      "rom-txt/usa/itemname.json (ROM)",
            "updatedAt": time.strftime("%Y-%m-%d"),
            "count": len(matched),
        },
        "items": sorted(matched),
    }
    OUT_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {OUT_PATH} ({len(matched)} items)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
