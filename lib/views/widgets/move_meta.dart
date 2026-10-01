import 'package:flutter/material.dart';

import '../../i18n/localization.dart';
import '../../models/move.dart';
import 'type_chip.dart';

/// A move's type, category and power at the end of a picker row — the
/// same three facts, in the same order and form, wherever a move is
/// offered for picking (move slots, the dex filter, the move dex).
///
/// Fixed column widths, like the dex move table, so the chips line up
/// down the list whatever the names and powers are. [dimmed] is for a
/// move the Pokémon can't learn.
class MoveMeta extends StatelessWidget {
  final Move move;
  final bool dimmed;

  const MoveMeta(this.move, {super.key, this.dimmed = false});

  static const double _chipWidth = 50;
  static const double _textWidth = 58;

  @override
  Widget build(BuildContext context) {
    final power = move.power > 0 ? '${move.power}' : '—';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TypeChip.dense(move.type, width: _chipWidth, dimmed: dimmed),
        const SizedBox(width: 6),
        SizedBox(
          width: _textWidth,
          // Category names are longer in English; shrink rather than
          // push the chip column out of line.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '${KoStrings.getCategoryName(move.category)} $power',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 12,
                color: dimmed ? Colors.grey[400] : Colors.grey[600],
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
