#!/usr/bin/env python3
"""Compare our movedex flags with the Champions ROM dump.

projectpokemon/champout's masterdata/waza.json carries each move's
contact flag (`direct`) and up to two category codes (punch, sound,
slice, wind, powder, ball, pulse, bite, …). Champions rebalances these
without notice — Double Shock became a punch in v1.2.0 — and the
calculator's Iron Fist / Sharpness / Punk Rock / Strong Jaw / Bulletproof
handling keys off our tags. Run after every game patch (the daily cron
does) and fix whatever it prints.

    python3 tools/audit_move_flags.py          # report, exit 1 on mismatch
    python3 tools/audit_move_flags.py --apply  # also add missing tags

Only moves in the Champions allowlist are checked, and only the flags
we model. Extra tags on our side are reported but not removed.
"""
from __future__ import annotations

import glob
import json
import sys
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RAW = "https://raw.githubusercontent.com/projectpokemon/champout/main/"
CODE = {"1": "punch", "2": "sound", "4": "slice", "5": "wind",
        "6": "powder", "7": "ball", "8": "pulse", "9": "bite"}
FLAGS = {"contact", *CODE.values()}


def fetch(path: str) -> str:
    req = urllib.request.Request(RAW + path, headers={"User-Agent": "damage-calc/1"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8")


def main() -> int:
    apply = "--apply" in sys.argv
    waza = {int(m["id"]): m for m in json.loads(fetch("masterdata/waza.json"))}
    names = {}
    for line in fetch("parse/move_availability.txt").splitlines():
        if "\t" in line:
            i, n = line.split("\t", 1)
            names[int(i)] = n.strip()
    files = {}
    ours = {}
    for f in sorted(glob.glob(str(REPO / "assets/moves/*.json"))):
        data = json.loads(Path(f).read_text(encoding="utf-8"))
        files[f] = data
        for m in data:
            ours[m["name"]] = (f, m)
    mismatches = []
    for i, name in names.items():
        if name not in ours:
            continue
        m = waza[i]
        rom = set()
        if m["direct"] == "1":
            rom.add("contact")
        for key in ("classification_a", "classification_b"):
            if m[key] in CODE:
                rom.add(CODE[m[key]])
        f, o = ours[name]
        mine = {t for t in (o.get("tags") or []) if t in FLAGS}
        if rom != mine:
            mismatches.append((name, sorted(rom - mine), sorted(mine - rom), f, o))
    if not mismatches:
        print(f"move flags: {len(names)} legal moves, all match the ROM")
        return 0
    print(f"WARN move flags: {len(mismatches)} mismatch(es) vs the ROM")
    touched = set()
    for name, add, extra, f, o in mismatches:
        print(f"  {name}: ROM has {add or '-'}; only ours has {extra or '-'}")
        if apply and add:
            o["tags"] = sorted(set(o.get("tags") or []) | set(add))
            touched.add(f)
    if apply:
        for f in touched:
            Path(f).write_text(json.dumps(files[f], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"applied to {len(touched)} file(s)")
    return 1


if __name__ == "__main__":
    sys.exit(main())
