#!/usr/bin/env python3
"""
Apply spread-target tags to damaging moves in assets/moves/*.json.

Source: Pokemon Showdown's moves.ts `target` field. Two groups matter for
Doubles damage reduction:
- allAdjacentFoes → foes-only spread (Rock Slide, Heat Wave, Hyper Voice, ...)
- allAdjacent    → foes + ally spread (Earthquake, Surf, Explosion, ...)

Both receive the 0.75× multiplier when hitting 2 targets. The allAdjacent
group additionally gets `custom:spread_hits_ally` so future 2v2 logic can
route ally damage without re-looking-up the target type.

Status moves (Growl, Leer, Poison Gas, ...) are skipped — they carry the
same targeting flag but no damage multiplier applies.

Z-moves / CAP moves are skipped (Showdown `num >= 905` or negative `num`).
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MOVES_DIR = ROOT / "assets" / "moves"

# Damaging spread moves — allAdjacentFoes (hits both opponents only)
FOES_ONLY = {
    "Acid", "Air Cutter", "Astral Barrage", "Bleakwind Storm", "Blizzard",
    "Breaking Swipe", "Bubble", "Burning Jealousy", "Clanging Scales",
    "Core Enforcer", "Dazzling Gleam", "Diamond Storm", "Disarming Voice",
    "Dragon Energy", "Electroweb", "Eruption", "Fiery Wrath", "Glacial Lance",
    "Glaciate", "Heat Wave", "Hyper Voice", "Icy Wind", "Incinerate",
    "Land's Wrath", "Make It Rain", "Matcha Gotcha", "Mortal Spin",
    "Muddy Water", "Origin Pulse", "Overdrive", "Powder Snow",
    "Precipice Blades", "Razor Leaf", "Razor Wind", "Relic Song",
    "Rock Slide", "Sandsear Storm", "Shell Trap", "Snarl", "Splishy Splash",
    "Springtide Storm", "Struggle Bug", "Swift", "Thousand Arrows",
    "Thousand Waves", "Twister", "Water Spout", "Wildbolt Storm",
}

# Damaging spread moves — allAdjacent (hits both opponents + ally)
ALL_ADJACENT = {
    "Boomburst", "Brutal Swing", "Bulldoze", "Discharge", "Earthquake",
    "Explosion", "Lava Plume", "Magnitude", "Mind Blown", "Misty Explosion",
    "Parabolic Charge", "Petal Blizzard", "Searing Shot", "Self-Destruct",
    "Sludge Wave", "Sparkling Aria", "Surf", "Synchronoise",
}

SPREAD_TAG = "custom:spread"
HITS_ALLY_TAG = "custom:spread_hits_ally"


def main() -> int:
    tagged = 0
    missing: list[str] = []
    all_targets = FOES_ONLY | ALL_ADJACENT
    seen: set[str] = set()

    for path in sorted(MOVES_DIR.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        changed = False
        for move in data:
            name = move.get("name")
            if name not in all_targets:
                continue
            seen.add(name)
            tags = move.get("tags") or []
            # Skip if already tagged (idempotent)
            need_spread = SPREAD_TAG not in tags
            need_ally = (name in ALL_ADJACENT) and (HITS_ALLY_TAG not in tags)
            if not need_spread and not need_ally:
                continue
            if need_spread:
                tags.append(SPREAD_TAG)
            if need_ally:
                tags.append(HITS_ALLY_TAG)
            move["tags"] = tags
            changed = True
            tagged += 1
        if changed:
            path.write_text(
                json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            print(f"Updated: {path.name}")

    missing = sorted(all_targets - seen)
    print(f"\nTagged {tagged} move entries.")
    if missing:
        print(f"Not present in our moves data ({len(missing)}):")
        for m in missing:
            print(f"  {m}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
