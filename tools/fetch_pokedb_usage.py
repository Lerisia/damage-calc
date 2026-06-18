#!/usr/bin/env python3
"""Pull Champions in-game singles usage stats from champs.pokedb.tokyo
and merge them into assets/champions_usage.json.

  - Ranking page (single fetch) gives the ranked Pokemon list (~235 in
    Season M-3).
  - Each per-Pokémon detail page (rate-limited 2s) yields the moves /
    items / abilities / natures / EV-spread breakdowns.
  - Japanese → English name mapping comes from our existing dex assets;
    no additional curated lookup needed for the base-form Pokémon.
    Special forms (Alolan/Galarian/Hisuian/etc.) use a manually-curated
    table at the top of this file.
  - Merge is non-destructive for entries pokedb doesn't cover — Megas
    (single + X/Y/Z splits) and tail-end Pokémon with empty pokedb
    pages keep whatever's in champions_usage.json already.

Usage:
    python3 tools/fetch_pokedb_usage.py
        [--season N]     # 3 = Season M-3 (Reg M-B). Default 3.
        [--rule R]       # 0 = singles, 1 = doubles. Default 0.
        [--cache DIR]    # Where to keep downloaded HTML between runs.
                         # Defaults to a fresh tempdir per run.
        [--sleep SECS]   # Politeness delay between detail fetches.
                         # Default 2.0.

Designed to be safe to re-run: it overwrites champions_usage.json
in place, and CI compares the git diff to decide whether to PR.
"""
from __future__ import annotations

import argparse
import html as htmlmod
import json
import re
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
USAGE_PATH = REPO / "assets" / "champions_usage.json"
BASE = "https://champs.pokedb.tokyo"
UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0 Safari/537.36"
)

# pokedb's non-base form IDs → our champions_usage.json key.
# These are Champions-allowed special forms (Alolan/Galarian/Hisuian/
# Paldean/Rotom/Floette/etc.). Update this when pokedb introduces a new
# special form to its ranked roster.
SPECIAL_FORMS: dict[str, str] = {
    "0026-01": "Alolan Raichu",
    "0038-01": "Alolan Ninetales",
    "0059-01": "Hisuian Arcanine",
    "0080-02": "Galarian Slowbro",
    "0128-01": "Paldean Tauros (Combat Breed)",
    "0128-02": "Paldean Tauros (Blaze Breed)",
    "0128-03": "Paldean Tauros (Aqua Breed)",
    "0157-01": "Hisuian Typhlosion",
    "0199-01": "Galarian Slowking",
    "0479-01": "Heat Rotom",
    "0479-02": "Wash Rotom",
    "0479-03": "Frost Rotom",
    "0479-04": "Fan Rotom",
    "0479-05": "Mow Rotom",
    "0503-01": "Hisuian Samurott",
    "0571-01": "Hisuian Zoroark",
    "0618-01": "Galarian Stunfisk",
    "0666-18": "Vivillon",  # pattern variation; use base
    "0670-05": "Floette (Eternal Flower)",
    "0678-01": "Female Meowstic",
    "0706-01": "Hisuian Goodra",
    "0711-01": "Gourgeist (Small Size)",
    "0711-02": "Gourgeist (Large Size)",
    "0711-03": "Gourgeist (Super Size)",
    "0713-01": "Hisuian Avalugg",
    "0724-01": "Hisuian Decidueye",
    "0745-01": "Midnight Lycanroc",
    "0745-02": "Dusk Lycanroc",
    "0902-01": "Basculegion (Female)",
}

STAT_LETTER_TO_KEY = {"H": "hp", "A": "atk", "B": "def", "C": "spa", "D": "spd", "S": "spe"}


# ─── HTTP helpers ─────────────────────────────────────────────────────

def http_get(url: str, timeout: int = 15) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


# ─── Ranking-page parsing (gets {id: jp_name} for all ranked Pokémon) ─

ID_NAME_RE = re.compile(
    r'/pokemon/show/(\d{4}-\d{2})\?[^"]*"[^>]*>.*?'
    r'<div class="pokemon-name">([^<]+)</div>',
    re.DOTALL,
)


def fetch_ranking(season: int, rule: int) -> dict[str, str]:
    url = f"{BASE}/pokemon/list?season={season}&rule={rule}"
    html = http_get(url).decode("utf-8", errors="ignore")
    ids: dict[str, str] = {}
    for pid, name in ID_NAME_RE.findall(html):
        if pid not in ids:
            ids[pid] = name.strip()
    if not ids:
        raise RuntimeError(f"ranking page returned 0 IDs (url={url})")
    return ids


# ─── Detail-page parsing ──────────────────────────────────────────────

ROW_RE = re.compile(
    r'<span class="usage-name[^"]*"[^>]*>\s*(.+?)\s*</span>\s*'
    r'<span class="usage-rate[^"]*"[^>]*>\s*([\d.]+)\s*%</span>',
    re.DOTALL,
)
NEXT_H_RE = re.compile(r"<h[23][^>]*>")
NATURE_NAME_RE = re.compile(r"^(\S+?)(?:\s*\(|\s*$)")
SPREAD_DETAIL_RE = re.compile(
    r'<li class="pokemon-stat-spread__detail">(.*?)</li>',
    re.DOTALL,
)
SPREAD_RATE_RE = re.compile(
    r'pokemon-stat-spread__detail-rate[^>]*>\s*([\d.]+)\s*%'
)
CHIP_RE = re.compile(
    r'<span class="pokemon-stat-spread__label">\s*([A-Z+])\s*</span>\s*'
    r'<span class="pokemon-stat-spread__value[^"]*">\s*([^<]+?)\s*</span>'
)


def _section(html: str, jp_heading: str) -> str:
    m = re.search(rf"<h\d[^>]*>{jp_heading}</h\d>", html)
    if not m:
        return ""
    start = m.end()
    end_m = NEXT_H_RE.search(html[start:])
    end = start + (end_m.start() if end_m else 6000)
    return html[start:end]


def _rows(section_html: str) -> list[tuple[str, float]]:
    out: list[tuple[str, float]] = []
    for name_raw, rate in ROW_RE.findall(section_html):
        name = re.sub(r"<[^>]+>", "", name_raw).strip()
        name = re.sub(r"\s+", " ", name)
        out.append((name, float(rate)))
    return out


def _moves_from_data_attrs(html: str) -> list[dict]:
    moves: list[dict] = []
    for raw in re.findall(r'data-move-detail="([^"]+)"', html):
        try:
            obj = json.loads(htmlmod.unescape(raw))
            moves.append({
                "name_ja": obj["name"],
                "rate": obj["rate"],
                "rank": obj["rank"],
            })
        except Exception:
            pass
    moves.sort(key=lambda m: m["rank"])
    return moves


def _ev_spreads(section_html: str) -> list[dict]:
    """Return list of {rate, sp} sorted by descending rate. Each sp is
    the actual stat distribution from the first sub-entry under each
    summary group (the most-used specific spread)."""
    spreads: list[dict] = []
    for li in SPREAD_DETAIL_RE.findall(section_html):
        rm = SPREAD_RATE_RE.search(li)
        if not rm:
            continue
        sp = {k: 0 for k in ("hp", "atk", "def", "spa", "spd", "spe")}
        for letter, value in CHIP_RE.findall(li):
            key = STAT_LETTER_TO_KEY.get(letter)
            if key:
                try:
                    sp[key] = int(value)
                except ValueError:
                    pass
        spreads.append({"rate": float(rm.group(1)), "sp": sp})
    spreads.sort(key=lambda s: -s["rate"])
    return spreads


# ─── JA → EN lookup tables (built from our project's assets) ─────────

def build_lookups(repo_root: Path) -> dict[str, dict[str, str]]:
    import glob
    moves_ja2en: dict[str, str] = {}
    move_category: dict[str, str] = {}   # English name → 'physical'/'special'/'status'
    for path in glob.glob(str(repo_root / "assets/moves/*.json")):
        for e in json.load(open(path)):
            if e.get("nameJa") and e.get("name"):
                moves_ja2en[e["nameJa"]] = e["name"]
            if e.get("name") and e.get("category"):
                move_category[e["name"]] = e["category"]

    abi_ja2en: dict[str, str] = {}
    for e in json.load(open(repo_root / "assets/abilities.json")):
        if e.get("nameJa") and e.get("name"):
            abi_ja2en[e["nameJa"]] = e["name"]

    items_data = json.load(open(repo_root / "assets/items.json"))
    items_iter = items_data if isinstance(items_data, list) else list(items_data.values())
    items_ja2en: dict[str, str] = {}
    for e in items_iter:
        if isinstance(e, dict) and e.get("nameJa") and e.get("name"):
            items_ja2en[e["nameJa"]] = e["name"]

    # Nature JA → English enum (from lib/models/nature.dart constant map)
    nat_text = (repo_root / "lib/models/nature.dart").read_text(encoding="utf-8")
    raw = re.findall(r"(\w+):\s*'([^']+)'", nat_text)
    nat_ja2en: dict[str, str] = {}
    for en, ja in raw:
        if any("぀" <= c <= "ヿ" for c in ja):
            nat_ja2en[ja] = en[0].upper() + en[1:]

    # Pokemon dex → base English name
    dex_to_base: dict[int, str] = {}
    skip_prefixes = (
        "Mega ", "Alolan ", "Galarian ", "Hisuian ", "Paldean ",
        "Heat ", "Wash ", "Frost ", "Fan ", "Mow ",
        "Midnight ", "Dusk ",
    )
    for path in sorted(glob.glob(str(repo_root / "assets/pokemon/*.json"))):
        try:
            d = json.load(open(path))
        except Exception:
            continue
        arr = d if isinstance(d, list) else list(d.values())
        for e in arr:
            if not isinstance(e, dict):
                continue
            name = e.get("name", "")
            dex = e.get("dexNumber")
            if dex is None or name.startswith(skip_prefixes):
                continue
            d_int = int(dex)
            dex_to_base.setdefault(d_int, name)

    return {
        "moves": moves_ja2en,
        "move_category": move_category,
        "abilities": abi_ja2en,
        "items": items_ja2en,
        "natures": nat_ja2en,
        "dex_to_base": dex_to_base,
    }


def pokedb_id_to_en(pid: str, dex_to_base: dict[int, str]) -> str | None:
    if pid in SPECIAL_FORMS:
        return SPECIAL_FORMS[pid]
    if not pid.endswith("-00"):
        return None
    try:
        dex = int(pid.split("-")[0])
    except ValueError:
        return None
    return dex_to_base.get(dex)


def parse_detail(html: str, maps: dict) -> dict | None:
    moves_en = [
        {"name": en, "rate": m["rate"]}
        for m in _moves_from_data_attrs(html)
        if (en := maps["moves"].get(m["name_ja"]))
    ]
    abilities_en = [
        {"name": en, "rate": rate}
        for name, rate in _rows(_section(html, "特性"))
        if (en := maps["abilities"].get(name))
    ]
    natures_en = []
    for raw_name, rate in _rows(_section(html, "能力補正")):
        m = NATURE_NAME_RE.match(raw_name)
        if not m:
            continue
        if (en := maps["natures"].get(m.group(1))):
            natures_en.append({"name": en, "rate": rate})
    items_en = [
        {"name": en, "rate": rate}
        for name, rate in _rows(_section(html, "持ち物"))
        if (en := maps["items"].get(name))
    ]
    spreads = _ev_spreads(_section(html, "能力ポイント"))
    default_sp = spreads[0]["sp"] if spreads else None

    if not moves_en and not abilities_en:
        return None  # pokedb page had no usage data for this Pokémon

    # defaultMoves: take top 4 by use rate, THEN reorder so damaging
    # moves appear before status moves (within each group, keep the
    # use-rate order). See project_default_moves_order memory.
    # Example: Staraptor's top 4 by rate are Close Combat / Brave Bird /
    # Roost / Blaze Kick; the displayed order should be Close Combat /
    # Brave Bird / Blaze Kick / Roost (Roost last because it's status).
    cat = maps.get("move_category", {})
    top4 = moves_en[:4]
    damaging = [m for m in top4 if cat.get(m["name"]) in ("physical", "special")]
    status = [m for m in top4 if cat.get(m["name"]) == "status"]
    ordered_defaults = damaging + status

    return {
        "defaultSp": default_sp,
        "abilities": abilities_en,
        "items": items_en,
        "moves": moves_en,
        "defaultMoves": [{"name": m["name"]} for m in ordered_defaults],
        "natures": natures_en,
    }


# ─── Merge into champions_usage.json ─────────────────────────────────

def to_usage_entry(parsed: dict, existing: dict | None) -> dict:
    out: dict = {}
    if parsed.get("defaultSp"):
        out["defaultSp"] = parsed["defaultSp"]
    if existing and "usageRank" in existing:
        out["usageRank"] = existing["usageRank"]

    def with_pct(rows):
        return [
            {"name": r["name"], **({"pct": r["rate"]} if r.get("rate") is not None else {})}
            for r in rows
        ]

    out["abilities"] = with_pct(parsed.get("abilities", []))
    out["items"] = with_pct(parsed.get("items", []))
    out["moves"] = with_pct(parsed.get("moves", []))
    out["defaultMoves"] = parsed.get("defaultMoves", [])
    out["natures"] = with_pct(parsed.get("natures", []))
    return out


# ─── Mega-mirror policy ──────────────────────────────────────────────
# pokedb doesn't rank Mega forms separately. Per project_mega_mirror_policy,
# single-Mega entries (no X/Y/Z suffix) mirror moves/natures/defaultMoves/
# defaultSp from their base form, keeping their own ability+item (from
# mega.json). Multi-form Megas (X/Y/Z) are full-frozen — manual curation.

_XYZ_SUFFIX_RE = re.compile(r"\s+[XYZ]$")


def is_xyz_split(mega_name: str) -> bool:
    return bool(_XYZ_SUFFIX_RE.search(mega_name))


def load_mega_index(repo_root: Path) -> dict[str, dict]:
    """Map mega English name → its mega.json entry (for ability + stone)."""
    megas = json.loads((repo_root / "assets/pokemon/mega.json").read_text(encoding="utf-8"))
    out: dict[str, dict] = {}
    for m in megas:
        if m.get("name", "").startswith("Mega "):
            out[m["name"]] = m
    return out


def base_name_for(mega_name: str) -> str:
    """Strip the 'Mega ' prefix to get the base species name."""
    return mega_name[5:].strip() if mega_name.startswith("Mega ") else mega_name


def mirror_megas_from_base(
    usage: dict, mega_index: dict[str, dict]
) -> tuple[int, int]:
    """For every single-Mega (non X/Y/Z), copy moves/defaultMoves/
    natures/defaultSp from its base form in `usage`. Preserve the
    Mega's own ability + item (from mega.json). Returns (mirrored,
    skipped_xyz)."""
    mirrored = skipped = 0
    for mega_name, mega_meta in mega_index.items():
        if is_xyz_split(mega_name):
            skipped += 1
            continue
        base = base_name_for(mega_name)
        if base not in usage:
            continue  # base lacks data, skip
        base_entry = usage[base]
        mirrored_entry: dict = {}
        if base_entry.get("defaultSp"):
            mirrored_entry["defaultSp"] = base_entry["defaultSp"]
        # Mega's ability: from mega.json's `abilities` (usually 1 entry)
        mega_abilities = mega_meta.get("abilities") or []
        mirrored_entry["abilities"] = [{"name": a} for a in mega_abilities]
        # Mega's item: the required mega stone
        stone = mega_meta.get("requiredItem")
        mirrored_entry["items"] = [{"name": stone}] if stone else []
        # Mirror moves / defaultMoves / natures from base
        mirrored_entry["moves"] = base_entry.get("moves", [])
        mirrored_entry["defaultMoves"] = base_entry.get("defaultMoves", [])
        mirrored_entry["natures"] = base_entry.get("natures", [])
        usage[mega_name] = mirrored_entry
        mirrored += 1
    return mirrored, skipped


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--season", type=int, default=3,
                    help="Season number (3 = Reg M-B)")
    ap.add_argument("--rule", type=int, default=0,
                    help="0 = singles, 1 = doubles")
    ap.add_argument("--cache", default=None,
                    help="Directory to cache downloaded HTML")
    ap.add_argument("--sleep", type=float, default=2.0,
                    help="Per-fetch politeness delay (seconds)")
    args = ap.parse_args()

    cache_dir = Path(args.cache) if args.cache else Path(tempfile.mkdtemp(prefix="pokedb_"))
    cache_dir.mkdir(parents=True, exist_ok=True)
    print(f"cache: {cache_dir}")

    print("fetching ranking page…")
    ids = fetch_ranking(args.season, args.rule)
    print(f"ranking: {len(ids)} Pokémon")

    maps = build_lookups(REPO)
    id_to_en = {pid: pokedb_id_to_en(pid, maps["dex_to_base"]) for pid in ids}
    unmapped = [pid for pid, en in id_to_en.items() if not en]
    if unmapped:
        print(f"WARN unmapped IDs (will skip): {unmapped[:5]}{'...' if len(unmapped) > 5 else ''}")

    # Fetch detail pages
    parsed: dict[str, dict] = {}
    for i, (pid, jp) in enumerate(ids.items(), 1):
        if not id_to_en[pid]:
            continue
        cache_file = cache_dir / f"{pid}.html"
        if not cache_file.exists() or cache_file.stat().st_size < 50_000:
            url = f"{BASE}/pokemon/show/{pid}?season={args.season}&rule={args.rule}"
            try:
                cache_file.write_bytes(http_get(url))
            except Exception as e:
                print(f"  [{i:>3}/{len(ids)}] {pid} ({jp}) fetch ERROR: {e}")
                continue
            time.sleep(args.sleep)
        try:
            entry = parse_detail(cache_file.read_text(encoding="utf-8"), maps)
            if entry:
                parsed[pid] = entry
        except Exception as e:
            print(f"  [{i:>3}/{len(ids)}] {pid} ({jp}) parse ERROR: {e}")
        if i % 25 == 0 or i == len(ids):
            print(f"  [{i:>3}/{len(ids)}] parsed={len(parsed)}")

    # Merge into champions_usage.json
    usage = json.loads(USAGE_PATH.read_text(encoding="utf-8"))
    replaced = added = skipped = 0
    for pid, entry in parsed.items():
        en = id_to_en[pid]
        existing = usage.get(en)
        new_entry = to_usage_entry(entry, existing)
        if existing is None:
            added += 1
        elif existing == new_entry:
            skipped += 1
        else:
            replaced += 1
        usage[en] = new_entry

    # Mirror single-Mega entries from their refreshed base forms.
    # X/Y/Z split megas (user-curated) are left alone.
    mega_index = load_mega_index(REPO)
    mirrored, skipped_xyz = mirror_megas_from_base(usage, mega_index)
    print(f"mega mirror: mirrored={mirrored} skipped_xyz={skipped_xyz}")

    if "_meta" in usage:
        usage["_meta"]["source"] = (
            "Pokemon Champions in-game Battle Data via champs.pokedb.tokyo"
        )
        usage["_meta"]["format"] = f"Regulation M-B / Season M-{args.season}"
        usage["_meta"]["updatedAt"] = time.strftime("%Y-%m-%d")
        usage["_meta"]["curatedBy"] = (
            "auto: champs.pokedb.tokyo (defaultMoves = top 4 by usage)"
        )

    USAGE_PATH.write_text(
        json.dumps(usage, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print()
    print(f"Done. replaced={replaced} added={added} skipped={skipped} "
          f"unmapped={len(unmapped)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
