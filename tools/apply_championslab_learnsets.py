#!/usr/bin/env python3
"""
Apply Pokemon Champions learnsets from ChampionsLab (Andrew21P/ChampionsLab)
to assets/learnsets.json.

ChampionsLab is datamine-sourced community-curated data. Source:
https://github.com/Andrew21P/ChampionsLab

This replaces yakkun-based data which was merging SV+past-game movepools.

Input:  tools/data/championslab.json (parsed from upstream pokemon-data.ts)
Output: assets/learnsets.json

For each entry in ChampionsLab:
- Derive Showdown ID (base English name + form suffix)
- Convert move names to Showdown move IDs
- Overwrite the matching learnsets.json key

Pokemon not present in ChampionsLab keep their existing learnsets untouched.
"""

import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CL_JSON = ROOT / "tools" / "data" / "championslab.json"
LEARNSETS = ROOT / "assets" / "learnsets.json"

CHAMPIONSLAB_TS_URL = (
    "https://raw.githubusercontent.com/Andrew21P/ChampionsLab/main/src/lib/pokemon-data.ts"
)


def refresh_from_upstream() -> None:
    """Download the latest pokemon-data.ts and parse it into championslab.json."""
    print(f"Fetching {CHAMPIONSLAB_TS_URL}")
    req = urllib.request.Request(CHAMPIONSLAB_TS_URL, headers={"User-Agent": "Mozilla/5.0"})
    ts = urllib.request.urlopen(req).read().decode("utf-8")
    match = re.search(r"export const POKEMON_SEED[^=]*=\s*(\[[\s\S]*?\n\];)", ts)
    if not match:
        raise RuntimeError("Could not locate POKEMON_SEED array in upstream TS")
    # Strip trailing semicolon + trailing commas (TS permits them, JSON doesn't).
    raw = match.group(1).rstrip(";").strip()
    cleaned = re.sub(r",(\s*[}\]])", r"\1", raw)
    data = json.loads(cleaned)
    CL_JSON.parent.mkdir(parents=True, exist_ok=True)
    CL_JSON.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    print(f"Cached {len(data)} entries to {CL_JSON}")


def showdown_id(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


# Explicit mapping for names whose Showdown key diverges from naive lowering.
# Key = ChampionsLab name. Value = Showdown-style learnset key.
NAME_OVERRIDES: dict[str, str] = {
    # Regional forms: "Hisuian X" -> "xhisui" etc.
    # (handled generically below but listed for clarity / exceptions)
    "Paldean Tauros": "taurospaldeacombat",
    "Paldean Tauros (Blaze)": "taurospaldeablaze",
    "Paldean Tauros (Aqua)": "taurospaldeaaqua",
    # Rotom appliances
    "Heat Rotom": "rotomheat",
    "Wash Rotom": "rotomwash",
    "Frost Rotom": "rotomfrost",
    "Fan Rotom": "rotomfan",
    "Mow Rotom": "rotommow",
    # Gendered species: Showdown treats male as the base key.
    "Meowstic-M": "meowstic",
    "Meowstic-F": "meowsticf",
    "Basculegion-M": "basculegion",
    "Basculegion-F": "basculegionf",
}


def derive_showdown_key(cl_name: str) -> str | None:
    if cl_name in NAME_OVERRIDES:
        return NAME_OVERRIDES[cl_name]

    # "Hisuian X" -> "xhisui"
    for prefix, suffix in [
        ("Hisuian ", "hisui"),
        ("Alolan ", "alola"),
        ("Galarian ", "galar"),
    ]:
        if cl_name.startswith(prefix):
            base = cl_name[len(prefix):]
            return showdown_id(base) + suffix
    return showdown_id(cl_name)


def main() -> int:
    if "--refresh" in sys.argv or not CL_JSON.exists():
        refresh_from_upstream()
    cl = json.loads(CL_JSON.read_text(encoding="utf-8"))
    learnsets = json.loads(LEARNSETS.read_text(encoding="utf-8"))

    unmapped: list[str] = []
    new_keys: list[str] = []
    replaced = 0
    for entry in cl:
        key = derive_showdown_key(entry["name"])
        if key is None:
            unmapped.append(entry["name"])
            continue
        move_ids = sorted({showdown_id(m["name"]) for m in entry.get("moves", [])})
        if key not in learnsets:
            new_keys.append(key)
        learnsets[key] = move_ids
        replaced += 1

    print(f"Replaced {replaced} learnset entries from ChampionsLab.")
    if unmapped:
        print(f"WARN: {len(unmapped)} entries with no mapping: {unmapped[:10]}")
    if new_keys:
        print(f"INFO: {len(new_keys)} new keys added to learnsets.json:")
        for k in new_keys:
            print(f"  {k}")

    LEARNSETS.write_text(
        json.dumps(learnsets, separators=(",", ":"), ensure_ascii=False),
        encoding="utf-8",
    )
    print(f"Wrote {LEARNSETS}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
