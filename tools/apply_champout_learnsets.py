#!/usr/bin/env python3
"""Pull Champions learnsets from projectpokemon/champout — the ROM-
direct data dump — and apply them to assets/learnsets.json.

Why this over ChampionsLab:
  ChampionsLab's learnsets came from someone's manual curation and
  carried subtle errors (e.g. Metagross with Heavy Slam / Ally Switch,
  neither of which the ROM actually grants). champout extracts species
  movepool data straight from the game's `personal_dump` so it matches
  in-game behaviour exactly.

Input:  https://raw.githubusercontent.com/projectpokemon/champout/main/parse/species_with_move.txt
Output: assets/learnsets.json (replaces 200+ species entries)

The file is shipped as an inverse index (Move → species list); we
flip it to species → moves and reduce to our Showdown-style keys.
Mega forms (`-Mega`, `-Mega X`, `-Mega Y`) are skipped because our
learnsets are keyed by base form only — megas mirror at lookup time
(see project_mega_mirror_policy memory). Regional / form variants
get our existing showdown-style suffixes (alola, hisui, galar, paldea
breed names, etc.).

Run:    python3 tools/apply_champout_learnsets.py
"""
from __future__ import annotations

import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEARNSETS = ROOT / "assets" / "learnsets.json"
CHAMPOUT_URL = (
    "https://raw.githubusercontent.com/projectpokemon/champout/main/"
    "parse/species_with_move.txt"
)


def showdown_id(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


# Explicit mappings for species names whose Showdown key diverges from
# naive lowering. champout uses dash-suffixed forms ("Tauros-Paldea Combat",
# "Meowstic-F", etc.) — line them up with our Showdown keys here.
NAME_OVERRIDES: dict[str, str] = {
    # Paldean Tauros breeds — Showdown uses suffixed paldeablaze/aqua/combat
    "Tauros-Paldea Combat": "taurospaldeacombat",
    "Tauros-Paldea Blaze": "taurospaldeablaze",
    "Tauros-Paldea Aqua": "taurospaldeaaqua",
    # Rotom appliances — Showdown puts the form first ("rotomheat")
    "Rotom-Heat": "rotomheat",
    "Rotom-Wash": "rotomwash",
    "Rotom-Frost": "rotomfrost",
    "Rotom-Fan": "rotomfan",
    "Rotom-Mow": "rotommow",
    # Gendered split species — Showdown treats male as the base key
    "Meowstic-M": "meowstic",
    "Meowstic-F": "meowsticf",
    "Basculegion-M": "basculegion",
    "Basculegion-F": "basculegionf",
    "Indeedee-M": "indeedee",
    "Indeedee-F": "indeedeef",
    # Other format anomalies
    "Floette-Eternal": "floetteeternal",
    "Nidoran-M": "nidoranm",
    "Nidoran-F": "nidoranf",
    "Vivillon-Fancy": "vivillonfancy",
    "Vivillon-Poke Ball": "vivillonpokeball",
}

# Species suffix → Showdown form suffix. Applied AFTER NAME_OVERRIDES so
# explicit cases above win.
SUFFIX_MAP: list[tuple[str, str]] = [
    # champout suffix, Showdown suffix
    ("-Alolan", "alola"),
    ("-Hisuian", "hisui"),
    ("-Galarian", "galar"),
    ("-Paldea", "paldea"),
    ("-Origin", "origin"),
    ("-Therian", "therian"),
    ("-White", "white"),
    ("-Black", "black"),
    ("-Resolute", "resolute"),
    ("-Pirouette", "pirouette"),
    ("-Sky", "sky"),
    ("-Sunshine", "sunshine"),
    ("-Eternal", "eternal"),
    ("-Blade", "blade"),
    ("-Shield", "shield"),
    ("-Crowned", "crowned"),
    ("-Sunny", "sunny"),
    ("-Rainy", "rainy"),
    ("-Snowy", "snowy"),
    ("-Dusk", "dusk"),
    ("-Midnight", "midnight"),
    ("-Dusk-Mane", "duskmane"),
    ("-Dawn-Wings", "dawnwings"),
    ("-Ultra", "ultra"),
    ("-Heat", "heat"),
    ("-Frost", "frost"),
    ("-Fan", "fan"),
    ("-Wash", "wash"),
    ("-Mow", "mow"),
    ("-Hero", "hero"),
    ("-Single-Strike", "singlestrike"),
    ("-Rapid-Strike", "rapidstrike"),
    ("-Ice", "ice"),
    ("-Shadow", "shadow"),
    ("-Stellar", "stellar"),
    ("-Terastal", "terastal"),
    # Sizes (Gourgeist, Pumpkaboo)
    ("-Small", "small"),
    ("-Large", "large"),
    ("-Super", "super"),
]


def to_showdown_key(name: str) -> str | None:
    """Map a champout species name to our Showdown-style learnset key,
    or None if the species should be skipped (Mega forms)."""
    if name in NAME_OVERRIDES:
        return NAME_OVERRIDES[name]
    # Skip ALL Mega forms — our learnsets are base-only; megas mirror
    if "-Mega" in name:
        return None
    # Apply suffix transformations
    for champ_suffix, sd_suffix in SUFFIX_MAP:
        if name.endswith(champ_suffix):
            base = name[: -len(champ_suffix)]
            return showdown_id(base) + sd_suffix
    return showdown_id(name)


def fetch_champout() -> str:
    print(f"Fetching {CHAMPOUT_URL}")
    req = urllib.request.Request(
        CHAMPOUT_URL,
        headers={"User-Agent": "Mozilla/5.0"},
    )
    return urllib.request.urlopen(req, timeout=30).read().decode("utf-8")


def parse_inverse(text: str) -> dict[str, list[str]]:
    """Parse 'Move: X / - Species' format → {species: [moves]}."""
    species_to_moves: dict[str, list[str]] = {}
    current_move: str | None = None
    for raw in text.splitlines():
        line = raw.rstrip()
        if line.startswith("Move: "):
            current_move = line[6:].strip()
        elif line.startswith("- ") and current_move:
            species = line[2:].strip()
            species_to_moves.setdefault(species, []).append(current_move)
    return species_to_moves


def main() -> int:
    text = fetch_champout()
    species_to_moves = parse_inverse(text)
    print(f"Parsed {len(species_to_moves)} species, "
          f"{sum(len(v) for v in species_to_moves.values())} learn-edges")

    learnsets = json.loads(LEARNSETS.read_text(encoding="utf-8"))

    replaced = 0
    added = 0
    skipped_mega = 0
    unmapped: list[str] = []

    for sp_name, moves in species_to_moves.items():
        key = to_showdown_key(sp_name)
        if key is None:
            skipped_mega += 1
            continue
        move_ids = sorted({showdown_id(m) for m in moves})
        if key in learnsets:
            if learnsets[key] != move_ids:
                replaced += 1
        else:
            added += 1
            unmapped.append(f"{sp_name} -> {key}")
        learnsets[key] = move_ids

    LEARNSETS.write_text(
        json.dumps(learnsets, separators=(",", ":"), ensure_ascii=False),
        encoding="utf-8",
    )

    print()
    print(f"replaced:     {replaced}")
    print(f"added (new):  {added}")
    print(f"skipped Mega: {skipped_mega}")
    if unmapped[:10]:
        print(f"first added keys (verify they map to real Showdown ids):")
        for entry in unmapped[:10]:
            print(f"  {entry}")
    print(f"Wrote {LEARNSETS}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
