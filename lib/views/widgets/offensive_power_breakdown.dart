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
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogCtx) {
      final lines = notes
          .map((n) => formatModifierNote(n,
              abilityNameMap: abilityNameMap, itemNameMap: itemNameMap))
          .toList();
      return Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.sizeOf(dialogCtx).height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row: move name + power + close.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            moveDisplayName,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500),
                          ),
                          Text(
                            AppStrings.t('breakdown.title'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$power',
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogCtx).maybePop(),
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: AppStrings.t('action.close'),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const Divider(height: 16),

                if (lines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      AppStrings.t('breakdown.empty'),
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: lines.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 4),
                        child: Text(
                          lines[i],
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
                Text(
                  AppStrings.t('breakdown.note'),
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[600], height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
