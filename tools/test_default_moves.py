"""Hand-computed cases for compute_default_moves — run with
`python3 tools/test_default_moves.py`. Guards the 2026-04-30 rule
against a repeat of the 2026-07-30 regression."""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from fetch_pokechamdb import compute_default_moves, _move_role

M = lambda en, type, cat, pow=0, prio=0, tags=(), hits=1: {
    "en": en, "type": type, "cat": cat, "pow": pow, "prio": prio,
    "tags": list(tags), "max_hits": hits}
META = {m["en"]: m for m in [
    M("Sludge Bomb", "poison", "special", 90),
    M("Sludge Wave", "poison", "special", 95),
    M("Giga Drain", "grass", "special", 75),
    M("Earthquake", "ground", "physical", 100),
    M("Stealth Rock", "rock", "status"),
    M("Protect", "normal", "status"),
    M("Mud Shot", "ground", "special", 55),
    M("Bullet Seed", "grass", "physical", 25, hits=5),
    M("Sucker Punch", "dark", "physical", 70, prio=1),
    M("U-turn", "bug", "physical", 70, tags=["custom:switch_out"]),
]}
R = lambda *pairs: [{"name": n, "pct": p} for n, p in pairs]
names = lambda out: [m["name"] for m in out]

def test_roles():
    assert _move_role(META["Stealth Rock"]) == "status"
    assert _move_role(META["Sucker Punch"]) == "priority"
    assert _move_role(META["U-turn"]) == "switch"
    assert _move_role(META["Mud Shot"]) == "utility"      # pow<60, single hit
    assert _move_role(META["Bullet Seed"]) == "main"      # pow<60 but multi-hit
    assert _move_role(META["Sludge Bomb"]) == "main"

def test_group_sum_outranks_lone_move():
    # Sludge Bomb 54 + Sludge Wave 30 = 84 as one group > Giga Drain 64,
    # even though Giga Drain's own rate beats Sludge Bomb's.
    rows = R(("Giga Drain", 64), ("Sludge Bomb", 54), ("Sludge Wave", 30), ("Earthquake", 20))
    out = names(compute_default_moves(rows, ["poison", "grass"], META))
    assert out == ["Sludge Bomb", "Giga Drain", "Earthquake"], out  # Sludge Wave folded into its group

def test_utility_never_pads_top4():
    rows = R(("Earthquake", 90), ("Mud Shot", 80), ("Stealth Rock", 70), ("Protect", 60), ("Giga Drain", 10))
    out = names(compute_default_moves(rows, ["ground"], META))
    # Mud Shot (80) still competes as its own candidate — utility is a
    # role, not an exclusion; it just doesn't merge into Earthquake's group.
    assert out == ["Earthquake", "Mud Shot", "Stealth Rock", "Protect"], out

def test_order_stab_then_nonstab_then_status():
    rows = R(("Stealth Rock", 95), ("Giga Drain", 80), ("Earthquake", 70), ("Protect", 60), ("Sucker Punch", 5))
    out = names(compute_default_moves(rows, ["ground"], META))
    assert out == ["Earthquake", "Giga Drain", "Stealth Rock", "Protect"], out

def test_priority_and_switch_score_individually():
    rows = R(("Sucker Punch", 60), ("U-turn", 55), ("Earthquake", 50), ("Sludge Bomb", 10), ("Sludge Wave", 5))
    out = names(compute_default_moves(rows, ["dark"], META))
    assert out == ["Sucker Punch", "U-turn", "Earthquake", "Sludge Bomb"], out

def test_no_pct_falls_back_to_position():
    rows = [{"name": n} for n in ["Protect", "Earthquake", "Giga Drain", "Stealth Rock", "Sucker Punch"]]
    out = names(compute_default_moves(rows, ["ground"], META))
    assert out == ["Earthquake", "Giga Drain", "Protect", "Stealth Rock"], out

if __name__ == "__main__":
    for k, f in list(globals().items()):
        if k.startswith("test_"): f(); print(f"  ok  {k}")
    print("all passed")
