import 'package:flutter/material.dart';

import '../../models/move.dart';
import '../../models/type.dart';
import '../../utils/app_strings.dart';
import '../../utils/localization.dart';
import 'type_filter_dialog.dart';

/// The controls both move tables share — the Pokédex detail's learnset
/// list and the Move Dex list: the sortable column header, the type and
/// category filter chips, and the comparator behind the header. Each
/// screen keeps its own sort state and toggle rule (the Move Dex cycles
/// back to registration order, the dex detail just flips) and hands the
/// state in.

enum MoveSortKey { name, type, category, power, accuracy }

/// Column default direction: text ascends, numbers descend (ranking
/// moves by power / accuracy almost always means big → small).
bool moveSortDefaultAsc(MoveSortKey key) =>
    !(key == MoveSortKey.power || key == MoveSortKey.accuracy);

/// Orders [a] against [b] by [key]; ties fall back to the localized
/// name so the order is stable.
int compareMoves(Move a, Move b, MoveSortKey key, {required bool asc}) {
  int cmp = switch (key) {
    MoveSortKey.name => a.localizedName.compareTo(b.localizedName),
    MoveSortKey.type =>
      KoStrings.getTypeName(a.type).compareTo(KoStrings.getTypeName(b.type)),
    MoveSortKey.category => a.category.index.compareTo(b.category.index),
    MoveSortKey.power => a.power.compareTo(b.power),
    // 0 (—) sorts as the lowest accuracy; simplest and what users expect.
    MoveSortKey.accuracy => a.accuracy.compareTo(b.accuracy),
  };
  if (cmp == 0 && key != MoveSortKey.name) {
    cmp = a.localizedName.compareTo(b.localizedName);
  }
  return asc ? cmp : -cmp;
}

/// Column header row: name (flex) · type · category · power · accuracy,
/// the active column tinted with an arrow. [showArrow] lets the Move
/// Dex hide the arrow while a search query overrides column sort.
class MoveSortHeader extends StatelessWidget {
  final MoveSortKey? sortKey;
  final bool asc;
  final bool showArrow;
  final ValueChanged<MoveSortKey> onTap;

  const MoveSortHeader({
    super.key,
    required this.sortKey,
    required this.asc,
    required this.onTap,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget cell({
      required MoveSortKey key,
      required String label,
      required Widget Function(Widget child) wrap,
    }) {
      final active = sortKey == key && showArrow;
      final arrow = active ? (asc ? ' ↑' : ' ↓') : '';
      return InkWell(
        onTap: () => onTap(key),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: wrap(
            Text(
              '$label$arrow',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: cell(
              key: MoveSortKey.name,
              label: AppStrings.t('move.name'),
              wrap: (c) => Align(alignment: Alignment.centerLeft, child: c),
            ),
          ),
          SizedBox(
            width: 50,
            child: cell(
              key: MoveSortKey.type,
              label: AppStrings.t('move.type'),
              wrap: (c) => Center(child: c),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 36,
            child: cell(
              key: MoveSortKey.category,
              label: AppStrings.t('move.category'),
              wrap: (c) => Center(child: c),
            ),
          ),
          SizedBox(
            width: 36,
            child: cell(
              key: MoveSortKey.power,
              label: AppStrings.t('move.power'),
              wrap: (c) => Center(child: c),
            ),
          ),
          SizedBox(
            width: 36,
            child: cell(
              key: MoveSortKey.accuracy,
              label: AppStrings.t('move.accuracy'),
              wrap: (c) => Center(child: c),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bordered chip whose width never changes with the selection (an
/// invisible "all" label sets it), used by both filter chips.
class _FilterChipFrame extends StatelessWidget {
  final String placeholder;
  final Widget label;
  const _FilterChipFrame({required this.placeholder, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(placeholder,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.transparent)),
          label,
        ],
      ),
    );
  }
}

/// Type filter chip → the type filter dialog. [available] restricts the
/// dialog to types the list actually contains (the dex detail passes
/// the learnset's types; the Move Dex offers all).
class TypeFilterChip extends StatelessWidget {
  final PokemonType? value;
  final Set<PokemonType>? available;
  final ValueChanged<PokemonType?> onChanged;

  const TypeFilterChip({
    super.key,
    required this.value,
    required this.onChanged,
    this.available,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final picked = await showTypeFilterDialog(
          context: context,
          current: value,
          available: available,
        );
        if (!context.mounted || identical(picked, kTypeFilterDismissed)) return;
        onChanged(picked as PokemonType?);
      },
      child: _FilterChipFrame(
        placeholder: AppStrings.t('dex.allTypes'),
        label: Text(
          value == null
              ? AppStrings.t('dex.allTypes')
              : KoStrings.getTypeName(value!),
          style: TextStyle(
              fontSize: 12,
              color: value != null ? KoStrings.getTypeColor(value!) : null,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Category filter chip (physical / special / status / all). [available]
/// hides categories the list doesn't contain.
class CategoryFilterChip extends StatelessWidget {
  final MoveCategory? value;
  final Set<MoveCategory>? available;
  final ValueChanged<MoveCategory?> onChanged;

  const CategoryFilterChip({
    super.key,
    required this.value,
    required this.onChanged,
    this.available,
  });

  static String label(MoveCategory? c) => switch (c) {
        null => AppStrings.t('dex.allCategories'),
        MoveCategory.physical => AppStrings.t('damage.physical'),
        MoveCategory.special => AppStrings.t('damage.special'),
        MoveCategory.status => AppStrings.t('damage.status'),
      };

  @override
  Widget build(BuildContext context) {
    // PopupMenuButton swallows null selections, so "all" is -1.
    const allSentinel = -1;
    return PopupMenuButton<int>(
      tooltip: AppStrings.t('dex.allCategories'),
      popUpAnimationStyle:
          AnimationStyle(duration: const Duration(milliseconds: 100)),
      child: _FilterChipFrame(
        placeholder: label(null),
        label: Text(label(value),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: allSentinel,
          child: Text(label(null), style: const TextStyle(fontSize: 13)),
        ),
        for (final c in MoveCategory.values)
          if (available == null || available!.contains(c))
            PopupMenuItem(
              value: c.index,
              child: Text(label(c), style: const TextStyle(fontSize: 13)),
            ),
      ],
      onSelected: (v) =>
          onChanged(v == allSentinel ? null : MoveCategory.values[v]),
    );
  }
}
