#!/usr/bin/env python3
"""Generate ``assets/inverse_learnsets.json`` from ``assets/learnsets.json``.

The forward learnsets file maps each Showdown pokemon ID to its move pool.
For the move dex's "who learns this move" view we need the inverse —
move ID → list of pokemon IDs. Building it at runtime walks ~75K (id, move)
pairs every cold launch and pushes a frame; a static asset turns it into a
single JSON parse.

Re-run this whenever assets/learnsets.json changes.

Usage:
    python3 tools/build_inverse_learnsets.py
"""
from __future__ import annotations

import json
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO_ROOT, "assets", "learnsets.json")
DST = os.path.join(REPO_ROOT, "assets", "inverse_learnsets.json")


def main() -> None:
    with open(SRC, encoding="utf-8") as f:
        forward = json.load(f)

    inverse: dict[str, list[str]] = {}
    for pokemon_id, payload in forward.items():
        # Skip the meta entry (regional form lookup table).
        if pokemon_id.startswith("_"):
            continue
        if not isinstance(payload, list):
            continue
        for move_id in payload:
            inverse.setdefault(move_id, []).append(pokemon_id)

    # Sort each move's learner list for stable output (and so the asset
    # diff is human-readable when learnsets change).
    for k in inverse:
        inverse[k].sort()

    with open(DST, "w", encoding="utf-8") as f:
        json.dump(inverse, f, ensure_ascii=False, separators=(",", ":"))
        f.write("\n")

    move_count = len(inverse)
    pair_count = sum(len(v) for v in inverse.values())
    print(f"Wrote {DST}")
    print(f"  {move_count} moves, {pair_count} (move, pokemon) pairs")


if __name__ == "__main__":
    main()
