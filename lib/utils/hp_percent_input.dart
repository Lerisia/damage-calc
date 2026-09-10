/// Parses what the user typed into an HP % box.
///
/// Empty means "back to full" — clearing the box and confirming is how
/// people reset it, and treating it as a cancel left the old value in
/// place. Non-numeric input is null (leave the value alone); numbers
/// clamp to the 0–999 % range the slider and chip damage math accept.
double? hpPercentFromInput(String text) {
  final t = text.trim();
  if (t.isEmpty) return 100.0;
  final v = double.tryParse(t);
  return v?.clamp(0.0, 999.0);
}
