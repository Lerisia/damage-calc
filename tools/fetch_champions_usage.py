#!/usr/bin/env python3
"""
Crawl Pikalytics `championstournaments` usage stats for every Pokemon
in our dex and write to `assets/champions_usage.json`.

Structure per pokemon:
    {
      "abilities": [{"name": "Rough Skin", "pct": 90.731}, ...],
      "items":     [{"name": "Choice Scarf", "pct": 26.545}, ...],   # top 5
      "moves":     [{"name": "Earthquake", "pct": 89.948}, ...],     # top 10
    }

Pokemon not present in Pokemon Champions (404 on Pikalytics) are
skipped silently.

Run from repo root:
    python3 tools/fetch_champions_usage.py

Re-running overwrites the file. Checkpoints every 25 pokemon so a
Ctrl-C / crash doesn't lose progress — just re-run and it'll skip
names already in the file.
"""

import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
POKE_DIR = REPO / "assets" / "pokemon"
OUT = REPO / "assets" / "champions_usage.json"
HEADERS = {
    "User-Agent": "damage-calc/1.0 (stats crawler; github.com/Lerisia/damage-calc)",
    "Accept": "text/html",
}

REQUEST_DELAY_S = 1.0
CHECKPOINT_EVERY = 25
REQUEST_TIMEOUT_S = 20
RETRY_ONCE = True

TOP_ITEMS = 5
TOP_MOVES = 10

# Section headers on the pikalytics page — each section is demarcated by
# one of these <h2> texts. Order matters (we use the adjacent header
# offsets to slice the HTML).
SECTION_HEADERS = [
    ("Best Moves for",      "moves"),
    ("Best Teammates for",  "teammates"),  # we don't store these
    ("Best Items for",      "items"),
    ("Best Abilities for",  "abilities"),
    ("Best Tera Types for", "teras"),      # skipped
    ("Best Spreads for",    "spreads"),    # skipped
    ("Best Nature for",     "natures"),    # skipped
]

ENTRY_RE = re.compile(
    r'pokedex-move-entry-new.*?'
    r'pokedex-inline-text-offset">([^<]+)</div>.*?'
    r'pokedex-inline-right">([\d.]+)%',
    re.DOTALL,
)


def all_pokemon_names() -> list[str]:
    names: list[str] = []
    seen: set[str] = set()
    for gen_file in sorted(POKE_DIR.glob("*.json")):
        data = json.loads(gen_file.read_text(encoding="utf-8"))
        for entry in data:
            if entry.get("hidden"):
                continue
            name = entry["name"]
            if name in seen:
                continue
            seen.add(name)
            names.append(name)
    return names


def fetch(url: str) -> str | None:
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT_S) as r:
            return r.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise
    # timeouts / connection errors bubble up


def slice_sections(html: str) -> dict[str, str]:
    """Find each section's <h2> offset, then slice HTML between
    consecutive headers. Returns a map of section name → raw HTML."""
    offsets: list[tuple[int, str]] = []
    for header_text, key in SECTION_HEADERS:
        # First occurrence only — later ones are mustache templates
        idx = html.find(f"<h2")
        # Just use .find on the header_text itself — headers are unique
        match_idx = html.find(header_text)
        if match_idx >= 0:
            offsets.append((match_idx, key))
    offsets.sort()
    sections: dict[str, str] = {}
    for i, (start, key) in enumerate(offsets):
        end = offsets[i + 1][0] if i + 1 < len(offsets) else len(html)
        sections[key] = html[start:end]
    return sections


def parse_entries(section_html: str) -> list[dict]:
    out: list[dict] = []
    seen: set[str] = set()
    for m in ENTRY_RE.finditer(section_html):
        name = m.group(1).strip()
        pct = float(m.group(2))
        if name in seen:
            continue
        seen.add(name)
        out.append({"name": name, "pct": pct})
    # Pikalytics already sorts by descending %, but be defensive.
    out.sort(key=lambda e: -e["pct"])
    return out


def scrape_one(pokemon_name: str) -> dict | None:
    # Champions URLs preserve the spaces; urllib.parse.quote handles it.
    encoded = urllib.parse.quote(pokemon_name)
    url = f"https://www.pikalytics.com/pokedex/championstournaments/{encoded}"
    html = fetch(url)
    if html is None:
        return None
    sections = slice_sections(html)
    moves = parse_entries(sections.get("moves", ""))[:TOP_MOVES]
    items = parse_entries(sections.get("items", ""))[:TOP_ITEMS]
    abilities = parse_entries(sections.get("abilities", ""))
    return {
        "abilities": abilities,
        "items": items,
        "moves": moves,
    }


def load_checkpoint() -> dict:
    if OUT.exists():
        try:
            return json.loads(OUT.read_text(encoding="utf-8"))
        except Exception:
            pass
    return {"_meta": {}}


def save(data: dict) -> None:
    data["_meta"]["source"] = "pikalytics.com/pokedex/championstournaments"
    data["_meta"]["updatedAt"] = datetime.now(timezone.utc).isoformat()
    data["_meta"]["count"] = sum(
        1 for k in data.keys() if not k.startswith("_")
    )
    OUT.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    names = all_pokemon_names()
    data = load_checkpoint()
    print(f"Total pokemon: {len(names)}")
    print(f"Already cached: {data['_meta'].get('count', 0)}")
    todo = [n for n in names if n not in data]
    print(f"To fetch: {len(todo)}\n")

    processed_since_save = 0
    found = 0
    missed = 0
    errored = 0
    started = time.monotonic()

    for i, name in enumerate(todo, 1):
        try:
            stats = scrape_one(name)
        except Exception as exc:
            if RETRY_ONCE:
                time.sleep(2)
                try:
                    stats = scrape_one(name)
                except Exception as exc2:
                    print(f"  [err] {name}: {exc2}")
                    errored += 1
                    continue
            else:
                print(f"  [err] {name}: {exc}")
                errored += 1
                continue

        if stats is None:
            missed += 1
            # Mark as missing so we don't re-fetch on the next run.
            data[name] = None
        else:
            found += 1
            data[name] = stats

        processed_since_save += 1
        if i % 10 == 0:
            elapsed = time.monotonic() - started
            rate = i / elapsed if elapsed else 0
            eta = (len(todo) - i) / rate if rate else 0
            print(
                f"  [{i:4}/{len(todo)}] {name:28} "
                f"found={found} missed={missed} err={errored} "
                f"ETA={int(eta // 60)}m{int(eta % 60):02d}s"
            )
        if processed_since_save >= CHECKPOINT_EVERY:
            save(data)
            processed_since_save = 0

        time.sleep(REQUEST_DELAY_S)

    save(data)
    print(
        f"\nDone. found={found} missed={missed} err={errored} "
        f"total cached entries={data['_meta']['count']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
