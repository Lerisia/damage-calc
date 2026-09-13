part of '../damage_calculator_screen.dart';

/// The damage-sum footer's rendering: chips for the selected shots, the
/// combined range and the N-set KO line. The arithmetic (joint
/// distribution, KO odds) stays in the screen; this only lays it out.
class _SumFooter extends StatelessWidget {
  final int total;
  final int max;
  final List<({int slot, String label})> chips;
  final double minPct;
  final double maxPct;
  final int minDmg;
  final int maxDmg;
  final String koText;
  final Color koColor;
  final VoidCallback onReset;
  final ValueChanged<int> onRemove;

  const _SumFooter({
    required this.total,
    required this.max,
    required this.chips,
    required this.minPct,
    required this.maxPct,
    required this.minDmg,
    required this.maxDmg,
    required this.koText,
    required this.koColor,
    required this.onReset,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (total == 0) {
      // Compact empty state. SafeArea keeps the hint above the iOS
      // home-indicator bar.
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
          child: Text(
            AppStrings.t('damage.sum.emptyHint'),
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${AppStrings.t('damage.sum.title')} ($total/$max)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: AppStrings.t('damage.sum.reset'),
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh, size: 18),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in chips)
                  InputChip(
                    label: Text(c.label, style: const TextStyle(fontSize: 12)),
                    onDeleted: () => onRemove(c.slot),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Text(
                    '${minPct.toStringAsFixed(1)}~${maxPct.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text('($minDmg~$maxDmg)',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  if (koText.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Text(koText,
                        style: TextStyle(
                            fontSize: 16, color: koColor, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.t('damage.sum.disclaimer'),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
