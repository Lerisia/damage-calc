import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'stat_input.dart';

/// Compact stat-point / EV input cell — small number field with a
/// tiny stat label above. Used in the team builder slot popup; can
/// be reused anywhere a single 0..max number cell is needed.
///
/// **Why this widget is its own file**: the `_EvCell` ancestor of
/// this widget shipped a focus-loss regression three times — keying
/// the inner `SelectAllField` on `(label, value)` so every keystroke
/// remounted the field, dropping focus and dismissing the keyboard.
/// See `feedback_ev_input_focus_regression.md`. Extracting it makes
/// it directly addressable by widget tests
/// (`test/widgets/ev_sp_cell_focus_test.dart`) so future value-in-key
/// regressions fail CI instead of shipping to users.
///
/// **Contract — do not break:**
/// - The inner `SelectAllField`'s `key` MUST be stable across value
///   changes (label-only is fine; do NOT interpolate the current
///   value). A changing key remounts the widget and kills focus.
/// - Storage stays in the cell's chosen unit (the parent decides
///   whether it's SP, EV, or anything else). This widget just
///   echoes a clamped 0..[max] integer back via [onChanged].
class EvSpCell extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const EvSpCell({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
        const SizedBox(height: 2),
        SizedBox(
          // Match the calculator's EV field height so the two screens
          // feel like the same input control.
          height: 36,
          // SelectAllField + ClampingFormatter are the same primitives
          // the main calc uses for stat editing — keeps select-on-
          // focus and clamp behavior consistent across screens.
          //
          // CRITICAL: the key is keyed on [label] only, NOT on
          // [value]. A value-keyed wrapper unmounts and remounts on
          // every keystroke, killing focus and dismissing the
          // keyboard. SelectAllField's didUpdateWidget syncs the
          // controller text from [value] when the field isn't
          // focused, so external mutations (sample load, species
          // pick) still propagate. Covered by ev_sp_cell_focus_test.
          child: SelectAllField(
            key: ValueKey('evspcell_$label'),
            initialText: '$value',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              ClampingFormatter(min: 0, max: max),
            ],
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            ),
            onChanged: (v) {
              final n = int.tryParse(v) ?? 0;
              onChanged(n);
            },
          ),
        ),
      ],
    );
  }
}
