#!/usr/bin/env python3
"""Checks for tools/namemap.py against the real assets.

    python3 tools/test_namemap.py
"""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from namemap import (JA_NAME_FIXUPS, NATURE_JA_TO_EN, ja_to_en_maps, map_ja,
                     nature_ja_to_en, norm_ja)

REPO = pathlib.Path(__file__).resolve().parent.parent


def test_norm_folds_kana_and_width():
    assert norm_ja("どくのトゲ") == norm_ja("どくのとげ")
    assert norm_ja("ゲップ") == "げっぷ"
    assert norm_ja("１０まんボルト") == "10まんぼると"
    assert norm_ja("ハイドロポンプ") != norm_ja("ハイドロカノン")


def test_assets_resolve():
    maps = ja_to_en_maps(REPO)
    assert map_ja("たべのこし", maps["items"]) == "leftovers"
    assert map_ja("こだわりスカーフ", maps["items"]) == "choice-scarf"
    assert map_ja("じしん", maps["moves"]) == "Earthquake"
    assert map_ja("ワイドフォース", maps["moves"]) == "Expanding Force"
    assert map_ja("もらいび", maps["abilities"]) == "Flash Fire"
    assert map_ja("そうだいしょう", maps["abilities"]) == "Supreme Overlord"


def test_fixups_apply():
    maps = ja_to_en_maps(REPO)
    assert map_ja("すなかくれ", maps["abilities"]) == "Sand Veil"     # pokechamdb typo
    assert map_ja("きょうそうしん", maps["abilities"]) == "Competitive"
    for k, v in JA_NAME_FIXUPS.items():
        assert k == norm_ja(k) and v == norm_ja(v), "fixups must be stored folded"


def test_natures_match_nature_dart():
    text = (REPO / "lib/models/nature.dart").read_text(encoding="utf-8")
    dart = {
        ja: en[0].upper() + en[1:]
        for en, ja in re.findall(r"(\w+):\s*'([^']+)'", text)
        if any("぀" <= c <= "ヿ" for c in ja)
    }
    assert len(dart) == 25
    assert {norm_ja(k): v for k, v in dart.items()} == NATURE_JA_TO_EN
    assert nature_ja_to_en("ようき") == "Jolly"
    assert nature_ja_to_en("ヨウキ") == "Jolly"


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("ok", name)
