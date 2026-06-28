import 'package:flutter/material.dart';

import '../../utils/app_strings.dart';

/// Single-cell rendering of a defensive type multiplier — the visual
/// language shared between the team-coverage matrix and the dex
/// per-Pokemon matchup chart. Centralising it here means the two
/// surfaces always look identical: same fractions, same symbols,
/// same colour palette, same pill backgrounds for the decisive tiers.
///
/// ```
///   numeric:        symbolic:
///   - 4×  "4×"      ◎     — light red pill, dark red text
///   - 2×  "2×"      ○     — red text only
///   - 1×  (blank)   (blank)
///   - ½   "½"       △     — blue text only
///   - ¼   "¼"       ▲     — light blue pill, dark blue text
///   - 무  "무"      ✕     — light gray pill, gray text
/// ```
class MatchupBadge extends StatelessWidget {
  /// Defensive multiplier (matches the values returned by the
  /// type-effectiveness helpers). Anything outside the canonical
  /// {0, 0.25, 0.5, 1, 2, 4} set renders as a fallback `×$value`.
  final double multiplier;

  /// Symbol mode (◎ / ○ / △ / ▲ / ✕) vs numeric mode (4× / 2× / ½ / ¼ / 무).
  /// Defaults to numeric to match the matrix's first-launch default.
  final bool symbolic;

  /// Font size for the label. The team-coverage matrix renders these
  /// at the same size as its cells (~15-17pt); the dex chart wants
  /// them slightly larger so they read as headers. Pass per call.
  final double fontSize;

  /// Whether to draw the pill background for the decisive tiers
  /// (4×, ¼, 무). Pass `false` to get the bare label without any
  /// backdrop — useful when the badge is embedded inside another
  /// surface that already has a background.
  final bool withPill;

  const MatchupBadge({
    super.key,
    required this.multiplier,
    this.symbolic = false,
    this.fontSize = 15,
    this.withPill = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spec = _specFor(multiplier, symbolic: symbolic, scheme: scheme);
    if (spec.label.isEmpty) return const SizedBox.shrink();
    final text = Text(
      spec.label,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: spec.weight,
        color: spec.fg,
        height: 1.0,
      ),
    );
    if (!withPill || spec.pillBg == null) return text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: spec.pillBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: text,
    );
  }

  /// Public so callers that need the colour for a non-badge context
  /// (e.g. tinting an adjacent label) can read it without rebuilding
  /// the switch. Returns null for the trivial 1× case.
  static Color? foregroundFor(double multiplier,
      {required ColorScheme scheme}) {
    return _specFor(multiplier, symbolic: false, scheme: scheme).fg;
  }
}

class _MatchupSpec {
  final String label;
  final Color fg;
  final Color? pillBg;
  final FontWeight weight;
  const _MatchupSpec({
    required this.label,
    required this.fg,
    this.pillBg,
    this.weight = FontWeight.w800,
  });
}

_MatchupSpec _specFor(double m,
    {required bool symbolic, required ColorScheme scheme}) {
  if (m == 0) {
    return _MatchupSpec(
      label: symbolic ? '✕' : AppStrings.t('team.matrix.immune'),
      fg: scheme.onSurface.withValues(alpha: 0.55),
      pillBg: scheme.onSurface.withValues(alpha: 0.10),
      weight: FontWeight.w700,
    );
  }
  if (m == 4) {
    return _MatchupSpec(
      label: symbolic ? '◎' : '4×',
      fg: Colors.red.shade900,
      pillBg: Colors.red.shade100,
      weight: FontWeight.w900,
    );
  }
  if (m == 2) {
    return _MatchupSpec(
      label: symbolic ? '○' : '2×',
      fg: Colors.red.shade600,
    );
  }
  if (m == 0.5) {
    return _MatchupSpec(
      label: symbolic ? '△' : '½',
      fg: Colors.blue.shade600,
    );
  }
  if (m == 0.25) {
    return _MatchupSpec(
      label: symbolic ? '▲' : '¼',
      fg: Colors.blue.shade900,
      pillBg: Colors.blue.shade100,
      weight: FontWeight.w900,
    );
  }
  if (m == 1) {
    return _MatchupSpec(label: '', fg: scheme.onSurface);
  }
  // Fallback — should not occur with canonical type-chart math.
  return _MatchupSpec(label: '×$m', fg: scheme.onSurface);
}
