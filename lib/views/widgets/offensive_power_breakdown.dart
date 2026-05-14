import 'package:flutter/material.dart';

import '../../utils/app_strings.dart';
import 'modifier_note.dart';

/// Bottom-sheet popup that shows the modifiers feeding a 결정력
/// number. Caller passes the `MoveSlotInfo.offensivePowerNotes` list
/// (and the ability/item name maps for note rendering) plus the
/// final power value.
///
/// Used by both Simple Mode (tap result block) and Extended Mode
/// (tap a per-slot 결정력 number). Same renderer as the Damage tab
/// modifier list — adding a new note key is a single edit in
/// `modifier_note.dart`.
void showOffensivePowerBreakdown(
  BuildContext context, {
  required int power,
  required String moveDisplayName,
  required List<String> notes,
  required Map<String, String> abilityNameMap,
  required Map<String, String> itemNameMap,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) {
      final lines = notes
          .map((n) => formatModifierNote(n,
              abilityNameMap: abilityNameMap, itemNameMap: itemNameMap))
          .toList();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: move name + final power figure.
              Text(
                moveDisplayName,
                style: const TextStyle(
                    fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    AppStrings.t('breakdown.title'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    '$power',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Modifier list (or empty-state message).
              if (lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    AppStrings.t('breakdown.empty'),
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: lines.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        lines[i],
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),

              // Footer disclaimer — matchup-conditional things aren't in
              // 결정력, so the popup explains the gap.
              const SizedBox(height: 12),
              Text(
                AppStrings.t('breakdown.note'),
                style: TextStyle(
                    fontSize: 11, color: Colors.grey[600], height: 1.4),
              ),
            ],
          ),
        ),
      );
    },
  );
}
