#!/usr/bin/env python3
"""Build the Champions-legal move allowlist from the game's own data.

Champions ships a restricted move roster — a subset of the national-dex
movepool. projectpokemon/champout dumps it straight from the ROM as
parse/move_availability.txt (one `<id>\\t<English name>` per line), so
the allowlist is exact and updates the same day a patch lands. Until
2026-09-09 this scraped yakkun's move list instead, which lagged the
game by days and needed a hand-maintained additions list.

Output: assets/champions_moves.json
  {
    "_meta": { "source": ..., "updatedAt": ..., "count": N },
    "moves": ["Earthquake", "Moonblast", ...]   // English keys, sorted
  }

Usage:
    python3 tools/fetch_champions_moves.py

Names are matched to our movedex by exact English name; a name that
doesn't match is reported and omitted, and an implausibly short list
aborts rather than shipping a truncated allowlist that would hide legal
moves.
"""
from __future__ import annotations

import json
import sys
import time
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MOVES_DIR = REPO / "assets" / "moves"
OUT_PATH = REPO / "assets" / "champions_moves.json"

URL = ("https://raw.githubusercontent.com/projectpokemon/champout/main/"
       "parse/move_availability.txt")
MIN_PLAUSIBLE = 450


def fetch_rom_names() -> list[str]:
    req = urllib.request.Request(URL, headers={"User-Agent": "damage-calc/1"})
    with urllib.request.urlopen(req, timeout=30) as r:
        text = r.read().decode("utf-8")
    names = []
    for line in text.splitlines():
        if "\t" in line:
            names.append(line.split("\t", 1)[1].strip())
    return names


def movedex_names() -> set[str]:
    out: set[str] = set()
    for f in sorted(MOVES_DIR.glob("*.json")):
        for m in json.loads(f.read_text(encoding="utf-8")):
            out.add(m["name"])
    return out


def main() -> int:
    print(f"fetching {URL} …")
    rom = fetch_rom_names()
    print(f"ROM move roster: {len(rom)}")
    if len(rom) < MIN_PLAUSIBLE:
        print(f"ABORT: only {len(rom)} moves (< {MIN_PLAUSIBLE}) — "
              "file format likely changed, not overwriting.")
        return 1

    known = movedex_names()
    english = sorted(n for n in rom if n in known)
    unmatched = sorted(n for n in rom if n not in known)
    if unmatched:
        print(f"WARN {len(unmatched)} ROM moves not in our movedex (omitted):")
        for u in unmatched:
            print(f"  {u}")

    payload = {
        "_meta": {
            "source": "projectpokemon/champout parse/move_availability.txt (ROM)",
            "updatedAt": time.strftime("%Y-%m-%d"),
            "count": len(english),
        },
        "moves": english,
    }
    OUT_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {OUT_PATH} ({len(english)} moves)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
