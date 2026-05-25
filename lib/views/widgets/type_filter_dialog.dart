import 'package:flutter/material.dart';
import '../../models/type.dart';
import '../../utils/app_strings.dart';
import '../../utils/localization.dart';

/// Single-select type picker used by the Pokémon / Move dex filters.
///
/// Returns the chosen type, or `null` for the "전체 / All types" option.
/// Dismissing the dialog without picking returns the special
/// [kTypeFilterDismissed] sentinel — callers can distinguish that from
/// an explicit "all types" pick (both bind to `null` filter state, but
/// dismissal should leave the previous filter untouched).
///
/// Picking a chip applies and closes immediately — no confirm button —
/// because each slot is a single-value filter.
///
/// `available`, if non-null, restricts which type chips appear (and
/// dims the ones not in the set). The Pokémon-dex moves tab uses this
/// to hide types the current Pokémon can't learn moves of.
const Object kTypeFilterDismissed = Object();

Future<Object?> showTypeFilterDialog({
  required BuildContext context,
  required PokemonType? current,
  Set<PokemonType>? available,
}) {
  return showDialog<Object?>(
    context: context,
    builder: (ctx) => _TypeFilterDialog(
      current: current,
      available: available,
    ),
  );
}

class _TypeFilterDialog extends StatelessWidget {
  final PokemonType? current;
  final Set<PokemonType>? available;

  const _TypeFilterDialog({required this.current, this.available});

  /// 18 main types in dex order — typeless is excluded since no real
  /// Pokémon / move filters on it.
  static const _options = <PokemonType>[
    PokemonType.normal,
    PokemonType.fire,
    PokemonType.water,
    PokemonType.electric,
    PokemonType.grass,
    PokemonType.ice,
    PokemonType.fighting,
    PokemonType.poison,
    PokemonType.ground,
    PokemonType.flying,
    PokemonType.psychic,
    PokemonType.bug,
    PokemonType.rock,
    PokemonType.ghost,
    PokemonType.dragon,
    PokemonType.dark,
    PokemonType.steel,
    PokemonType.fairy,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      title: Row(
        children: [
          Expanded(
            child: Text(
              AppStrings.t('dex.filterByType'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: AppStrings.t('action.close'),
            onPressed: () => Navigator.pop(context, kTypeFilterDismissed),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // "전체" lives in its own row so users always have a
              // one-tap path back to no-filter, regardless of how many
              // type chips fill the grid below.
              _AllTypesChip(
                selected: current == null,
                onTap: () => Navigator.pop(context, null),
                surfaceColor: scheme.onSurface,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in _options)
                    _TypeFilterChip(
                      type: t,
                      selected: current == t,
                      // Dimmed but still tappable — the grid layout
                      // stays stable across Pokémon (vs hiding chips
                      // entirely, which would reflow the rows), and
                      // picking a missing type just shows zero rows.
                      dimmed: available != null && !available!.contains(t),
                      onTap: () => Navigator.pop(context, t),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllTypesChip extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Color surfaceColor;
  const _AllTypesChip({
    required this.selected,
    required this.onTap,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? surfaceColor : surfaceColor.withValues(alpha: 0.08),
          border: Border.all(
            color: selected ? surfaceColor : surfaceColor.withValues(alpha: 0.45),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          AppStrings.t('dex.allTypes'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected
                ? Theme.of(context).colorScheme.surface
                : surfaceColor,
          ),
        ),
      ),
    );
  }
}

class _TypeFilterChip extends StatelessWidget {
  final PokemonType type;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  const _TypeFilterChip({
    required this.type,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = KoStrings.getTypeColor(type);
    // Dimmed chips fade fill and label opacity together so the chip
    // still reads as the right type but visibly secondary.
    final fillAlpha = selected ? 1.0 : (dimmed ? 0.04 : 0.08);
    final borderAlpha = selected ? 1.0 : (dimmed ? 0.25 : 0.55);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: fillAlpha),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: borderAlpha),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          KoStrings.getTypeName(type),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : color.withValues(alpha: dimmed ? 0.55 : 1.0),
          ),
        ),
      ),
    );
  }
}
