#!/usr/bin/env python3
"""
Apply scraped Pokemon Champions learnsets to assets/learnsets.json.

Maps each yakkun slug (e.g., n26, n26a, n479h) to the correct Showdown-style
learnset key (raichu, raichualola, rotomheat, ...) so form-specific entries
(regional forms, Rotom appliances, Aegislash stances, etc.) are all updated.

Rules:
- Mega forms share their base form's learnset in Champions → their moves
  are merged into the base dex entry (the game treats Megas as distinct
  entities but yakkun lists identical movesets anyway).
- Regional forms (Alolan / Galarian / Hisuian / Paldean) get their own
  Showdown key following the `{name}alola` / `galar` / `hisui` / `paldea*`
  convention used by pokemon-showdown.
- Special forms (Rotom appliances, Aegislash stances, Lycanroc times,
  Necrozma fusions, Urshifu styles, ...) get explicit per-slug mappings.
- Bare Champions-only forms with no Showdown counterpart are dropped with
  a warning.
"""

import json
import re
import sys
import unicodedata
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
    result: dict[str, str] = {}
    for path in sorted(MOVES_DIR.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        for m in data:
            ja = m.get("nameJa")
            en = m.get("name")
            if ja and en:
                result[nfkc(ja)] = showdown_id(en)
    return result


def build_dex_base_map() -> dict[int, str]:
    """Dex number -> base-form Showdown ID (e.g., 26 -> 'raichu')."""
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
            if "formId" not in p and dex not in base:
                base[dex] = showdown_id(en)
            elif dex not in fallback:
                fallback[dex] = showdown_id(en)
    for dex, sid in fallback.items():
        base.setdefault(dex, sid)
    return base


# Explicit per-slug overrides for forms whose Showdown key can't be derived
# from a simple suffix rule (appliances, stances, fusions, ...).
# None means "skip this slug" (Champions-only form with no Showdown counterpart).
SLUG_OVERRIDES: dict[str, str | None] = {
    # Rotom appliances
    "n479h": "rotomheat",
    "n479w": "rotomwash",
    "n479f": "rotomfrost",
    "n479s": "rotomfan",
    "n479c": "rotommow",
    # Aegislash: Showdown merges shield/blade into "aegislash"
    "n681b": "aegislash",
    # Lycanroc forms
    "n745d": "lycanrocdusk",
    "n745f": "lycanrocmidnight",
    # Deoxys: Showdown merges all forms into "deoxys"
    "n386a": "deoxys",
    "n386d": "deoxys",
    "n386s": "deoxys",
    # Pumpkaboo / Gourgeist: only the "super" size has a separate key
    "n710s": "pumpkaboo",
    "n710l": "pumpkaboo",
    "n710k": "pumpkaboosuper",
    "n711s": "gourgeist",
    "n711l": "gourgeist",
    "n711k": "gourgeistsuper",
    # Shaymin: merged into base
    "n492s": "shaymin",
    # Basculin forms: only whitestriped separate
    "n550f": "basculin",
    "n550w": "basculinwhitestriped",
    # Necrozma fusions
    "n800s": "necrozmaduskmane",
    "n800m": "necrozmadawnwings",
    "n800u": "necrozmaultra",
    # Zygarde: only 10% separate; complete merges into base
    "n718t": "zygarde10",
    "n718c": "zygarde",
    # Hoopa: merged
    "n720u": "hoopa",
    # Kyurem
    "n646w": "kyuremwhite",
    "n646b": "kyuremblack",
    # Keldeo / Meloetta: merged
    "n647k": "keldeo",
    "n648f": "meloetta",
    # Therian forms: merged
    "n641a": "tornadus",
    "n642a": "thundurus",
    "n645a": "landorus",
    "n905a": "enamorus",
    # Zacian / Zamazenta crowned
    "n888f": "zaciancrowned",
    "n889f": "zamazentacrowned",
    # Urshifu rapid strike
    "n892r": "urshifurapidstrike",
    # Calyrex fusions
    "n898w": "calyrexice",
    "n898b": "calyrexshadow",
    # Origin forms: merged into base
    "n483o": "dialga",
    "n484o": "palkia",
    "n487o": "giratina",
    # Tauros Paldea
    "n128a": "taurospaldeacombat",
    "n128b": "taurospaldeablaze",
    "n128c": "taurospaldeaaqua",
    # Wooper paldea
    "n194p": "wooperpaldea",
    # Oinkologne female
    "n916f": "oinkolognef",
    # Indeedee / Meowstic female
    "n876f": "indeedeef",
    "n678f": "meowsticf",
    # Minior / Wishiwashi / Eiscue / Mimikyu / Morpeko / Palafin / Oricorio:
    # Showdown merges all forms into the base key
    "n774f": "minior",
    "n746f": "wishiwashi",
    "n875f": "eiscue",
    "n849f": "toxtricitylowkey",
    "n934f": "palafin",
    "n902f": "basculegionf",
    "n741p": "oricorio",
    "n741f": "oricorio",
    "n741m": "oricorio",
    # Wormadam cloaks
    "n413s": "wormadamsandy",
    "n413d": "wormadamtrash",
    # Ogerpon / Terapagos: merged (no form-specific Showdown keys)
    "n1011w": "ogerpon",
    "n1011h": "ogerpon",
    "n1011c": "ogerpon",
    "n1021t": "terapagos",
    "n1021s": "terapagos",
    # Ursaluna bloodmoon
    "n901f": "ursalunabloodmoon",
    # Floette eternal
    "n670e": "floetteeternal",
    # Darmanitan forms
    "n555f": "darmanitan",       # zen shares base
    "n555g": "darmanitangalar",
    "n555h": "darmanitangalar",  # galar-zen shares galar key
    # Galarian regional forms with distinct Showdown keys
    "n77g": "ponytagalar",
    "n78g": "rapidashgalar",
    "n79g": "slowpokegalar",
    "n80g": "slowbrogalar",
    "n199g": "slowkinggalar",
    "n83g": "farfetchdgalar",
    "n122g": "mrmimegalar",
    "n222g": "corsolagalar",
    "n263g": "zigzagoongalar",
    "n264g": "linoonegalar",
    "n562g": "yamaskgalar",
    "n618g": "stunfiskgalar",
    "n110g": "weezinggalar",
    "n554g": "darumakagalar",
    "n144g": "articunogalar",
    "n145g": "zapdosgalar",
    "n146g": "moltresgalar",
    "n52a": "meowthalola",
    "n52g": "meowthgalar",
}


def main() -> int:
    raw = json.loads(RAW_PATH.read_text(encoding="utf-8"))
    move_map = build_move_map()
    dex_base = build_dex_base_map()
    learnsets = json.loads(LEARNSETS_PATH.read_text(encoding="utf-8"))

    # Collect moves keyed by target Showdown ID.
    target_moves: dict[str, set[str]] = {}
    missing_moves: set[str] = set()
    skipped_slugs: list[tuple[str, str]] = []

    # Build a moves set per slug first (JA->showdown IDs).
    slug_moves: dict[str, set[str]] = {}
    slug_names: dict[str, str] = {}
    for slug, entry in raw.items():
        slug_names[slug] = entry["name_ja"]
        show_moves: set[str] = set()
        for ja in entry["moves_ja"]:
            key = nfkc(ja)
            sid = move_map.get(key)
            if not sid:
                missing_moves.add(ja)
                continue
            show_moves.add(sid)
        slug_moves[slug] = show_moves

    # Resolve each slug to a target Showdown ID.
    def resolve(slug: str, dex: int, form: str) -> str | None:
        if slug in SLUG_OVERRIDES:
            return SLUG_OVERRIDES[slug]
        if form == "":
            return dex_base.get(dex)
        # Standard regional suffixes
        base = dex_base.get(dex)
        if base is None:
            return None
        if form == "m" or form == "x" or form == "y":
            # Mega / Mega X / Mega Y share base's learnset
            return base
        if form == "a":
            return base + "alola"
        if form == "g":
            return base + "galar"
        if form == "h":
            return base + "hisui"
        if form == "p":
            return base + "paldea"
        return None

    for slug, entry in raw.items():
        dex = entry["dex"]
        form = entry["form"]
        tgt = resolve(slug, dex, form)
        if tgt is None:
            skipped_slugs.append((slug, entry["name_ja"]))
            continue
        target_moves.setdefault(tgt, set()).update(slug_moves[slug])

    if missing_moves:
        print(f"WARN: {len(missing_moves)} JA move names without mapping:")
        for ja in sorted(missing_moves):
            print(f"  {ja}")

    if skipped_slugs:
        print(f"INFO: {len(skipped_slugs)} Champions forms skipped (no Showdown key):")
        for slug, name in skipped_slugs:
            print(f"  {slug} {name}")

    # Apply: replace in learnsets.
    replaced = 0
    added = []
    for tgt, moves in sorted(target_moves.items()):
        if tgt not in learnsets:
            added.append(tgt)
        learnsets[tgt] = sorted(moves)
        replaced += 1

    print(f"Replaced learnsets for {replaced} entries.")
    if added:
        print(f"INFO: {len(added)} new learnset keys added:")
        for k in added[:20]:
            print(f"  {k}")

    LEARNSETS_PATH.write_text(
        json.dumps(learnsets, separators=(",", ":"), ensure_ascii=False),
        encoding="utf-8",
    )
    print(f"Wrote {LEARNSETS_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
