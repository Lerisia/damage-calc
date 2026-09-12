#!/usr/bin/env python3
"""Pull Champions in-game usage stats from pokechamdb.com into
assets/champions_usage(_doubles).json.

Why this source (see project_champions_data_landscape memory):
  pokedb.tokyo IP-banned us; pkmnchamps stopped updating at 2026-07
  (Season M-B). pokechamdb.com tracks the current in-game season
  (M-5, updated daily) with full per-Pokémon detail — abilities,
  items, moves, natures, and EV spreads in 0–32 SP units (confirming
  it's in-game Battle Data, not Showdown).

  Unlike pkmnchamps there's no bulk JSON endpoint: the site is a
  Next.js RSC app, so each Pokémon's data lives in the per-page flight
  payload (`self.__next_f.push([1,"…"])`). We fetch the ranking page
  once for the ordered slug list, then one detail page per Pokémon.

Bot-signature mitigation:
  ~235 detail pages per format is the same burst volume that got the
  home IP banned from pokedb. So this fetcher SPREADS the requests:
  a randomized delay between each detail fetch (default 60–180 s),
  turning a run into a many-hour trickle that reads as human. Each
  fetched detail is cached to disk keyed by (season, format, slug),
  so a killed run resumes without re-hitting pages it already has.

Names in the flight payload are Japanese; we map them to our English
keys via each move/ability/item's `nameJa` (NFKC-normalized), the
nature table below, and dexNo/slug for species. Any unmapped name is
logged and skipped rather than guessed.

Usage:
    python3 tools/fetch_pokechamdb.py [--rule 0|1]
        [--season M-5]        # default: site's latest for the format
        [--cache DIR]         # detail-page cache (default: temp)
        [--min-delay 60] [--max-delay 180]
        [--no-delay]          # for a one-shot debug run (bot-risky)

Same output contract + mega policy as fetch_pkmnchamps.py:
  rule 0 → champions_usage.json, rule 1 → champions_usage_doubles.json
  MEGA_BASE_OVERRIDES (Mega Floette ← Eternal Flower), X/Y/Z copied
  from singles, single-mega mirror.
"""
from __future__ import annotations

import argparse
import json
import os
import random
import re
import sys
import time
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MOVES_DIR = REPO / "assets" / "moves"
SINGLES_USAGE_PATH = REPO / "assets" / "champions_usage.json"
DOUBLES_USAGE_PATH = REPO / "assets" / "champions_usage_doubles.json"
BASE = "https://pokechamdb.com"
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
      "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15")


def usage_path_for(rule: int) -> Path:
    return DOUBLES_USAGE_PATH if rule == 1 else SINGLES_USAGE_PATH


def api_format(rule: int) -> str:
    return "double" if rule == 1 else "single"


# ─── Name-mapping tables ────────────────────────────────────────────
# JA → EN normalisation, fixups and the nature table live in
# tools/namemap.py, shared with the other scrapers.
from namemap import (JA_NAME_FIXUPS, NATURE_JA_TO_EN, ja_to_en_maps,  # noqa: E402
                     map_ja, norm_ja as norm)

# pokechamdb form/region slug → our champions_usage.json key. Base
# species (even hyphenated slugs like kommo-o, mr-rime) resolve via
# dexNo and never reach this table.
SLUG_TO_NAME: dict[str, str] = {
    "arcanine-hisui":       "Hisuian Arcanine",
    "ninetales-alola":      "Alolan Ninetales",
    "raichu-alola":         "Alolan Raichu",
    "slowbro-galar":        "Galarian Slowbro",
    "slowking-galar":       "Galarian Slowking",
    "stunfisk-galar":       "Galarian Stunfisk",
    "typhlosion-hisui":     "Hisuian Typhlosion",
    "samurott-hisui":       "Hisuian Samurott",
    "zoroark-hisui":        "Hisuian Zoroark",
    "goodra-hisui":         "Hisuian Goodra",
    "avalugg-hisui":        "Hisuian Avalugg",
    "decidueye-hisui":      "Hisuian Decidueye",
    "rotom-heat":           "Heat Rotom",
    "rotom-wash":           "Wash Rotom",
    "rotom-frost":          "Frost Rotom",
    "rotom-fan":            "Fan Rotom",
    "rotom-mow":            "Mow Rotom",
    "lycanroc-dusk":        "Lycanroc (Dusk Form)",
    "lycanroc-midnight":    "Lycanroc (Midnight Form)",
    "basculegion-female":   "Basculegion (Female)",
    "meowstic-female":      "Meowstic (Female)",
    "gourgeist-large":      "Gourgeist (Large Size)",
    "gourgeist-small":      "Gourgeist (Small Size)",
    "gourgeist-super":      "Gourgeist (Super Size)",
    "tauros-paldea-combat": "Paldean Tauros (Combat Breed)",
    "tauros-paldea-blaze":  "Paldean Tauros (Blaze Breed)",
    "tauros-paldea-aqua":   "Paldean Tauros (Aqua Breed)",
    # M-C entrants that share a dexNo with another form. Without these
    # the dexNo fallback in key_for would file their stats under the
    # base form's key — silently, since the fallback succeeds. Slugs
    # follow the site's pattern above (raichu-alola, meowstic-female);
    # Toxtricity Low Key is left out until its slug shows up in the log.
    "persian-alola":        "Alolan Persian",
    "indeedee-female":      "Indeedee (Female)",
    "toxtricity-low-key":   "Toxtricity (Low Key Form)",   # seen live 2026-09-10
    "floette-eternal":      "Floette (Eternal Flower)",    # Champions only has the Eternal Flower one
}

# Base species whose slug happens to contain a hyphen. Anything else
# hyphenated that isn't in SLUG_TO_NAME is probably a form we haven't
# mapped, and key_for would otherwise resolve it via dexNo without a
# word. Extend when the warning below names a genuine base species.
HYPHENATED_BASE_SLUGS: frozenset[str] = frozenset({"kommo-o", "mr-rime"})

MEGA_BASE_OVERRIDES: dict[str, str] = {
    "Mega Floette": "Floette (Eternal Flower)",
}

_XYZ_SUFFIX_RE = re.compile(r"\s+[XYZ]$")


def is_xyz_split(mega_name: str) -> bool:
    return bool(_XYZ_SUFFIX_RE.search(mega_name))


# ─── HTTP + RSC extraction ──────────────────────────────────────────

def http_get(url: str, timeout: int = 25) -> str:
    req = urllib.request.Request(url, headers={
        "User-Agent": UA,
        "Accept": "text/html",
        "Accept-Language": "ja,en;q=0.8",
    })
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", errors="ignore")


def rsc_text(html: str) -> str:
    """Concatenate + unescape every self.__next_f flight string so the
    embedded JSON can be sliced out with real UTF-8."""
    blobs = re.findall(r'self\.__next_f\.push\(\[1,"(.*?)"\]\)', html, re.S)
    return json.loads('"' + "".join(blobs).replace("\n", "\\n") + '"')


def _brace_slice(text: str, start: int) -> str:
    """Return the JSON object starting at the first '{' at/after start."""
    j = text.find("{", start)
    depth = 0
    k = j
    while k < len(text):
        c = text[k]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return text[j:k + 1]
        k += 1
    raise ValueError("unterminated object")


def _bracket_slice(text: str, start: int) -> str:
    j = text.find("[", start)
    depth = 0
    k = j
    while k < len(text):
        c = text[k]
        if c == "[":
            depth += 1
        elif c == "]":
            depth -= 1
            if depth == 0:
                return text[j:k + 1]
        k += 1
    raise ValueError("unterminated array")


def fetch_ranking(rule: int, season: str | None) -> tuple[str, list[dict]]:
    fmt = api_format(rule)
    season_q = season or "M-5"
    url = f"{BASE}/en?format={fmt}&season={season_q}&view=pokemon"
    dec = rsc_text(http_get(url))
    i = dec.find('"initialRanking"')
    if i < 0:
        raise RuntimeError("ranking payload not found")
    # Resolve the real latest season the page served (in case default
    # M-5 rolls over).
    obj = json.loads(_brace_slice(dec, i))
    resolved_season = obj.get("seasonId", season_q)
    entries = obj.get("entries", [])
    return resolved_season, entries


def fetch_detail(slug: str, rule: int, season: str) -> dict:
    fmt = api_format(rule)
    url = f"{BASE}/en/pokemon/{slug}?season={season}&format={fmt}"
    dec = rsc_text(http_get(url))
    i = dec.find('"initialDetail"')
    if i < 0:
        raise RuntimeError(f"detail payload not found for {slug}")
    return json.loads(_brace_slice(dec, i + len('"initialDetail":') - 1))


# ─── Local asset lookups ────────────────────────────────────────────

def load_lookups() -> dict:
    def load(fn: Path):
        return json.loads(fn.read_text(encoding="utf-8"))

    ja = ja_to_en_maps(REPO)
    abil, items, moves = ja["abilities"], ja["items"], ja["moves"]
    # Per-move metadata for the auto-default rule (role classification
    # + STAB).
    move_meta: dict[str, dict] = {}
    for path in sorted((REPO / "assets/moves").glob("*.json")):
        for m in load(path):
            en = m.get("name")
            if not en or en in move_meta:
                continue
            move_meta[en] = {
                "en": en,
                "type": m.get("type"),
                "cat": m.get("category"),
                "prio": m.get("priority", 0) or 0,
                "tags": m.get("tags") or [],
                "pow": m.get("power", 0) or 0,
                "max_hits": m.get("maxHits") or 1,
            }

    pokemon_types: dict[str, list[str]] = {}
    for path in sorted((REPO / "assets/pokemon").glob("*.json")):
        for p in load(path):
            pokemon_types[p["name"]] = [
                t for t in (p.get("type1"), p.get("type2")) if t
            ]

    pid_to_base = {}
    for gen in ("gen1", "gen2", "gen3", "gen4", "gen5",
                "gen6", "gen7", "gen8", "gen9"):
        for p in load(REPO / f"assets/pokemon/{gen}.json"):
            pid_to_base[int(p["dexNumber"])] = p["name"]

    mega_index = {}
    for m in load(REPO / "assets/pokemon/mega.json"):
        if m.get("name", "").startswith("Mega "):
            mega_index[m["name"]] = m

    return {
        "abil": abil, "items": items, "moves": moves,
        "move_meta": move_meta, "pokemon_types": pokemon_types,
        "pid_to_base": pid_to_base,
        "mega_index": mega_index,
    }


# ─── Auto-default moves (rule of 2026-04-30) ────────────────────────
# Ported verbatim from the user's refresh_usage.py, which was never
# committed (it lives at ~/scripts/damage-calc-refresh/). The pokedb
# fetcher (June 2026) replaced it with "top four by rate, attacking
# first" and the pkmnchamps fetcher (2026-07-30) with "first four
# attacking" — both silently. Restored 2026-09-09.

def _move_role(meta: dict) -> str:
    """status / priority / switch / utility / main.

    - status:   category == status
    - priority: priority > 0 (Sucker Punch, Aqua Jet, …)
    - switch:   tagged custom:switch_out (U-turn, Volt Switch, …)
    - utility:  power < 60 and not multi-hit (Mud Shot, Flame Charge) —
                a side-effect hit, not an offensive role
    - main:     everything else — the actual damage moves
    """
    if meta["cat"] == "status":
        return "status"
    if meta["prio"] > 0:
        return "priority"
    if "custom:switch_out" in meta["tags"]:
        return "switch"
    if meta["pow"] < 60 and meta["max_hits"] <= 1:
        return "utility"
    return "main"


def compute_default_moves(
    rows: list[dict],
    pokemon_types: list[str],
    move_meta: dict[str, dict],
) -> list[dict]:
    """Pick the four default moves from a species' usage rows.

    1. Classify each move (main / priority / switch / utility / status).
    2. Group main moves by (type, category); a group's score is the sum
       of its members' use rates, its representative the highest one.
    3. Candidates = main groups + every non-main move individually,
       sorted by score descending; take the top four.
    4. Order: STAB attacking → non-STAB attacking → status. Attacking
       partitions sort by group score (Sludge Bomb + Sludge Wave
       outrank a lone Giga Drain); status sorts by individual rate.

    `rows` are {"name": EN, "pct": float} in descending use-rate
    order. Rows with no pct (hand-written entries) score by position,
    so the writer's ordering stands in for the statistics.
    """
    pt = {t.lower() for t in pokemon_types}
    cands: list[dict] = []
    n = len(rows)
    for i, it in enumerate(rows):
        meta = move_meta.get(it.get("name", ""))
        if not meta:
            continue
        rate = it.get("pct")
        rate = float(rate) if rate is not None else float(n - i)
        cands.append({**meta, "use_rate": rate, "role": _move_role(meta)})

    groups: dict[tuple[str, str], list[dict]] = {}
    for c in cands:
        if c["role"] == "main":
            groups.setdefault((c["type"], c["cat"]), []).append(c)

    finals: list[dict] = []
    seen: set[tuple[str, str]] = set()
    for c in cands:
        if c["role"] == "main":
            key = (c["type"], c["cat"])
            if key in seen:
                continue
            seen.add(key)
            grp = groups[key]
            best = max(grp, key=lambda x: x["use_rate"])
            finals.append({"rep": best, "sort_key": sum(x["use_rate"] for x in grp)})
        else:
            finals.append({"rep": c, "sort_key": c["use_rate"]})

    finals.sort(key=lambda x: -x["sort_key"])
    picks = finals[:4]

    stab = [f for f in picks if f["rep"]["cat"] != "status" and f["rep"]["type"] in pt]
    nonstab = [f for f in picks if f["rep"]["cat"] != "status" and f["rep"]["type"] not in pt]
    status = [f for f in picks if f["rep"]["cat"] == "status"]
    stab.sort(key=lambda x: -x["sort_key"])
    nonstab.sort(key=lambda x: -x["sort_key"])
    status.sort(key=lambda x: -x["rep"]["use_rate"])
    return [{"name": f["rep"]["en"]} for f in stab + nonstab + status]


# ─── Conversion ─────────────────────────────────────────────────────

def key_for(detail: dict, lookups: dict) -> str | None:
    slug = detail.get("pokemonSlug", "")
    if slug in SLUG_TO_NAME:
        return SLUG_TO_NAME[slug]
    dex = detail.get("dexNo")
    if "-" in slug and slug not in HYPHENATED_BASE_SLUGS:
        print(f"  WARN form slug {slug!r} not in SLUG_TO_NAME — "
              f"falling back to dexNo {dex} (base form key)")
    return lookups["pid_to_base"].get(int(dex)) if dex is not None else None


def convert(detail: dict, lookups: dict, unmapped: dict, key: str) -> dict:
    def rows(cat: str, table: dict | None, is_item=False):
        out = []
        for r in detail.get(cat, []):
            ja = r.get("name")
            if not ja:
                continue
            if table is not None:
                en = map_ja(ja, table)
                if en is None:
                    unmapped.setdefault(cat, set()).add(ja)
                    continue
            else:
                en = ja
            out.append({"name": en, "pct": float(r.get("percentage", 0.0))})
        return out

    entry = {"usageRank": int(detail["rank"])}
    entry["abilities"] = rows("abilities", lookups["abil"])
    entry["items"] = rows("items", lookups["items"])
    entry["moves"] = rows("moves", lookups["moves"])
    # Natures: JA → English via the fixed table.
    nats = []
    for r in detail.get("natures", []):
        en = NATURE_JA_TO_EN.get(norm(r.get("name", "")))
        if en is None:
            unmapped.setdefault("natures", set()).add(r.get("name"))
            continue
        nats.append({"name": en, "pct": float(r.get("percentage", 0.0))})
    entry["natures"] = nats
    entry["teras"] = []

    entry["defaultMoves"] = compute_default_moves(
        entry["moves"], lookups["pokemon_types"].get(key, []),
        lookups["move_meta"],
    )

    evs = detail.get("evs") or []
    if evs:
        top = evs[0]
        entry["defaultSp"] = {
            "hp": int(top.get("hp", 0)), "atk": int(top.get("atk", 0)),
            "def": int(top.get("def", 0)), "spa": int(top.get("spAtk", 0)),
            "spd": int(top.get("spDef", 0)), "spe": int(top.get("speed", 0)),
        }
    return entry


# ─── Mega mirror (unchanged policy) ─────────────────────────────────

def base_name_for(mega_name: str) -> str:
    if mega_name in MEGA_BASE_OVERRIDES:
        return MEGA_BASE_OVERRIDES[mega_name]
    return mega_name[5:].strip() if mega_name.startswith("Mega ") else mega_name


def mirror_megas(usage: dict, mega_index: dict) -> tuple[int, int]:
    mirrored = skipped = 0
    for mega_name, meta in mega_index.items():
        if is_xyz_split(mega_name):
            skipped += 1
            continue
        base = base_name_for(mega_name)
        if base not in usage:
            continue
        be = usage[base]
        m = {}
        if be.get("defaultSp"):
            m["defaultSp"] = be["defaultSp"]
        m["abilities"] = [{"name": a} for a in (meta.get("abilities") or [])]
        stone = meta.get("requiredItem")
        m["items"] = [{"name": stone}] if stone else []
        m["moves"] = be.get("moves", [])
        m["defaultMoves"] = be.get("defaultMoves", [])
        m["natures"] = be.get("natures", [])
        usage[mega_name] = m
        mirrored += 1
    return mirrored, skipped


# ─── Main ───────────────────────────────────────────────────────────

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rule", type=int, default=0, help="0=singles 1=doubles")
    ap.add_argument("--season", default=None, help="e.g. M-5 (default: latest)")
    ap.add_argument("--cache", default=None, help="detail-page cache dir")
    ap.add_argument("--min-delay", type=float, default=60.0)
    ap.add_argument("--max-delay", type=float, default=180.0)
    ap.add_argument("--no-delay", action="store_true",
                    help="skip inter-request delays (debug; bot-risky)")
    args = ap.parse_args()

    fmt = api_format(args.rule)
    cache_dir = Path(args.cache) if args.cache else \
        Path(os.environ.get("TMPDIR", "/tmp")) / "pokechamdb_cache"
    cache_dir.mkdir(parents=True, exist_ok=True)

    print(f"fetching ranking (format={fmt}, season={args.season or 'latest'}) …")
    season, entries = fetch_ranking(args.rule, args.season)
    print(f"season={season}  ranked={len(entries)}")

    # Format guard: pokechamdb's M-5 (as of 2026-08) serves the SAME
    # singles data under format=double — the detail `format` field
    # comes back "single" regardless. Writing that into the doubles
    # file would clobber real doubles data with a singles mirror. Probe
    # the top-ranked detail; if the site doesn't actually honour the
    # requested format, abort before touching the file. When pokechamdb
    # starts publishing real doubles data this check passes on its own
    # and the doubles refresh begins working with no code change.
    if entries:
        probe = fetch_detail(entries[0]["pokemonSlug"], args.rule, season)
        got = probe.get("format")
        if got != fmt:
            print(f"ABORT: requested format={fmt} but site returned "
                  f"format={got!r} — pokechamdb has no distinct {fmt} "
                  f"data for {season}. Leaving {usage_path_for(args.rule).name} "
                  f"untouched.")
            return 3

    lookups = load_lookups()
    unmapped: dict[str, set] = {}
    details: list[dict] = []

    for idx, e in enumerate(entries, 1):
        slug = e["pokemonSlug"]
        cache_file = cache_dir / f"{season}_{fmt}_{slug}.json"
        if cache_file.exists():
            detail = json.loads(cache_file.read_text(encoding="utf-8"))
        else:
            try:
                detail = fetch_detail(slug, args.rule, season)
            except Exception as ex:
                print(f"  [{idx}/{len(entries)}] {slug} fetch ERROR: {ex}")
                continue
            cache_file.write_text(
                json.dumps(detail, ensure_ascii=False), encoding="utf-8")
            if not args.no_delay:
                delay = random.uniform(args.min_delay, args.max_delay)
                time.sleep(delay)
        details.append(detail)
        if idx % 20 == 0 or idx == len(entries):
            print(f"  [{idx}/{len(entries)}] collected={len(details)}")

    # Merge into the format's on-disk file, preserving curation.
    out_path = usage_path_for(args.rule)
    usage = json.loads(out_path.read_text(encoding="utf-8")) \
        if out_path.exists() else {"_meta": {}}

    ranked_keys: set[str] = set()
    added = replaced = unmapped_species = 0
    for detail in details:
        key = key_for(detail, lookups)
        if key is None:
            unmapped_species += 1
            print(f"  UNMAPPED species: slug={detail.get('pokemonSlug')} "
                  f"dex={detail.get('dexNo')}")
            continue
        ranked_keys.add(key)
        entry = convert(detail, lookups, unmapped, key)
        if key in usage:
            replaced += 1
        else:
            added += 1
        usage[key] = entry
    print(f"merge: added={added} replaced={replaced} "
          f"unmapped_species={unmapped_species}")

    # Strip stale ranks from dropouts (non-mega only).
    dropped = 0
    for name, ent in usage.items():
        if name == "_meta" or not isinstance(ent, dict):
            continue
        if name.startswith("Mega ") or name in ranked_keys:
            continue
        if "usageRank" in ent:
            del ent["usageRank"]
            dropped += 1
    print(f"stripped stale usageRank from {dropped} dropouts")

    # X/Y/Z megas: copy verbatim from singles on a doubles run.
    if args.rule == 1 and SINGLES_USAGE_PATH.exists():
        src = json.loads(SINGLES_USAGE_PATH.read_text(encoding="utf-8"))
        copied = 0
        for name, ent in src.items():
            if (name == "_meta" or not isinstance(ent, dict) or
                    not name.startswith("Mega ") or not is_xyz_split(name)):
                continue
            usage[name] = ent
            copied += 1
        print(f"X/Y/Z mega copied from singles: {copied}")

    mirrored, skipped_xyz = mirror_megas(usage, lookups["mega_index"])
    print(f"mega mirror: mirrored={mirrored} skipped_xyz={skipped_xyz}")

    meta = usage.setdefault("_meta", {})
    meta["source"] = "Pokemon Champions in-game Battle Data via pokechamdb.com"
    meta["format"] = f"Season {season} / {fmt}"
    meta["updatedAt"] = time.strftime("%Y-%m-%d")
    meta["curatedBy"] = "auto: pokechamdb.com (defaultMoves = role/group rule of 2026-04-30)"
    meta["notes"] = (
        "Entries ordered by descending in-game usage. Fetched via "
        "spread scraping of pokechamdb's RSC payloads; names mapped "
        "JP→EN via nameJa/dexNo."
    )

    out_path.write_text(
        json.dumps(usage, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8")
    print(f"\nwrote {out_path}")

    if unmapped:
        print("\nUNMAPPED names (add to fixups if legit):")
        for cat, names in unmapped.items():
            print(f"  {cat}: {sorted(names)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
