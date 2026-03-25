#!/usr/bin/env python3
"""
Build learnsets.json from Showdown's learnsets.ts

Rules:
1. Use the most recent MAINLINE generation the Pokemon appears in.
   (SV=9 > SwSh=8 > SM=7 > ORAS=6 > XY=6 > BW=5 > ...)
2. Include moves learnable in that generation (level, TM, tutor, egg).
3. Also include moves newly added in Legends Z-A (code "10" prefix if exists).
4. Pre-evolution moves are inherited by all evolutions in the chain.
5. EXCLUDE:
   - Let's Go codes (V suffix, e.g. "8V")
   - BDSP codes (B suffix, e.g. "8B")
   - Event-only moves (S suffix) are EXCLUDED unless also learnable by other means.
   - Reminder-only moves that aren't learnable in the target gen.

Usage:
  python3 tools/build_learnsets.py
  # Outputs: assets/learnsets.json
"""

import json
import re
import sys
import urllib.request

SHOWDOWN_LEARNSETS_URL = (
    "https://raw.githubusercontent.com/smogon/pokemon-showdown/master/data/learnsets.ts"
)
SHOWDOWN_POKEDEX_URL = (
    "https://raw.githubusercontent.com/smogon/pokemon-showdown/master/data/pokedex.ts"
)

# Codes to EXCLUDE regardless of generation
EXCLUDED_SUFFIXES = {'V', 'B'}  # V=Let's Go, B=BDSP

# Max mainline generation to consider
MAX_GEN = 9


def download(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    return urllib.request.urlopen(req).read().decode("utf-8")


def parse_ts_object(ts_text: str) -> dict:
    """
    Rough parser for Showdown's TypeScript object exports.
    Extracts { pokemon: { move: [codes] } } structure.
    """
    result = {}
    current_pokemon = None
    current_learnset = None

    for line in ts_text.split("\n"):
        line = line.strip()

        # Match pokemon entry: "bulbasaur: {"
        m = re.match(r'^(\w+):\s*\{', line)
        if m and current_pokemon is None:
            current_pokemon = m.group(1)
            current_learnset = None
            continue

        # Match learnset start: "learnset: {"
        if current_pokemon and line == "learnset: {":
            current_learnset = {}
            continue

        # Match move entry: "movename: ["code1", "code2"],"
        if current_learnset is not None:
            m = re.match(r'^(\w+):\s*\[(.+?)\],?$', line)
            if m:
                move_name = m.group(1)
                codes_str = m.group(2)
                codes = re.findall(r'"([^"]+)"', codes_str)
                current_learnset[move_name] = codes
                continue

            # End of learnset
            if line.startswith("}"):
                if current_learnset is not None and current_pokemon:
                    result[current_pokemon] = current_learnset
                    current_learnset = None
                    # Check if this also closes the pokemon
                    if line == "},":
                        current_pokemon = None
                continue

        # End of pokemon
        if current_pokemon and line in ("}", "},"):
            if current_learnset and current_pokemon:
                result[current_pokemon] = current_learnset
            current_pokemon = None
            current_learnset = None

    return result


def parse_pokedex(ts_text: str) -> dict:
    """Parse Showdown's pokedex.ts for evolution chains."""
    evos = {}  # pokemon -> [evo1, evo2, ...]
    prevos = {}  # pokemon -> prevo

    for line in ts_text.split("\n"):
        line = line.strip()
        # Match: evos: ["Ivysaur"],
        m = re.match(r'^evos:\s*\[(.+?)\],?$', line)
        if m:
            pass  # We'll use a different approach

    # Simpler: extract prevo fields
    current = None
    for line in ts_text.split("\n"):
        line = line.strip()
        m = re.match(r'^(\w+):\s*\{', line)
        if m:
            current = m.group(1)
            continue
        if current:
            m = re.match(r'^prevo:\s*"(\w+)"', line)
            if m:
                prevos[current] = m.group(1)
            m = re.match(r'^evos:\s*\[(.+?)\]', line)
            if m:
                evo_names = re.findall(r'"(\w+)"', m.group(1))
                # Convert to lowercase IDs
                evo_ids = [e.lower().replace(" ", "").replace("-", "").replace(".", "")
                           .replace("'", "").replace(":", "").replace("%", "") for e in evo_names]
                evos[current] = evo_ids
        if line in ("}", "},"):
            current = None

    return prevos, evos


def parse_code(code: str):
    """
    Parse a Showdown learnset code like "9M", "8L10", "7E", "8V".
    Returns (generation: int, source: str) or None if invalid.
    """
    m = re.match(r'^(\d+)([A-Z])', code)
    if not m:
        return None
    gen = int(m.group(1))
    source = m.group(2)
    return gen, source


def find_latest_mainline_gen(codes: list[str]) -> int:
    """
    Find the most recent mainline generation a move is available in.
    Excludes Let's Go (V) and BDSP (B) codes.
    """
    best = 0
    for code in codes:
        parsed = parse_code(code)
        if parsed is None:
            continue
        gen, source = parsed
        if source in EXCLUDED_SUFFIXES:
            continue
        if gen > best:
            best = gen
    return best


def get_pokemon_latest_gen(learnsets: dict, pokemon_id: str) -> int:
    """
    Determine the most recent mainline generation a Pokemon appears in,
    by checking the highest generation code across all its moves.
    """
    if pokemon_id not in learnsets:
        return 0
    moves = learnsets[pokemon_id]
    best = 0
    for codes in moves.values():
        for code in codes:
            parsed = parse_code(code)
            if parsed is None:
                continue
            gen, source = parsed
            if source in EXCLUDED_SUFFIXES:
                continue
            if gen > best:
                best = gen
    return best


def get_learnable_moves(learnsets: dict, pokemon_id: str, target_gen: int) -> set:
    """
    Get moves learnable by a Pokemon in the target generation.
    A move is learnable if it has any code from target_gen
    (excluding V and B suffixes, and excluding event-only S codes).
    """
    if pokemon_id not in learnsets:
        return set()

    moves = learnsets[pokemon_id]
    result = set()

    for move, codes in moves.items():
        has_target_gen = False
        has_non_event = False

        for code in codes:
            parsed = parse_code(code)
            if parsed is None:
                continue
            gen, source = parsed
            if source in EXCLUDED_SUFFIXES:
                continue
            if gen == target_gen:
                has_target_gen = True
                if source != 'S':  # Not event-only
                    has_non_event = True

        # Include if learnable in target gen by non-event means
        if has_target_gen and has_non_event:
            result.add(move)

    return result


def get_full_prevo_chain(prevos: dict, pokemon_id: str) -> list:
    """Get all pre-evolutions in chain order (earliest first)."""
    chain = []
    current = pokemon_id
    while current in prevos:
        current = prevos[current]
        chain.append(current)
    chain.reverse()
    return chain


def build_learnsets():
    print("Downloading Showdown learnsets...", file=sys.stderr)
    learnset_ts = download(SHOWDOWN_LEARNSETS_URL)

    print("Downloading Showdown pokedex...", file=sys.stderr)
    pokedex_ts = download(SHOWDOWN_POKEDEX_URL)

    print("Parsing learnsets...", file=sys.stderr)
    raw_learnsets = parse_ts_object(learnset_ts)
    print(f"  Found {len(raw_learnsets)} Pokemon", file=sys.stderr)

    print("Parsing pokedex for evolution chains...", file=sys.stderr)
    prevos, evos = parse_pokedex(pokedex_ts)

    # Build regional form mapping
    regional_map = {}  # "dexNumber_region" -> showdownId
    # (This would need the pokedex data to map dex numbers to regional forms)

    print("Building filtered learnsets...", file=sys.stderr)
    result = {}
    skipped = 0

    for pokemon_id in sorted(raw_learnsets.keys()):
        # Skip Missingno and CAP pokemon
        if pokemon_id == "missingno":
            continue

        # Find target generation
        target_gen = get_pokemon_latest_gen(raw_learnsets, pokemon_id)
        if target_gen == 0:
            skipped += 1
            continue

        # Cap at MAX_GEN
        if target_gen > MAX_GEN:
            target_gen = MAX_GEN

        # Get moves for this Pokemon in its target gen
        own_moves = get_learnable_moves(raw_learnsets, pokemon_id, target_gen)

        # Inherit pre-evolution moves
        prevo_chain = get_full_prevo_chain(prevos, pokemon_id)
        for prevo_id in prevo_chain:
            prevo_gen = get_pokemon_latest_gen(raw_learnsets, prevo_id)
            if prevo_gen == 0:
                continue
            # Use the same target gen for prevo moves
            # (prevo might have egg moves not available to evo directly)
            prevo_moves = get_learnable_moves(raw_learnsets, prevo_id, min(prevo_gen, target_gen))
            own_moves |= prevo_moves

        if own_moves:
            result[pokemon_id] = sorted(own_moves)

    # Build regional form mapping from the data
    # Regional forms in Showdown: rattataalola, raticatealola, etc.
    regional_entries = {}
    for pokemon_id in result:
        for region in ['alola', 'galar', 'hisui', 'paldea']:
            if pokemon_id.endswith(region):
                # Try to find dex number from our Pokemon data
                base_name = pokemon_id[:-len(region)]
                # We'll add a simple mapping based on known regional forms
                regional_entries[pokemon_id] = region

    # Add _regional mapping
    # Load our Pokemon data to get dex numbers
    import os
    regional_map = {}
    data_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'assets', 'pokemon')
    for region_file in ['alola.json', 'galar.json', 'hisui.json', 'paldea.json']:
        filepath = os.path.join(data_dir, region_file)
        if not os.path.exists(filepath):
            continue
        with open(filepath) as f:
            pokemon_list = json.load(f)
        region = region_file.replace('.json', '')
        for p in pokemon_list:
            dex = p.get('dexNumber', 0)
            # Construct Showdown ID
            base_en = p.get('name', '').split()[-1].lower()  # "Alolan Raichu" -> "raichu"
            showdown_id = f"{base_en}{region}"
            if showdown_id in result:
                key = f"{dex}_{region}"
                regional_map[key] = showdown_id

    result['_regional'] = regional_map

    print(f"Built learnsets for {len(result) - 1} Pokemon ({skipped} skipped)", file=sys.stderr)

    # Verify Scizor doesn't have Roost (gen9 check)
    scizor_moves = result.get('scizor', [])
    assert 'roost' not in scizor_moves, f"Scizor should NOT have Roost in gen9! Found: roost in scizor"
    print("  ✓ Verification: Scizor does not have Roost", file=sys.stderr)

    return result


def main():
    result = build_learnsets()

    output_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        'assets', 'learnsets.json'
    )
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, separators=(',', ':'))

    print(f"Written to {output_path}", file=sys.stderr)


if __name__ == '__main__':
    import os
    main()
