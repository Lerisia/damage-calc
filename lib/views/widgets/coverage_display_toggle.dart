import 'package:flutter/material.dart';

import '../../utils/app_strings.dart';
import '../../utils/coverage_display_controller.dart';
import 'segmented_toggle.dart';

/// Flips a matchup table between numeric ("4×", "½", …) and symbolic
/// (◎ / ○ / △ / ▲ / ✕) notation.
///
/// Tied to [CoverageDisplayController], which persists the choice — so
/// the party-coverage matrix and the built-in type chart stay in the
/// notation the user picked, wherever they set it. Pair it with
/// [MatchupBadge], which reads the same flag.
class CoverageDisplayToggle extends StatelessWidget {
  final CoverageDisplayMode mode;
  final bool alignRight;

  const CoverageDisplayToggle({
    super.key,
    required this.mode,
    this.alignRight = true,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedToggle(
      alignRight: alignRight,
      labels: [
        AppStrings.t('team.matrix.display.numeric'),
        AppStrings.t('team.matrix.display.symbolic'),
      ],
      selectedIndex: mode == CoverageDisplayMode.symbolic ? 1 : 0,
      onSelect: (i) => CoverageDisplayController.instance.set(
        i == 1 ? CoverageDisplayMode.symbolic : CoverageDisplayMode.numeric,
      ),
    );
  }
}
