#!/usr/bin/env python3
"""Merge pochammon.com SP-spread usage stats into champions_usage.json.

The Pokémon Champions in-game Battle Data exposes, per species, the
most-adopted stat-point (SP) spreads. pochammon.com surfaces them at
`/api/stats/ranking` as `sp_spreads` (ranked by use rate). This script
fetches the rank-1 spread for every species and writes it back into
`assets/champions_usage.json` as a `defaultSp` field, so loading a
Pokémon can pre-fill the community's most-used build.

Run from the repo root:  python3 tools/fetch_pochammon_sp.py

The merge is a surgical text insertion — it does NOT re-serialise the
JSON, so the hand-tuned formatting (2-space indent, compact
`{"name": ...}` rows, blank lines between entries) is preserved and
the diff stays small. Re-running refreshes every `defaultSp` line.
"""
import json
import re
import sys
import urllib.request

API = "https://pochammon.com/api"
USAGE_PATH = "assets/champions_usage.json"

# pochammon `name_en` (PokeAPI-style slug) → champions_usage.json key.
# Only needed for forms whose display name doesn't normalise cleanly;
# base species match automatically (case/space/hyphen-insensitive).
ALIAS = {
    "basculegion-male": "Basculegion",
    "basculegion-female": "Basculegion (Female)",
    "rotom-wash": "Wash Rotom",
    "rotom-heat": "Heat Rotom",
    "rotom-frost": "Frost Rotom",
    "rotom-mow": "Mow Rotom",
    "rotom-fan": "Fan Rotom",
    "floette-eternal-flower": "Floette (Eternal Flower)",
    "aegislash-shield": "Aegislash",
    "maushold-family-of-three": "Maushold",
    "ninetales-alola": "Alolan Ninetales",
    "raichu-alola": "Alolan Raichu",
    "typhlosion-hisui": "Hisuian Typhlosion",
    "zoroark-hisui": "Hisuian Zoroark",
    "arcanine-hisui": "Hisuian Arcanine",
    "goodra-hisui": "Hisuian Goodra",
    "samurott-hisui": "Hisuian Samurott",
    "decidueye-hisui": "Hisuian Decidueye",
    "avalugg-hisui": "Hisuian Avalugg",
    "mimikyu-disguised": "Mimikyu",
    "palafin-zero": "Palafin",
    "morpeko-full-belly": "Morpeko",
    "tauros-paldea-aqua-breed": "Paldean Tauros (Aqua Breed)",
    "tauros-paldea-blaze-breed": "Paldean Tauros (Blaze Breed)",
    "tauros-paldea-combat-breed": "Paldean Tauros (Combat Breed)",
    "meowstic-male": "Meowstic",
    "meowstic-female": "Meowstic (Female)",
    "slowking-galar": "Galarian Slowking",
    "slowbro-galar": "Galarian Slowbro",
    "stunfisk-galar": "Galarian Stunfisk",
    "lycanroc-midday": "Lycanroc",
    "lycanroc-dusk": "Lycanroc (Dusk Form)",
    "lycanroc-midnight": "Lycanroc (Midnight Form)",
    "gourgeist-small": "Gourgeist (Small Size)",
    "mr-rime": "Mr. Rime",
}


def get(path):
    req = urllib.request.Request(
        API + path, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def norm(s):
    return s.lower().replace(" ", "").replace("-", "").replace("'", "")


def main():
    pokemon = get("/pokemon?limit=500")
    pokemon = pokemon["results"] if isinstance(pokemon, dict) else pokemon
    ranking = get("/stats/ranking")

    with open(USAGE_PATH, encoding="utf-8") as f:
        text = f.read()
    usage = json.loads(text)
    by_norm = {norm(k): k for k in usage if k != "_meta"}

    ko_form = {}
    for p in pokemon:
        ko_form[(p["name_ko"], p.get("form") or "")] = p

    # Resolve ranking → {champions_usage key: sp dict}.
    spreads = {}
    unresolved = []
    for entry in ranking:
        ko = entry["pokemon"]
        form = entry.get("form") or ""
        rec = ko_form.get((ko, form)) or ko_form.get((ko, ""))
        if rec is None:
            unresolved.append(f"{ko} ({form})")
            continue
        en = rec["name_en"]
        key = ALIAS.get(en) or by_norm.get(norm(en))
        if key is None:
            unresolved.append(en)
            continue
        if key in spreads:
            continue  # ranking is usage-sorted — keep the first hit
        rows = entry.get("sp_spreads") or []
        if not rows:
            continue
        t = rows[0]
        spreads[key] = {
            "hp": t["sp_hp"], "atk": t["sp_atk"], "def": t["sp_def"],
            "spa": t["sp_spa"], "spd": t["sp_spd"], "spe": t["sp_spe"],
        }

    # Surgical insert: drop a `"defaultSp": {...},` line right after the
    # opening brace of each species object. Strip any pre-existing line
    # first so re-runs stay idempotent.
    text = re.sub(r'\n    "defaultSp": \{[^}]*\},', "", text)
    applied = 0
    for key, sp in spreads.items():
        compact = ("{" + ", ".join(f'"{k}": {sp[k]}' for k in
                   ("hp", "atk", "def", "spa", "spd", "spe")) + "}")
        anchor = f'  "{key}": {{\n'
        if anchor not in text:
            unresolved.append(f"[anchor missing] {key}")
            continue
        text = text.replace(
            anchor, f'{anchor}    "defaultSp": {compact},\n', 1)
        applied += 1

    # Sanity: must still be valid JSON.
    json.loads(text)
    with open(USAGE_PATH, "w", encoding="utf-8") as f:
        f.write(text)

    print(f"defaultSp applied to {applied} species")
    if unresolved:
        print(f"unresolved ({len(unresolved)}): {', '.join(unresolved)}")


if __name__ == "__main__":
    sys.exit(main())
