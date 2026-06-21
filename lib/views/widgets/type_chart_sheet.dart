import 'package:flutter/material.dart';
import '../../models/type.dart';
import '../../utils/ability_effects.dart' show abilityAdjustedDefensiveMultiplier;
import '../../utils/app_strings.dart';
import '../../utils/localization.dart' show KoStrings;

/// Classic Pokémon 18×18 type-effectiveness matrix in the same
/// `Table` form the team-coverage matrix uses: type labels in the
/// header row/column with cells coloured by multiplier.
///
/// Rows = attacking type, columns = defending type. Labels use
/// `KoStrings.getTypeName` so they pick up the user's locale
/// (한국어 / English / 日本語).
class TypeChartSheet extends StatelessWidget {
  const TypeChartSheet({super.key});

  static void show(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1100,
              maxHeight: size.height * 0.85,
            ),
            child: const TypeChartSheet(),
          ),
        );
      },
    );
  }

  static const _types = <PokemonType>[
    PokemonType.normal, PokemonType.fire, PokemonType.water, PokemonType.electric,
    PokemonType.grass, PokemonType.ice, PokemonType.fighting, PokemonType.poison,
    PokemonType.ground, PokemonType.flying, PokemonType.psychic, PokemonType.bug,
    PokemonType.rock, PokemonType.ghost, PokemonType.dragon, PokemonType.dark,
    PokemonType.steel, PokemonType.fairy,
  ];

  static const _labelCol = 52.0;
  static const _cellCol = 36.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          child: Row(children: [
            Expanded(
              child: Text(
                AppStrings.t('typeChart.title'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
              visualDensity: VisualDensity.compact,
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(
            AppStrings.t('typeChart.legend'),
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                child: _buildTable(scheme),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(ColorScheme scheme) {
    return Table(
      columnWidths: {
        0: const FixedColumnWidth(_labelCol),
        for (int i = 0; i < _types.length; i++)
          i + 1: const FixedColumnWidth(_cellCol),
      },
      border: TableBorder(
        top:    BorderSide(color: scheme.outlineVariant, width: 0.6),
        bottom: BorderSide(color: scheme.outlineVariant, width: 0.6),
        left:   BorderSide(color: scheme.outlineVariant, width: 0.6),
        right:  BorderSide(color: scheme.outlineVariant, width: 0.6),
        horizontalInside: BorderSide(color: scheme.outlineVariant, width: 0.5),
        verticalInside:   BorderSide(color: scheme.outlineVariant, width: 0.5),
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Header row — defender types
        TableRow(children: [
          _CornerHeader(),
          for (final d in _types) _TypeLabelCell(type: d, horizontal: false),
        ]),
        // 18 attacker rows
        for (final atk in _types)
          TableRow(children: [
            _TypeLabelCell(type: atk, horizontal: true),
            for (final def in _types)
              _MultCell(
                mult: abilityAdjustedDefensiveMultiplier(atk, def, null),
              ),
          ]),
      ],
    );
  }
}

class _CornerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 32,
      child: Center(
        child: Text('↘', style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}

class _TypeLabelCell extends StatelessWidget {
  final PokemonType type;
  /// `true` when this cell sits in the leftmost column (row label);
  /// `false` for the top-row (column label). Visual only — both use
  /// the type colour as background.
  final bool horizontal;
  const _TypeLabelCell({required this.type, required this.horizontal});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: horizontal ? 32 : 32,
      color: KoStrings.getTypeColor(type),
      alignment: Alignment.center,
      child: Text(
        KoStrings.getTypeName(type),
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.clip,
      ),
    );
  }
}

class _MultCell extends StatelessWidget {
  final double mult;
  const _MultCell({required this.mult});

  @override
  Widget build(BuildContext context) {
    final (bg, label, fg) = _styleFor(mult);
    return Container(
      height: 32,
      color: bg,
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  static (Color, String, Color) _styleFor(double m) {
    if (m == 0.0) return (Colors.grey.shade800, '0', Colors.white);
    if (m == 0.5) return (Colors.green.shade600, '½', Colors.white);
    if (m == 2.0) return (Colors.red.shade600,   '2', Colors.white);
    return (Colors.transparent, '', Colors.black);
  }
}
