part of '../simple_mode_screen.dart';

/// The defender's HP row in Simple Mode: colour-coded slider with the
/// damage-range overlay, the fixed-width tappable % chip, and a
/// trailing slot for the Stealth Rock button.
///
/// The slider reads as a percent but moves in whole HP: its range is
/// 0…[maxHp] with one division per HP, so it can only land on shares
/// a real HP produces. The chip shows the share of the current
/// integer; tapping it edits the real value (see the screen's
/// `_editHp`).
class _DefenderHpField extends StatelessWidget {
  final int currentHp;
  final int maxHp;
  final ({double minPct, double maxPct})? damageRange;
  final ValueChanged<int> onChanged;
  final VoidCallback onEdit;
  final Widget trailing;

  const _DefenderHpField({
    required this.currentHp,
    required this.maxHp,
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
    final pct = hpPercentOf(maxHp, currentHp);
    // Green → orange → red as HP drops, like the in-game bar.
    final Color color = pct >= 50
        ? Colors.green
        : pct >= 20
            ? Colors.orange
            : Colors.red;
    // The damage overlay is painted as part of the track (see
    // [_DamageRangeTrackShape]) so the thumb sits on top of it and the
    // overlay moves in lockstep with the thumb during a drag. The
    // track spans 0…100 % of max HP, so the overlay's percents map
    // straight onto track fractions.
    final double minDmgFrac =
        dmg == null ? 0 : (dmg.minPct / 100).clamp(0.0, 1.0);
    final double maxDmgFrac =
        dmg == null ? 0 : (dmg.maxPct / 100).clamp(0.0, 1.0);
    final bool hasDmgOverlay = dmg != null && currentHp > 0 && dmg.maxPct > 0;
    final int sliderMax = maxHp < 1 ? 1 : maxHp;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 28,
            child: SliderTheme(
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
                value: currentHp.clamp(0, sliderMax).toDouble(),
                min: 0,
                max: sliderMax.toDouble(),
                // One division per HP: every thumb position is a real
                // HP value, so no unreachable share can be dialled in.
                divisions: sliderMax,
                onChanged: maxHp < 1 ? null : (v) => onChanged(v.round()),
              ),
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
