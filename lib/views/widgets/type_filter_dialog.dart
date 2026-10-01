import 'package:flutter/material.dart';
import '../../models/type.dart';
import '../../i18n/app_strings.dart';
import 'type_chip.dart';

/// Returned when a type dialog is closed without a pick.
const Object kTypeFilterDismissed = Object();

/// The 18 regular types in dex order — no Stellar, no typeless.
const List<PokemonType> kMainTypes = <PokemonType>[
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

/// The one single-choice type dialog: a grid of [TypeChip] options,
/// with an optional "none" row above it. Every place that asks for one
/// type opens this — the dex / move filters, the Terastal pickers of
/// both calculator modes, a move's type override, the dex filter's
/// attack type — so a type is picked from the same chips everywhere.
/// (Until 2026-10-02 three of those were plain text lists.)
///
/// Returns the chosen type, `null` for the "none" row, or
/// [kTypeFilterDismissed] when closed without a pick — callers leave
/// their value untouched on that one.
///
/// A tap applies and closes immediately; there is no confirm button.
///
///  * [title] defaults to the filter's "타입으로 검색".
///  * [noneLabel] defaults to "모든 타입"; [offerNone] false drops the
///    row.
///  * [options] defaults to [kMainTypes].
///  * [available], if non-null, dims the options outside the set (they
///    stay tappable — the grid doesn't reflow, and picking one just
///    matches nothing).
Future<Object?> showTypeFilterDialog({
  required BuildContext context,
  required PokemonType? current,
  Set<PokemonType>? available,
  String? title,
  String? noneLabel,
  bool offerNone = true,
  List<PokemonType> options = kMainTypes,
}) {
  return showDialog<Object?>(
    context: context,
    builder: (ctx) => _TypeChoiceDialog(
      current: current,
      available: available,
      title: title ?? AppStrings.t('dex.filterByType'),
      noneLabel: offerNone ? (noneLabel ?? AppStrings.t('dex.allTypes')) : null,
      options: options,
    ),
  );
}

/// Pick one of [options] — no "none" row. Null when dismissed.
Future<PokemonType?> showTypeChoiceDialog({
  required BuildContext context,
  required String title,
  PokemonType? current,
  List<PokemonType> options = kMainTypes,
}) async {
  final picked = await showTypeFilterDialog(
    context: context,
    current: current,
    title: title,
    offerNone: false,
    options: options,
  );
  return picked is PokemonType ? picked : null;
}

class _TypeChoiceDialog extends StatelessWidget {
  final PokemonType? current;
  final Set<PokemonType>? available;
  final String title;

  /// Null hides the "none" row.
  final String? noneLabel;
  final List<PokemonType> options;

  const _TypeChoiceDialog({
    required this.current,
    required this.title,
    required this.noneLabel,
    required this.options,
    this.available,
  });

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
              title,
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
              // The "none" entry lives in its own row so there is
              // always a one-tap path back to no type, however many
              // chips fill the grid below.
              if (noneLabel != null) ...[
                _NoneChip(
                  label: noneLabel!,
                  selected: current == null,
                  onTap: () => Navigator.pop(context, null),
                  surfaceColor: scheme.onSurface,
                ),
                const SizedBox(height: 10),
              ],
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in options)
                    TypeChip.option(
                      t,
                      key: ValueKey('type_option_${t.name}'),
                      selected: current == t,
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

class _NoneChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color surfaceColor;
  const _NoneChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('type_option_none'),
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
          label,
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

/// Types a Pokémon can Terastallize into: the 18 regular types plus
/// Stellar.
const List<PokemonType> kTeraTypes = <PokemonType>[
  ...kMainTypes,
  PokemonType.stellar,
];
