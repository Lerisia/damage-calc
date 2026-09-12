"""Shared JA → EN name mapping for the Champions scrapers.

pokechamdb, champs.pokedb.tokyo (and whatever comes next) publish moves /
abilities / items / natures in Japanese; our data keys are the English
names in assets/. Every scraper used to build its own tables and its own
kana normalisation, so a fix landed in one and not the others (the
Toxtricity-form merge, the Sand Veil typo, kana-casing mismatches).
This module is the one place:

  * norm_ja()         — NFKC + katakana→hiragana fold, so the sites'
                        kana casing joins ours without per-name tables
  * JA_NAME_FIXUPS    — genuine spelling variants (typos, ヴィ vs ビ)
  * NATURE_JA_TO_EN   — the fixed 25 natures
  * ja_to_en_maps()   — {"abilities","items","moves"}: norm_ja(nameJa)
                        → our English key, built from assets/
  * map_ja()          — one lookup that applies norm + fixups

Run `python3 tools/test_namemap.py` after touching any of it.
"""
from __future__ import annotations

import json
import unicodedata
from pathlib import Path


def norm_ja(s: str) -> str:
    """NFKC (folds full-width digits/latin) + katakana→hiragana so the
    sites' kana spellings join ours (どくのトゲ vs どくのとげ, ゲップ vs
    げっぷ, ようせいのはね vs ようせいのハネ). The long-vowel mark ー and
    punctuation are left alone; genuine spelling variants still need
    [JA_NAME_FIXUPS]."""
    s = unicodedata.normalize("NFKC", s).strip()
    out = []
    for ch in s:
        o = ord(ch)
        # Katakana block U+30A1–U+30F6 → hiragana (−0x60).
        out.append(chr(o - 0x60) if 0x30A1 <= o <= 0x30F6 else ch)
    return "".join(out)


# Site spelling → our spelling, keyed and valued in the folded form (see
# norm_ja), so only real variants live here. Extend as a scraper's
# "UNMAPPED" log surfaces new ones.
JA_NAME_FIXUPS: dict[str, str] = {
    "すなかくれ": "すながくれ",       # Sand Veil (pokechamdb typo)
    "へびーめたる": "へゔぃめたる",   # Heavy Metal (ビ vs ヴィ)
    "きょうそうしん": "かちき",        # Competitive (alt JP name)
}

# Nature JP → our English (capitalized) name. Fixed 25-value set.
NATURE_JA_TO_EN: dict[str, str] = {
    "がんばりや": "Hardy", "さみしがり": "Lonely", "いじっぱり": "Adamant",
    "やんちゃ": "Naughty", "ゆうかん": "Brave", "ずぶとい": "Bold",
    "すなお": "Docile", "わんぱく": "Impish", "のうてんき": "Lax",
    "のんき": "Relaxed", "ひかえめ": "Modest", "おっとり": "Mild",
    "てれや": "Bashful", "うっかりや": "Rash", "れいせい": "Quiet",
    "おだやか": "Calm", "おとなしい": "Gentle", "しんちょう": "Careful",
    "きまぐれ": "Quirky", "なまいき": "Sassy", "おくびょう": "Timid",
    "せっかち": "Hasty", "ようき": "Jolly", "むじゃき": "Naive",
    "まじめ": "Serious",
}


def _load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def ja_to_en_maps(repo: Path) -> dict[str, dict[str, str]]:
    """norm_ja(nameJa) → English key, for abilities, items and moves,
    built from assets/. A duplicated Japanese name keeps its first
    English key (move files are read in sorted order)."""
    abilities: dict[str, str] = {}
    for a in _load(repo / "assets/abilities.json"):
        if a.get("nameJa") and a.get("name"):
            abilities.setdefault(norm_ja(a["nameJa"]), a["name"])
    items: dict[str, str] = {}
    for it in _load(repo / "assets/items.json"):
        if it.get("nameJa") and it.get("name"):
            items.setdefault(norm_ja(it["nameJa"]), it["name"])
    moves: dict[str, str] = {}
    for path in sorted((repo / "assets/moves").glob("*.json")):
        for m in _load(path):
            if m.get("nameJa") and m.get("name"):
                moves.setdefault(norm_ja(m["nameJa"]), m["name"])
    return {"abilities": abilities, "items": items, "moves": moves}


def map_ja(name: str, table: dict[str, str]) -> str | None:
    """Resolve a site-provided Japanese name through fold + fixups."""
    key = norm_ja(name)
    key = norm_ja(JA_NAME_FIXUPS.get(key, key))
    return table.get(key)


def nature_ja_to_en(name: str) -> str | None:
    return NATURE_JA_TO_EN.get(norm_ja(name))
