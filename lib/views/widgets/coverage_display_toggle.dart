import 'package:flutter/material.dart';

import '../../utils/app_strings.dart';
import '../../utils/coverage_display_controller.dart';

/// Compact two-button toggle that flips a matchup table between
/// numeric ("4×", "½", …) and symbolic (◎ / ○ / △ / ▲ / ✕) notation.
///
/// Tied to [CoverageDisplayController], which persists the choice to
/// SharedPreferences — so the party-coverage matrix and the built-in
/// type chart stay in the notation the user picked, wherever they set
/// it. Pair it with [MatchupBadge], which reads the same flag.
class CoverageDisplayToggle extends StatelessWidget {
  final CoverageDisplayMode mode;

  /// Right-aligned by default, matching the party matrix toolbar.
  /// Pass false when the caller does its own alignment.
  final bool alignRight;

  const CoverageDisplayToggle({
    super.key,
    required this.mode,
    this.alignRight = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final toggle = Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeBtn(
            context,
            label: AppStrings.t('team.matrix.display.numeric'),
            selected: mode == CoverageDisplayMode.numeric,
            target: CoverageDisplayMode.numeric,
          ),
          Container(width: 1, height: 20, color: scheme.outlineVariant),
          _modeBtn(
            context,
            label: AppStrings.t('team.matrix.display.symbolic'),
            selected: mode == CoverageDisplayMode.symbolic,
            target: CoverageDisplayMode.symbolic,
          ),
        ],
      ),
    );
    if (!alignRight) return toggle;
    return Align(alignment: Alignment.centerRight, child: toggle);
  }

  Widget _modeBtn(
    BuildContext context, {
    required String label,
    required bool selected,
    required CoverageDisplayMode target,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => CoverageDisplayController.instance.set(target),
      child: Container(
        color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? scheme.onSurface
                : scheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
