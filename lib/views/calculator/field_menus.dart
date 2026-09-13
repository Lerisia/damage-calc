part of '../damage_calculator_screen.dart';

/// One entry of a [_StickyCheckMenu]. [getValue] is read live so the
/// checkbox reflects state changes while the popup stays open.
class _StickyCheckItem {
  final String label;
  final bool Function() getValue;
  final VoidCallback onToggle;
  final bool enabled;
  const _StickyCheckItem({
    required this.label,
    required this.getValue,
    required this.onToggle,
    this.enabled = true,
  });
}

/// Wide-toolbar dropdown of checkboxes that DOESN'T close on tap —
/// each row is a non-interactive PopupMenuItem (so Flutter's built-in
/// close-on-select never fires) with a StatefulBuilder so the box
/// updates inside the still-open popup. Used for rooms, auras and
/// ruins; the label tints when anything in the menu is active.
class _StickyCheckMenu extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool active;
  final double fontSize;
  final List<_StickyCheckItem> items;

  const _StickyCheckMenu({
    required this.label,
    required this.tooltip,
    required this.active,
    required this.fontSize,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: tooltip,
      popUpAnimationStyle: AnimationStyle(duration: const Duration(milliseconds: 100)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(
              fontSize: fontSize,
              color: active ? scheme.primary : Colors.grey.shade500,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            )),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (_) => [
        for (final item in items)
          PopupMenuItem<String>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: StatefulBuilder(
              builder: (ctx, setLocal) {
                final value = item.getValue();
                void toggle() { item.onToggle(); setLocal(() {}); }
                return InkWell(
                  onTap: item.enabled ? toggle : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24, height: 24,
                          child: Checkbox(
                            value: value,
                            onChanged: item.enabled ? (_) => toggle() : null,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Force normal onSurface — a disabled PopupMenuItem
                        // would otherwise dim every child.
                        Text(
                          item.label,
                          style: TextStyle(
                            color: item.enabled
                                ? scheme.onSurface
                                : scheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
