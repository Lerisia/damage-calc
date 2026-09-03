import 'package:flutter/material.dart';

/// Compact bordered segmented control — the app's standard way to
/// flip a table between two presentations (numeric vs symbolic
/// matchups, base vs realized speeds).
///
/// Kept generic so every such toggle reads the same; callers own the
/// state and just hand over labels plus the selected index.
class SegmentedToggle extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Right-aligned by default, matching the party matrix toolbar.
  final bool alignRight;

  const SegmentedToggle({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
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
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 20, color: scheme.outlineVariant),
            _segment(context, labels[i], i == selectedIndex, i),
          ],
        ],
      ),
    );
    if (!alignRight) return toggle;
    return Align(alignment: Alignment.centerRight, child: toggle);
  }

  Widget _segment(
      BuildContext context, String label, bool selected, int index) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onSelect(index),
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
