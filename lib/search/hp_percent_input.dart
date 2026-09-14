import '../calc/hp.dart';

/// Parses what the user typed into a current-HP box.
///
/// Real value by default (`94` → 94 HP, clamped to 0…[maxHp]); a
/// trailing `%` reads as a share and lands on the nearest achievable
/// HP (`40%` of 187 → 75). Empty means "back to full" — clearing the
/// box and confirming is how people reset it. Non-numeric input is
/// null (leave the value alone).
int? currentHpFromInput(String text, int maxHp) {
  final t = text.trim();
  if (t.isEmpty) return maxHp;
  if (t.endsWith('%')) {
    final pct = double.tryParse(t.substring(0, t.length - 1).trim());
    if (pct == null) return null;
    return currentHpOf(maxHp, pct.clamp(0.0, 100.0));
  }
  final v = int.tryParse(t) ?? double.tryParse(t)?.round();
  return v?.clamp(0, maxHp);
}
