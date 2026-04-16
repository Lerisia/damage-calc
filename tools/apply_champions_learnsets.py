#!/usr/bin/env python3
"""
Replace learnset entries for Champions-confirmed Pokemon in
assets/learnsets.json using scraped Champions data from yakkun.

For Pokemon that appear in Champions (by dex number), the Champions move
list overrides the existing (Showdown-derived) learnset. Pokemon absent
from Champions keep their existing learnset untouched.

Input:  assets/champions_learnsets_raw.json (scraped Japanese data)
        assets/moves/*.json                 (for JA -> Showdown move ID)
        assets/pokemon/*.json               (for dex -> Showdown pokemon ID)
Output: assets/learnsets.json               (overwritten)

Pokemon ID resolution: uses the base entry for each dex number (the
pokedex entry without a form suffix like Mega / Alolan). Champions
treats forms as distinct entities but learnsets.json is keyed by base
species only, so we merge all forms of the same dex into a single
union move set.
"""

import json
import re
import sys
import unicodedata
from glob import glob
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW_PATH = ROOT / "tools" / "data" / "champions_learnsets_raw.json"
LEARNSETS_PATH = ROOT / "assets" / "learnsets.json"
POKEMON_DIR = ROOT / "assets" / "pokemon"
MOVES_DIR = ROOT / "assets" / "moves"


def showdown_id(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


def nfkc(s: str) -> str:
    return unicodedata.normalize("NFKC", s)


def build_move_map() -> dict[str, str]:
    """NFKC-normalized Japanese move name -> Showdown move ID."""
    result: dict[str, str] = {}
    for path in sorted(MOVES_DIR.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        for m in data:
            ja = m.get("nameJa")
            en = m.get("name")
            if ja and en:
                result[nfkc(ja)] = showdown_id(en)
    return result


def build_dex_map() -> dict[int, str]:
    """Dex number -> Showdown pokemon ID (using base-form English name).

    When multiple entries share a dex number, the entry with no formId
    (the base) wins; otherwise the first seen entry is used.
    """
    base: dict[int, str] = {}
    fallback: dict[int, str] = {}
    for path in sorted(POKEMON_DIR.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        entries = data if isinstance(data, list) else data.get("pokemon", [])
        for p in entries:
            dex = p.get("dexNumber")
            en = p.get("name")
            if not dex or not en:
                continue
            sid = showdown_id(en)
            if "formId" not in p and dex not in base:
                base[dex] = sid
            elif dex not in fallback:
                fallback[dex] = sid
    # merge
    for dex, sid in fallback.items():
        base.setdefault(dex, sid)
    return base


def main() -> int:
    raw = json.loads(RAW_PATH.read_text(encoding="utf-8"))
    move_map = build_move_map()
    dex_map = build_dex_map()
    learnsets = json.loads(LEARNSETS_PATH.read_text(encoding="utf-8"))

    # Group Champions moves by dex number (union across forms).
    dex_moves: dict[int, set[str]] = {}
    dex_names_ja: dict[int, list[str]] = {}
    missing_moves: set[str] = set()
    for entry in raw.values():
        dex = entry["dex"]
        dex_names_ja.setdefault(dex, []).append(entry["name_ja"])
        target = dex_moves.setdefault(dex, set())
        for ja in entry["moves_ja"]:
            key = nfkc(ja)
            show_id = move_map.get(key)
            if not show_id:
                missing_moves.add(ja)
                continue
            target.add(show_id)

    if missing_moves:
        print(f"WARN: {len(missing_moves)} moves without Showdown ID mapping:")
        for ja in sorted(missing_moves):
            print(f"  {ja}")

    # Replace learnsets for each Champions-confirmed dex
    replaced = 0
    no_pokemon_map = []
    no_learnset_entry = []
    for dex, moves in sorted(dex_moves.items()):
        sid = dex_map.get(dex)
        if not sid:
            no_pokemon_map.append((dex, dex_names_ja[dex]))
            continue
        if sid not in learnsets:
            no_learnset_entry.append((dex, sid))
        learnsets[sid] = sorted(moves)
        replaced += 1

    print(f"Replaced learnsets for {replaced} dex entries.")
    if no_pokemon_map:
        print(f"WARN: {len(no_pokemon_map)} Champions dex numbers had no pokedex entry:")
        for dex, names in no_pokemon_map[:20]:
            print(f"  {dex}: {names}")
    if no_learnset_entry:
        print(f"INFO: {len(no_learnset_entry)} new IDs added to learnsets.json "
              "(dex had no prior entry).")
        for dex, sid in no_learnset_entry[:20]:
            print(f"  {dex} ({sid})")

    LEARNSETS_PATH.write_text(
        json.dumps(learnsets, separators=(",", ":"), ensure_ascii=False),
        encoding="utf-8",
    )
    print(f"Wrote {LEARNSETS_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
