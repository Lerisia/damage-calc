#!/usr/bin/env python3
"""Build the Champions-legal move allowlist from yakkun's move list.

Champions (the game) ships a restricted move roster — a subset of the
national-dex movepool. Neither pkmnchamps' API nor our champions_usage
data expose the legal set: the API's `allowed` list is items-only, and
usage data only surfaces moves people actually ran (a legal-but-unused
move never appears). yakkun's /ch/move_list.htm is the one source that
enumerates the full Champions move roster (~497 moves), so we scrape it
into an allowlist asset the app reads to hide non-Champions moves when
"Champions only" is on.

Match strategy: yakkun lists moves by Japanese name; we map those to
our English move keys via each move's `nameJa` in assets/moves/*.json.
NFKC normalization folds full-width digits/latin (１０まんボルト →
10まんボルト) so the join is exact — verified 497/497 with zero
ambiguity at authoring time.

Output: assets/champions_moves.json
  {
    "_meta": { "source": ..., "updatedAt": ..., "count": N },
    "moves": ["Earthquake", "Moonblast", ...]   // English keys, sorted
  }

Usage:
    python3 tools/fetch_champions_moves.py

Re-run after a Champions patch changes the move roster. If yakkun's
markup shifts and the scrape yields an implausibly small set, the
tool aborts rather than shipping a truncated allowlist that would
hide legal moves.
"""
from __future__ import annotations

import json
import re
import sys
import time
import unicodedata
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MOVES_DIR = REPO / "assets" / "moves"
OUT_PATH = REPO / "assets" / "champions_moves.json"
URL = "https://yakkun.com/ch/move_list.htm"

# Below this, assume the scrape broke (markup drift, partial page) and
# refuse to overwrite — hiding legal moves is worse than a stale list.
MIN_PLAUSIBLE = 400


def norm(s: str) -> str:
    """NFKC so full-width digits/latin fold to half-width, matching
    across yakkun's and our own JP spellings."""
    return unicodedata.normalize("NFKC", s).strip()


def fetch_yakkun_ja() -> set[str]:
    req = urllib.request.Request(
        URL,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/605.1.15 (KHTML, like Gecko) "
                "Version/17.4 Safari/605.1.15"
            ),
            "Accept": "text/html",
            "Accept-Language": "ja",
        },
    )
    # yakkun serves EUC-JP.
    html = urllib.request.urlopen(req, timeout=20).read().decode(
        "euc-jp", errors="ignore")
    rows = re.findall(r'search/\?move=\d+"[^>]*>([^<]+)</a>', html)
    return {norm(name) for name in rows}


def build_ja_to_english() -> dict[str, list[str]]:
    out: dict[str, list[str]] = {}
    for f in sorted(MOVES_DIR.glob("*.json")):
        for m in json.loads(f.read_text(encoding="utf-8")):
            ja = m.get("nameJa")
            if ja:
                out.setdefault(norm(ja), []).append(m["name"])
    return out


def main() -> int:
    print(f"fetching {URL} …")
    yakkun = fetch_yakkun_ja()
    print(f"yakkun champions moves: {len(yakkun)}")
    if len(yakkun) < MIN_PLAUSIBLE:
        print(f"ABORT: only {len(yakkun)} moves scraped (< {MIN_PLAUSIBLE}). "
              "yakkun markup likely changed — not overwriting.")
        return 1

    ja_to_en = build_ja_to_english()
    english: set[str] = set()
    unmatched: list[str] = []
    for ja in yakkun:
        hit = ja_to_en.get(ja)
        if hit:
            english.update(hit)
        else:
            unmatched.append(ja)

    if unmatched:
        print(f"WARN {len(unmatched)} yakkun moves didn't map to our "
              f"movedex (will be omitted):")
        for u in sorted(unmatched):
            print(f"  {u}")

    payload = {
        "_meta": {
            "source": "yakkun.com/ch/move_list.htm (Champions move roster)",
            "updatedAt": time.strftime("%Y-%m-%d"),
            "count": len(english),
        },
        "moves": sorted(english),
    }
    OUT_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"\nwrote {OUT_PATH}  ({len(english)} moves)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
