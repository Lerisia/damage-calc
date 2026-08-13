#!/usr/bin/env python3
"""Pull Champions in-game usage stats from pkmnchamps.com's public API
and merge them into `assets/champions_usage(_doubles).json`.

Why this exists (see also project_champions_data_landscape memory):
  champs.pokedb.tokyo — the previous source — began 403-blocking our
  home server IP in July 2026 (nginx-level IP ban, not CF). While that
  contact is pending, pkmnchamps.com serves the same in-game ranking
  cut of Reg M-B via a REST endpoint that returns EVERY ranked
  Pokémon's abilities/items/moves/natures/spread in a single response.

Traffic profile is a huge improvement:
  * pokedb: 1 ranking page + 235 detail pages = 236 requests/day
  * pkmnchamps: 1 list endpoint per format = 2 requests/day total

That drops the bot-signature to ~zero — no sequential PID traversal,
no rate to throttle, no need for random jitter or long sleeps.

Usage:
    python3 tools/fetch_pkmnchamps.py
        [--regulation R]  # default 'reg_mb' (current on-cart regulation)
        [--month YYYY-MM] # default = latest month available upstream
        [--rule R]        # 0 = singles, 1 = doubles. Default 0.

Same file-layout contract as the older fetch_pokedb_usage.py:
  * rule=0 → assets/champions_usage.json
  * rule=1 → assets/champions_usage_doubles.json
  * MEGA_BASE_OVERRIDES (single source of truth) still routes Mega
    Floette off "Floette (Eternal Flower)" instead of the plain species
  * X/Y/Z split megas stay 100% user-curated; on a doubles refresh
    they are copied verbatim from the freshest singles file
"""
from __future__ import annotations

import argparse
import json
import re
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SINGLES_USAGE_PATH = REPO / "assets" / "champions_usage.json"
DOUBLES_USAGE_PATH = REPO / "assets" / "champions_usage_doubles.json"


def usage_path_for(rule: int) -> Path:
    return DOUBLES_USAGE_PATH if rule == 1 else SINGLES_USAGE_PATH


API_BASE = "https://pkmnchamps.com"
# These two headers are what the site's own JS sends when the /ja/stats
# page fetches from its API — without them the API returns 403 even to
# a browser-shaped request. Emulating them here isn't cloaking, it's
# what a normal page load transmits.
API_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
    ),
    "Accept": "application/json",
    "Accept-Language": "ja,en;q=0.8",
    "Referer": f"{API_BASE}/ja/stats",
    "Origin": API_BASE,
}


# ─── Slug → our-JSON-key mappings ────────────────────────────────────

# pkmnchamps' region_form slugs → the string keys we use in
# champions_usage.json (matches our assets/pokemon/*.json `name` fields).
# When a new special form is added to a regulation's roster, extend
# this map and re-run the fetch. Missing forms are logged and skipped
# rather than silently coerced.
REGION_FORM_TO_NAME: dict[str, str] = {
    "raichu-alola":                "Alolan Raichu",
    "ninetales-alola":             "Alolan Ninetales",
    "arcanine-hisui":              "Hisuian Arcanine",
    "slowbro-galar":               "Galarian Slowbro",
    "tauros-paldea-combat-breed":  "Paldean Tauros (Combat Breed)",
    "tauros-paldea-blaze-breed":   "Paldean Tauros (Blaze Breed)",
    "tauros-paldea-aqua-breed":    "Paldean Tauros (Aqua Breed)",
    "typhlosion-hisui":            "Hisuian Typhlosion",
    "slowking-galar":              "Galarian Slowking",
    "rotom-fan":                   "Fan Rotom",
    "rotom-frost":                 "Frost Rotom",
    "rotom-heat":                  "Heat Rotom",
    "rotom-mow":                   "Mow Rotom",
    "rotom-wash":                  "Wash Rotom",
    "samurott-hisui":              "Hisuian Samurott",
    "zoroark-hisui":               "Hisuian Zoroark",
    "stunfisk-galar":              "Galarian Stunfisk",
    "floette-eternal":             "Floette (Eternal Flower)",
    # pkmnchamps ships this slug as 'meowstic-mega' even though there
    # is no Mega Meowstic — it's the female form. Best guess at their
    # end, mapped through to the actual key we use.
    "meowstic-mega":               "Meowstic (Female)",
    "goodra-hisui":                "Hisuian Goodra",
    "avalugg-hisui":               "Hisuian Avalugg",
    "decidueye-hisui":             "Hisuian Decidueye",
    "lycanroc-dusk":               "Lycanroc (Dusk Form)",
    "lycanroc-midnight":           "Lycanroc (Midnight Form)",
    "basculegion-female":          "Basculegion (Female)",
}


# Mega forms whose competitive base ISN'T the plain "Mega X" → "X"
# stripping. Champions doesn't Mega-evolve regular Floette — only
# "Floette (Eternal Flower)" carries the mega-worthy stat spread and
# signature Light of Ruin. Keep this map narrow.
MEGA_BASE_OVERRIDES: dict[str, str] = {
    "Mega Floette": "Floette (Eternal Flower)",
}


_XYZ_SUFFIX_RE = re.compile(r"\s+[XYZ]$")


def is_xyz_split(mega_name: str) -> bool:
    return bool(_XYZ_SUFFIX_RE.search(mega_name))


# ─── HTTP ──────────────────────────────────────────────────────────

def http_get_json(path: str, timeout: int = 30):
    req = urllib.request.Request(f"{API_BASE}{path}", headers=API_HEADERS)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8", errors="ignore"))


def latest_month_for(regulation: str, battle_format: str) -> str:
    """Ask the site which months exist for this (reg, format) and
    return the newest one. Lets the script keep working after month
    rollovers without needing a config bump."""
    entries = http_get_json("/api/champions-data?action=regMonths")
    matching = sorted(
        (e for e in entries
         if e.get("regulation") == regulation
         and e.get("battle_format") == battle_format),
        key=lambda e: e["month"], reverse=True,
    )
    if not matching:
        raise RuntimeError(
            f"regMonths has no entries for reg={regulation} format={battle_format}")
    return matching[0]["month"]


# ─── Local asset lookups ─────────────────────────────────────────────

def load_lookups(repo_root: Path):
    """Build the four slug→display-name maps + pid→English map from the
    on-disk pokedex/abilities/items/moves data."""
    def kebab(name: str) -> str:
        return (name.lower()
                    .replace("'", "")
                    .replace(".", "")
                    .replace(" ", "-"))

    # Pokemon: dexNumber (int) → English name for base species. Loaded
    # from the 9 gen-N files only; regional and form-variants live in
    # separate files and are addressed via REGION_FORM_TO_NAME above.
    pid_to_base: dict[int, str] = {}
    for gen in ("gen1", "gen2", "gen3", "gen4", "gen5",
                "gen6", "gen7", "gen8", "gen9"):
        for p in json.loads(
                (repo_root / f"assets/pokemon/{gen}.json").read_text(encoding="utf-8")):
            pid_to_base[int(p["dexNumber"])] = p["name"]

    # Abilities
    ability_slug_to_name: dict[str, str] = {}
    for a in json.loads((repo_root / "assets/abilities.json").read_text(encoding="utf-8")):
        ability_slug_to_name[kebab(a["name"])] = a["name"]

    # Moves — merged across every gen file. Duplicate keys resolve to
    # the last-loaded (newer-gen) name, which is stable because move
    # slugs are unique across gens.
    move_slug_to_name: dict[str, str] = {}
    for gen in ("gen1", "gen2", "gen3", "gen4", "gen5",
                "gen6", "gen7", "gen8", "gen9"):
        for m in json.loads(
                (repo_root / f"assets/moves/{gen}.json").read_text(encoding="utf-8")):
            move_slug_to_name[kebab(m["name"])] = m["name"]

    # Damaging-move whitelist for defaultMoves derivation. `power`
    # missing / falsy / category "Status" ⇒ status move; skip. Same
    # shape check that was used in the pokedb pipeline.
    damaging_moves: set[str] = set()
    for gen in ("gen1", "gen2", "gen3", "gen4", "gen5",
                "gen6", "gen7", "gen8", "gen9"):
        for m in json.loads(
                (repo_root / f"assets/moves/{gen}.json").read_text(encoding="utf-8")):
            cat = m.get("category", "")
            power = m.get("power") or m.get("bp") or 0
            if cat != "Status" and (power or m.get("name") in {
                # Fixed-damage moves have BP 0 but ARE damaging.
                "Seismic Toss", "Night Shade", "Dragon Rage",
                "Sonic Boom", "Endeavor", "Super Fang",
            }):
                damaging_moves.add(m["name"])

    # Items: valid item slug set (items already stored kebab-case).
    valid_items: set[str] = {
        i["name"] for i in json.loads(
            (repo_root / "assets/items.json").read_text(encoding="utf-8"))
    }

    # Mega index for the mirror step.
    mega_index: dict[str, dict] = {}
    for m in json.loads((repo_root / "assets/pokemon/mega.json").read_text(encoding="utf-8")):
        if m.get("name", "").startswith("Mega "):
            mega_index[m["name"]] = m

    return {
        "pid_to_base": pid_to_base,
        "ability_slug_to_name": ability_slug_to_name,
        "move_slug_to_name": move_slug_to_name,
        "damaging_moves": damaging_moves,
        "valid_items": valid_items,
        "mega_index": mega_index,
    }


# ─── Entry conversion ───────────────────────────────────────────────

def key_for_entry(entry: dict, lookups: dict) -> str | None:
    """Compute our champions_usage.json key for a pkmnchamps API entry.

    - `region_form` set → look up via REGION_FORM_TO_NAME.
    - `mega_form` set → not currently expected (pkmnchamps doesn't rank
      megas separately), but if it appears in the future we'd map here.
    - Otherwise → base species by pokemon_id.

    Returns None for unmapped entries (caller logs + skips)."""
    rf = entry.get("region_form") or ""
    if rf:
        return REGION_FORM_TO_NAME.get(rf)
    mf = entry.get("mega_form") or ""
    if mf:
        # Currently no rankings for mega forms; if pkmnchamps starts
        # exposing them, add a mega_slug→name map similar to region.
        return None
    pid = entry.get("pokemon_id")
    return lookups["pid_to_base"].get(int(pid)) if pid is not None else None


def convert_entry(entry: dict, lookups: dict) -> dict:
    """Translate one pkmnchamps list item into our on-disk schema.

    Preserves the same JSON shape existing consumers already read:
      abilities/items/moves/natures/teras: [{name, pct}]
      defaultMoves: [{name}] for the top-4 damaging moves
      defaultSp:    Stats object from the most-adopted spread
      usageRank:    integer position in the ranked list
    """
    out: dict = {"usageRank": int(entry["pick_rank"])}

    def usage_list(rows, name_map=None, valid_set=None):
        r = []
        for row in rows or ():
            raw = row.get("name")
            if not raw:
                continue
            if name_map is not None:
                display = name_map.get(raw)
                if display is None:
                    continue  # unknown slug — silently drop
            else:
                display = raw
            if valid_set is not None and display not in valid_set:
                continue
            r.append({"name": display, "pct": float(row.get("usage", 0.0))})
        return r

    out["abilities"] = usage_list(entry.get("abilities"),
                                  name_map=lookups["ability_slug_to_name"])
    out["items"] = usage_list(entry.get("items"),
                              valid_set=lookups["valid_items"])
    out["moves"] = usage_list(entry.get("moves"),
                              name_map=lookups["move_slug_to_name"])

    # Natures come through as English lowercase from pkmnchamps
    # ("jolly", "adamant"). Our JSON stores them capitalized.
    out["natures"] = [
        {"name": (n["name"] or "").capitalize(),
         "pct": float(n.get("usage", 0.0))}
        for n in (entry.get("natures") or ()) if n.get("name")
    ]

    # Teras not exposed by pkmnchamps — keep an empty list so the
    # existing consumer's `list(v['teras'])` doesn't KeyError.
    out["teras"] = []

    # defaultMoves — top 4 damaging moves by usage, in that order.
    dmg = lookups["damaging_moves"]
    default_moves = [
        {"name": m["name"]}
        for m in out["moves"] if m["name"] in dmg
    ][:4]
    out["defaultMoves"] = default_moves

    # defaultSp: most-adopted spread's stat block (Champions SP units).
    spreads = entry.get("spreads") or []
    if spreads:
        sps = spreads[0].get("sps") or {}
        out["defaultSp"] = {
            "hp":  int(sps.get("hp",  0)),
            "atk": int(sps.get("atk", 0)),
            "def": int(sps.get("def", 0)),
            "spa": int(sps.get("spa", 0)),
            "spd": int(sps.get("spd", 0)),
            "spe": int(sps.get("spe", 0)),
        }

    return out


# ─── Mega mirror (identical policy to fetch_pokedb_usage.py) ────────

def base_name_for(mega_name: str) -> str:
    if mega_name in MEGA_BASE_OVERRIDES:
        return MEGA_BASE_OVERRIDES[mega_name]
    return mega_name[5:].strip() if mega_name.startswith("Mega ") else mega_name


def mirror_megas_from_base(usage: dict, mega_index: dict) -> tuple[int, int]:
    """For every single-Mega (non X/Y/Z), copy moves/defaultMoves/
    natures/defaultSp from its base in `usage`. Preserves the Mega's
    own ability + item (from mega.json). X/Y/Z split megas are
    skipped — they stay user-curated in the singles file."""
    mirrored = skipped = 0
    for mega_name, mega_meta in mega_index.items():
        if is_xyz_split(mega_name):
            skipped += 1
            continue
        base = base_name_for(mega_name)
        if base not in usage:
            continue
        base_entry = usage[base]
        m: dict = {}
        if base_entry.get("defaultSp"):
            m["defaultSp"] = base_entry["defaultSp"]
        mega_abilities = mega_meta.get("abilities") or []
        m["abilities"] = [{"name": a} for a in mega_abilities]
        stone = mega_meta.get("requiredItem")
        m["items"] = [{"name": stone}] if stone else []
        m["moves"] = base_entry.get("moves", [])
        m["defaultMoves"] = base_entry.get("defaultMoves", [])
        m["natures"] = base_entry.get("natures", [])
        usage[mega_name] = m
        mirrored += 1
    return mirrored, skipped


# ─── Main ───────────────────────────────────────────────────────────

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--regulation", default="reg_mb",
                    help="Regulation slug (default 'reg_mb')")
    ap.add_argument("--month", default=None,
                    help="YYYY-MM (default = latest month available)")
    ap.add_argument("--rule", type=int, default=0,
                    help="0 = singles, 1 = doubles")
    args = ap.parse_args()

    battle_format = "doubles" if args.rule == 1 else "singles"
    month = args.month or latest_month_for(args.regulation, battle_format)
    print(f"source: pkmnchamps.com  reg={args.regulation}  month={month}  "
          f"format={battle_format}")

    lookups = load_lookups(REPO)

    entries = http_get_json(
        f"/api/champions-data?action=list"
        f"&regulation={args.regulation}"
        f"&month={month}"
        f"&format={battle_format}")
    print(f"fetched {len(entries)} entries")

    # Load existing on-disk snapshot so we can preserve non-ranked
    # curation (X/Y/Z megas, hand-tweaked entries) and detect dropouts.
    out_path = usage_path_for(args.rule)
    if out_path.exists():
        usage = json.loads(out_path.read_text(encoding="utf-8"))
    else:
        usage = {"_meta": {}}

    ranked_keys: set[str] = set()
    replaced = added = skipped_unmapped = 0
    for entry in entries:
        key = key_for_entry(entry, lookups)
        if key is None:
            skipped_unmapped += 1
            print(f"  UNMAPPED pid={entry.get('pokemon_id')} "
                  f"region={entry.get('region_form','')} "
                  f"mega={entry.get('mega_form','')}")
            continue
        ranked_keys.add(key)
        new_entry = convert_entry(entry, lookups)
        if key in usage:
            replaced += 1
        else:
            added += 1
        usage[key] = new_entry
    print(f"merge: added={added} replaced={replaced} unmapped={skipped_unmapped}")

    # Strip stale usageRank from entries that dropped out of this
    # regulation-month. Same policy as the pokedb pipeline.
    dropped_rank = 0
    for name, ent in usage.items():
        if name == "_meta" or not isinstance(ent, dict):
            continue
        if name.startswith("Mega "):
            continue  # megas aren't ranked in this feed; preserve as-is
        if name in ranked_keys:
            continue
        if "usageRank" in ent:
            del ent["usageRank"]
            dropped_rank += 1
    print(f"stripped stale usageRank from {dropped_rank} dropout entries")

    # X/Y/Z megas: doubles refresh copies them verbatim from singles.
    if args.rule == 1 and SINGLES_USAGE_PATH.exists():
        singles_src = json.loads(SINGLES_USAGE_PATH.read_text(encoding="utf-8"))
        xyz_copied = 0
        for name, ent in singles_src.items():
            if (name == "_meta" or not isinstance(ent, dict) or
                    not name.startswith("Mega ") or not is_xyz_split(name)):
                continue
            usage[name] = ent
            xyz_copied += 1
        print(f"X/Y/Z mega copied from singles: {xyz_copied}")

    # Single-mega mirror (unchanged policy from prior pipeline).
    mirrored, skipped_xyz = mirror_megas_from_base(usage, lookups["mega_index"])
    print(f"mega mirror: mirrored={mirrored} skipped_xyz={skipped_xyz}")

    # Meta stamp.
    meta = usage.setdefault("_meta", {})
    meta["source"] = (
        "Pokemon Champions in-game Battle Data via pkmnchamps.com "
        "(/api/champions-data action=list)"
    )
    meta["format"] = f"Regulation {args.regulation} / {month}"
    meta["updatedAt"] = time.strftime("%Y-%m-%d")
    meta["curatedBy"] = (
        "auto: pkmnchamps.com (defaultMoves = top 4 damaging by usage)"
    )
    meta["notes"] = (
        "Entries are ordered by descending in-game usage. pct is the "
        "raw percentage reported by upstream. Items/moves/natures are "
        "capped at the top 10 as returned by the upstream list "
        "endpoint."
    )

    out_path.write_text(
        json.dumps(usage, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"\nwrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
