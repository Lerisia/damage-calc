part of '../simple_mode_screen.dart';

/// The defender's HP row in Simple Mode: colour-coded slider with the
/// 100 % anchor and the damage-range overlay, the fixed-width tappable
/// % chip, and a trailing slot for the Stealth Rock button.
class _DefenderHpField extends StatelessWidget {
  final double pct;
  final ({double minPct, double maxPct})? damageRange;
  final ValueChanged<double> onChanged;
  final VoidCallback onEdit;
  final Widget trailing;

  const _DefenderHpField({
    required this.pct,
    required this.damageRange,
    required this.onChanged,
    required this.onEdit,
    required this.trailing,
  });

  /// `94%` for whole percents; decimals (6.25 % chip damage) keep up to
  /// two digits with a redundant trailing zero dropped (`6.5` not `6.50`).
  static String formatPct(double pct) {
    if (pct == pct.roundToDouble()) return pct.toStringAsFixed(0);
    final s = pct.toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }

  @override
  Widget build(BuildContext context) {
    final dmg = damageRange;
    // Green → orange → red as HP drops, like the in-game bar; cyan above
    // 100 % (Dynamax, heals, mid-turn estimates) so the overflow is obvious.
    final Color color = pct > 100
        ? Colors.cyan
        : pct >= 50
            ? Colors.green
            : pct >= 20
                ? Colors.orange
                : Colors.red;
    const sliderMax = 150;
    // Thumb radius (8) is the horizontal padding the slider reserves
    // on each side; the 100 % marker sits at this fraction of the track.
    const thumbRadius = 8.0;
    const hundredFraction = 100 / sliderMax;
    // The damage overlay is painted as part of the track (see
    // [_DamageRangeTrackShape]) so the thumb sits on top of it and the
    // overlay moves in lockstep with the thumb during a drag.
    final double minDmgFrac =
        dmg == null ? 0 : (dmg.minPct / sliderMax).clamp(0.0, 1.0);
    final double maxDmgFrac =
        dmg == null ? 0 : (dmg.maxPct / sliderMax).clamp(0.0, 1.0);
    final bool hasDmgOverlay = dmg != null && pct > 0 && dmg.maxPct > 0;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 28,
            child: LayoutBuilder(
              builder: (ctx, c) {
                final trackWidth = c.maxWidth - thumbRadius * 2;
                final markerLeft = thumbRadius + hundredFraction * trackWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: markerLeft - 1,
                      top: (c.maxHeight - 12) / 2,
                      child: IgnorePointer(
                        child: Container(
                          width: 2,
                          height: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        overlayShape: SliderComponentShape.noOverlay,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        activeTrackColor: color,
                        inactiveTrackColor: color.withValues(alpha: 0.25),
                        thumbColor: color,
                        trackShape: hasDmgOverlay
                            ? _DamageRangeTrackShape(
                                minDmgFraction: minDmgFrac,
                                maxDmgFraction: maxDmgFrac,
                              )
                            : null,
                      ),
                      child: Slider(
                        value: pct.clamp(0, sliderMax).toDouble(),
                        min: 0,
                        max: sliderMax.toDouble(),
                        // 1 % steps; sub-percent values go through the
                        // % chip's editor. Snap to 100 within ±2.
                        divisions: sliderMax,
                        onChanged: (v) {
                          var rounded = v.round();
                          if ((rounded - 100).abs() <= 2) rounded = 100;
                          onChanged(rounded.toDouble());
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        // Fixed-width tappable % chip: the slider is Expanded, so a chip
        // that grew with its digits would change the track length on
        // every edit. Wide enough for "100.00%"; longer scales down.
        InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 74,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${formatPct(pct)}%',
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit, size: 12, color: Theme.of(context).colorScheme.outline),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        trailing,
      ],
    );
  }
}
