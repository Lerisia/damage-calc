#!/usr/bin/env python3
"""
Scrape Pokemon Champions (포챔) confirmed Pokemon and their learnsets from
yakkun.com/ch/. Outputs raw Japanese data to assets/champions_learnsets_raw.json.

Yakkun is datamine-sourced (not Showdown), so this is closer to the official
game data than our Showdown-derived learnsets.json.

Output format:
{
  "n6": {
    "dex": 6,
    "form": "",              // "", "m", "x", "y", "a", "g", "h", etc.
    "name_ja": "リザードン",
    "moves_ja": ["ギガインパクト", "かえんほうしゃ", ...]
  },
  "n6x": {...},
  ...
}

Politeness: 1.5s between requests, ~5-7 min total for 275 Pokemon.
Run: python3 tools/scrape_champions.py [--limit N] [--resume]
"""

import json
import re
import sys
import time
from pathlib import Path

from bs4 import BeautifulSoup
from curl_cffi import requests

OFFER_URL = "https://yakkun.com/ch/zukan/offer/"
POKEMON_URL = "https://yakkun.com/ch/zukan/{slug}"
OUT_PATH = Path(__file__).resolve().parent / "data" / "champions_learnsets_raw.json"

DELAY = 1.5  # seconds between requests


def fetch(url: str) -> str:
    r = requests.get(url, impersonate="chrome120")
    if r.status_code != 200:
        raise RuntimeError(f"HTTP {r.status_code} for {url}")
    return r.content.decode("euc-jp", errors="replace")


def parse_offer_page(html: str) -> list[dict]:
    """Returns list of confirmed Pokemon entries from the Champions offer page."""
    soup = BeautifulSoup(html, "html.parser")
    ul = soup.select_one("ul.pokemon_list")
    if ul is None:
        raise RuntimeError("Could not locate ul.pokemon_list")

    entries = []
    for li in ul.find_all("li", recursive=False):
        classes = li.get("class") or []
        if "nodata" in classes:
            continue  # not in Champions
        a = li.select_one(".name a")
        if not a:
            continue
        m = re.search(r"/ch/zukan/(n(\d+)([a-z]?))", a.get("href", ""))
        if not m:
            continue
        slug = m.group(1)
        dex = int(m.group(2))
        form = m.group(3)
        name_ja = a.get_text(strip=True)
        entries.append({"slug": slug, "dex": dex, "form": form, "name_ja": name_ja})
    return entries


def parse_pokemon_page(html: str) -> list[str]:
    """Returns the Japanese names of moves learnable in Champions."""
    soup = BeautifulSoup(html, "html.parser")
    # Move table is the one whose first row is "◆ {name}が覚える技".
    move_table = None
    for tbl in soup.find_all("table"):
        first = tbl.find("tr")
        if first and "が覚える技" in first.get_text():
            move_table = tbl
            break
    if move_table is None:
        return []

    moves = []
    for row in move_table.find_all("tr"):
        classes = row.get("class") or []
        if "move_main_row" not in classes:
            continue
        if "past_move" in classes:
            continue  # not learnable in Champions
        cell = row.select_one("td.move_name_cell")
        if not cell:
            continue
        a = cell.find("a")
        name_ja = a.get_text(strip=True) if a else cell.get_text(strip=True).split()[0]
        if name_ja:
            moves.append(name_ja)
    return moves


def load_cache() -> dict:
    if OUT_PATH.exists():
        try:
            return json.loads(OUT_PATH.read_text(encoding="utf-8"))
        except Exception:
            return {}
    return {}


def save_cache(data: dict) -> None:
    OUT_PATH.write_text(
        json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True),
        encoding="utf-8",
    )


def main() -> int:
    args = sys.argv[1:]
    limit = None
    resume = False
    for arg in args:
        if arg.startswith("--limit"):
            limit = int(arg.split("=", 1)[1]) if "=" in arg else int(args[args.index(arg) + 1])
        elif arg == "--resume":
            resume = True

    print("Fetching offer list…")
    offer_html = fetch(OFFER_URL)
    entries = parse_offer_page(offer_html)
    print(f"  {len(entries)} confirmed Pokemon")
    if limit:
        entries = entries[:limit]
        print(f"  Limited to {limit}")

    cache = load_cache() if resume else {}
    done = 0
    for i, entry in enumerate(entries, 1):
        slug = entry["slug"]
        if resume and slug in cache and cache[slug].get("moves_ja"):
            continue
        url = POKEMON_URL.format(slug=slug)
        try:
            html = fetch(url)
            moves = parse_pokemon_page(html)
        except Exception as e:
            print(f"  [{i}/{len(entries)}] {slug} ({entry['name_ja']}): ERROR {e}")
            continue
        cache[slug] = {**entry, "moves_ja": moves}
        done += 1
        print(f"  [{i}/{len(entries)}] {slug} {entry['name_ja']}: {len(moves)} moves")
        if done % 20 == 0:
            save_cache(cache)
        time.sleep(DELAY)

    save_cache(cache)
    print(f"Saved {len(cache)} entries to {OUT_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
