import 'package:flutter/material.dart';
import '../../models/type.dart';
import '../../utils/ability_effects.dart' show abilityAdjustedDefensiveMultiplier;
import '../../utils/app_strings.dart';
import '../../utils/localization.dart' show KoStrings;

/// Classic Pokémon 18×18 type-effectiveness matrix.
/// Rows = attacking type, columns = defending type. Cells colour-
/// coded: red ×2, green ×½, yellow ×0, blank ×1.
///
/// Single-type defender chart only — dual-type matchups already
/// surface on the per-Pokémon dex page (this widget is the quick
/// reference table competitive players keep open in a tab).
class TypeChartSheet extends StatelessWidget {
  const TypeChartSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const SafeArea(top: false, child: TypeChartSheet()),
      constraints: const BoxConstraints(maxWidth: 720),
    );
  }

  static const _types = <PokemonType>[
    PokemonType.normal, PokemonType.fire, PokemonType.water, PokemonType.electric,
    PokemonType.grass, PokemonType.ice, PokemonType.fighting, PokemonType.poison,
    PokemonType.ground, PokemonType.flying, PokemonType.psychic, PokemonType.bug,
    PokemonType.rock, PokemonType.ghost, PokemonType.dragon, PokemonType.dark,
    PokemonType.steel, PokemonType.fairy,
  ];

  static const _cell = 28.0;
  static const _headerCell = 32.0;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              AppStrings.t('typeChart.title'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              AppStrings.t('typeChart.legend'),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
          const Divider(height: 1),
          // Horizontally + vertically scrollable matrix
          Expanded(
            child: Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  child: _Matrix(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Matrix extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top header row: corner cell + 18 defender chips
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CornerHeader(),
            for (final d in TypeChartSheet._types) _DefenderHeader(type: d),
          ],
        ),
        // 18 attacker rows
        for (final atk in TypeChartSheet._types)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AttackerHeader(type: atk),
              for (final def in TypeChartSheet._types)
                _Cell(mult: abilityAdjustedDefensiveMultiplier(atk, def, null)),
            ],
          ),
      ],
    );
  }
}

class _CornerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: TypeChartSheet._headerCell,
      height: TypeChartSheet._headerCell,
      child: Center(
        child: Text(
          '↘',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ),
    );
  }
}

class _DefenderHeader extends StatelessWidget {
  final PokemonType type;
  const _DefenderHeader({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: TypeChartSheet._cell,
      height: TypeChartSheet._headerCell,
      decoration: BoxDecoration(
        color: KoStrings.getTypeColor(type),
        border: Border.all(color: Colors.white, width: 0.5),
      ),
      alignment: Alignment.center,
      child: Text(
        _abbrev(type),
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AttackerHeader extends StatelessWidget {
  final PokemonType type;
  const _AttackerHeader({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: TypeChartSheet._headerCell,
      height: TypeChartSheet._cell,
      decoration: BoxDecoration(
        color: KoStrings.getTypeColor(type),
        border: Border.all(color: Colors.white, width: 0.5),
      ),
      alignment: Alignment.center,
      child: Text(
        _abbrev(type),
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final double mult;
  const _Cell({required this.mult});

  @override
  Widget build(BuildContext context) {
    final (bg, label) = _styleFor(mult);
    return Container(
      width: TypeChartSheet._cell,
      height: TypeChartSheet._cell,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: Colors.white, width: 0.5),
      ),
      alignment: Alignment.center,
      child: label.isEmpty
          ? const SizedBox.shrink()
          : Text(
              label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
    );
  }

  static (Color, String) _styleFor(double m) {
    if (m == 0.0) return (Colors.grey.shade700, '0');
    if (m == 0.5) return (Colors.green.shade600, '½');
    if (m == 2.0) return (Colors.red.shade600, '2');
    return (Colors.grey.shade100, ''); // neutral ×1
  }
}

/// Short 2-character type abbreviation rendered into the header cells.
/// Matches Bulbapedia / Serebii / community charts so the cells stay
/// readable inside ~28-px squares (full Korean / Japanese / English
/// names won't fit at that size).
String _abbrev(PokemonType t) {
  switch (t) {
    case PokemonType.normal:   return 'NOR';
    case PokemonType.fire:     return 'FIR';
    case PokemonType.water:    return 'WAT';
    case PokemonType.electric: return 'ELE';
    case PokemonType.grass:    return 'GRA';
    case PokemonType.ice:      return 'ICE';
    case PokemonType.fighting: return 'FIG';
    case PokemonType.poison:   return 'POI';
    case PokemonType.ground:   return 'GRD';
    case PokemonType.flying:   return 'FLY';
    case PokemonType.psychic:  return 'PSY';
    case PokemonType.bug:      return 'BUG';
    case PokemonType.rock:     return 'ROC';
    case PokemonType.ghost:    return 'GHO';
    case PokemonType.dragon:   return 'DRA';
    case PokemonType.dark:     return 'DRK';
    case PokemonType.steel:    return 'STL';
    case PokemonType.fairy:    return 'FAI';
    default:                   return '?';
  }
}
