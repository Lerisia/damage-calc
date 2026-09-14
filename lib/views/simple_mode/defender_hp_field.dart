part of '../simple_mode_screen.dart';

/// The defender's HP row in Simple Mode: colour-coded slider with the
/// 100 % anchor and the damage-range overlay, the fixed-width tappable
/// HP chip, and a trailing slot for the Stealth Rock button.
///
/// The slider reads as a percent (0…150 %, anchor at 100 %) but moves
/// in whole HP — one division per HP — so it can only land on values
/// a real HP produces. The chip shows the current HP as an integer;
/// tapping it edits that value (see the screen's `_editHp`).
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

  @override
  Widget build(BuildContext context) {
    final dmg = damageRange;
    final pct = hpPercentOf(maxHp, currentHp);
    // Green → orange → red as HP drops, like the in-game bar; cyan above
    // 100 % (Dynamax, heals, mid-turn estimates) so the overflow is obvious.
    final Color color = currentHp > maxHp
        ? Colors.cyan
        : pct >= 50
            ? Colors.green
            : pct >= 20
                ? Colors.orange
                : Colors.red;
    // Track spans 0…150 % of max HP in whole-HP steps; the 100 %
    // marker sits at max HP.
    final int sliderMax = maxCurrentHp(maxHp < 1 ? 1 : maxHp);
    // Thumb radius (8) is the horizontal padding the slider reserves
    // on each side; the 100 % marker sits at this fraction of the track.
    const thumbRadius = 8.0;
    final double hundredFraction = maxHp / sliderMax;
    // The damage overlay is painted as part of the track (see
    // [_DamageRangeTrackShape]) so the thumb sits on top of it and the
    // overlay moves in lockstep with the thumb during a drag.
    final double minDmgFrac =
        dmg == null ? 0 : (dmg.minPct / 100 * hundredFraction).clamp(0.0, 1.0);
    final double maxDmgFrac =
        dmg == null ? 0 : (dmg.maxPct / 100 * hundredFraction).clamp(0.0, 1.0);
    final bool hasDmgOverlay = dmg != null && currentHp > 0 && dmg.maxPct > 0;
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
                        value: currentHp.clamp(0, sliderMax).toDouble(),
                        min: 0,
                        max: sliderMax.toDouble(),
                        // One division per HP: every thumb position is
                        // a real HP value.
                        divisions: sliderMax,
                        onChanged: maxHp < 1 ? null : (v) => onChanged(v.round()),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        // Fixed-width tappable HP chip: the slider is Expanded, so a chip
        // that grew with its digits would change the track length on
        // every edit. Wide enough for three digits; longer scales down.
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
                      '$currentHp',
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
