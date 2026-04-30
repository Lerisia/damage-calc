import 'package:flutter/material.dart';
import '../../utils/app_strings.dart';
import '../../utils/move_options_controller.dart';

/// Compact "변화기 보기" toggle. Listens to the global
/// [MoveOptionsController] so flipping it in one place (calculator
/// move section, party-coverage offensive grid) updates everywhere
/// the user has a move picker open. Used as a trailing affordance on
/// section headers — designed to be small enough to sit inline with
/// the section title.
class StatusMovesToggle extends StatelessWidget {
  const StatusMovesToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MoveOptionsController.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: controller.showStatusMoves,
      builder: (context, on, _) {
        final color = on
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant;
        return InkWell(
          onTap: () => controller.setShowStatusMoves(!on),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  on ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 3),
                Text(
                  AppStrings.t('move.showStatus'),
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: on ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
