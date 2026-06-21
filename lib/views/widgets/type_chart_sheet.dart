import 'package:flutter/material.dart';
import '../../models/type.dart';
import '../../utils/ability_effects.dart' show abilityAdjustedDefensiveMultiplier;
import '../../utils/app_strings.dart';
import '../../utils/localization.dart' show KoStrings;

/// Generic type-effectiveness chart — pick a defending type combo
/// (1 or 2 types) and see every attacking type sorted into
/// ×4 / ×2 / ×1 / ×½ / ×¼ / ×0 buckets. Mirrors the dex's per-Pokémon
/// matchup chart but without needing a species selected; useful as a
/// quick reference while team-building.
class TypeChartSheet extends StatefulWidget {
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

  @override
  State<TypeChartSheet> createState() => _TypeChartSheetState();
}

class _TypeChartSheetState extends State<TypeChartSheet> {
  PokemonType _type1 = PokemonType.normal;
  PokemonType? _type2;

  // 18 attackable types — excludes typeless (used for type-stripped
  // mons, doesn't appear in the chart) and stellar (Terastal-only).
  static const _allTypes = <PokemonType>[
    PokemonType.normal, PokemonType.fire, PokemonType.water, PokemonType.electric,
    PokemonType.grass, PokemonType.ice, PokemonType.fighting, PokemonType.poison,
    PokemonType.ground, PokemonType.flying, PokemonType.psychic, PokemonType.bug,
    PokemonType.rock, PokemonType.ghost, PokemonType.dragon, PokemonType.dark,
    PokemonType.steel, PokemonType.fairy,
  ];

  void _toggleType(PokemonType t) {
    setState(() {
      // Tap on a slot's current type to clear it (slot 2 only).
      if (t == _type1) {
        if (_type2 != null) {
          _type1 = _type2!;
          _type2 = null;
        }
        return;
      }
      if (t == _type2) {
        _type2 = null;
        return;
      }
      // Otherwise assign: slot 2 if empty, else replace slot 2.
      if (_type2 == null) {
        _type2 = t;
      } else {
        _type2 = t;
      }
    });
  }

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
          const Divider(height: 1),
          // Selected defender type chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  AppStrings.t('typeChart.defender'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                _typeBadge(_type1, primary: true),
                if (_type2 != null) ...[
                  const SizedBox(width: 6),
                  _typeBadge(_type2!, primary: false),
                ],
              ],
            ),
          ),
          // Type selector grid (tap to set/swap)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in _allTypes) _selectorChip(t),
              ],
            ),
          ),
          const Divider(height: 1),
          // Matchup buckets
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: _MatchupGrid(type1: _type1, type2: _type2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(PokemonType t, {required bool primary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: KoStrings.getTypeColor(t),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: primary ? Colors.black87 : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Text(
        KoStrings.getTypeName(t),
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _selectorChip(PokemonType t) {
    final isPicked = t == _type1 || t == _type2;
    return GestureDetector(
      onTap: () => _toggleType(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: KoStrings.getTypeColor(t).withValues(alpha: isPicked ? 1.0 : 0.55),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          KoStrings.getTypeName(t),
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: isPicked ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _MatchupGrid extends StatelessWidget {
  final PokemonType type1;
  final PokemonType? type2;
  const _MatchupGrid({required this.type1, this.type2});

  @override
  Widget build(BuildContext context) {
    final buckets = <double, List<PokemonType>>{
      4.0: [], 2.0: [], 1.0: [], 0.5: [], 0.25: [], 0.0: [],
    };
    for (final atk in _TypeChartSheetState._allTypes) {
      final m = abilityAdjustedDefensiveMultiplier(atk, type1, type2);
      if (buckets.containsKey(m)) buckets[m]!.add(atk);
    }
    final keys = buckets.entries.where((e) => e.value.isNotEmpty)
        .map((e) => e.key).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final k in keys)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(_multLabel(k),
                    style: TextStyle(
                        fontSize: 12,
                        color: _multColor(k),
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (final t in buckets[k]!) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: KoStrings.getTypeColor(t),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      KoStrings.getTypeName(t),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
      ],
    );
  }

  static String _multLabel(double mult) {
    if (mult == 4.0) return '×4';
    if (mult == 2.0) return '×2';
    if (mult == 1.0) return '×1';
    if (mult == 0.5) return '×½';
    if (mult == 0.25) return '×¼';
    if (mult == 0.0) return '×0';
    return '×$mult';
  }

  static Color _multColor(double mult) {
    if (mult >= 2.0) return Colors.red;
    if (mult > 0 && mult < 1) return Colors.green;
    if (mult == 0) return Colors.grey;
    return Colors.black;
  }
}
