import '../calc/hp.dart';

/// Parses what the user typed into an HP box.
///
/// With [percent] the plain number is a share of [maxHp] (`33` → the
/// nearest real HP, 58 of 175); otherwise it is the real value (`94`).
/// A trailing `%` always reads as a share. Results clamp to 0…150 % of
/// max. Empty means "back to full" — clearing the box and confirming
/// is how people reset it. Non-numeric input is null (leave the value
/// alone).
int? currentHpFromInput(String text, int maxHp, {bool percent = false}) {
  var t = text.trim();
  if (t.isEmpty) return maxHp;
  var asPercent = percent;
  if (t.endsWith('%')) {
    asPercent = true;
    t = t.substring(0, t.length - 1).trim();
  }
  final v = double.tryParse(t);
  if (v == null) return null;
  if (asPercent) return currentHpOf(maxHp, v);
  return v.round().clamp(0, maxCurrentHp(maxHp));
}

/// `94` for whole percents; otherwise up to two decimals with a
/// redundant trailing zero dropped (`6.25` stays, `6.50` → `6.5`).
String formatHpPercent(double pct) {
  if (pct == pct.roundToDouble()) return pct.toStringAsFixed(0);
  final s = pct.toStringAsFixed(2);
  return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
}
