import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/battle_pokemon.dart';
import '../../models/move.dart';
import '../../models/nature.dart';
import '../../models/rank.dart';
import '../../models/stats.dart';
import '../../models/status.dart';
import '../../models/terrain.dart';
import '../../models/type.dart';
import '../../models/weather.dart';
import '../../utils/ability_effects.dart';
import '../../utils/grounded.dart';
import '../../utils/item_effects.dart';
import '../../utils/move_transform.dart';
import '../../utils/offensive_calculator.dart';
import '../../utils/stat_calculator.dart';
import 'move_selector.dart';
import 'pokemon_selector.dart';
import 'stat_input.dart';

/// A reusable panel for configuring one side of a battle (attacker or defender).
class PokemonPanel extends StatefulWidget {
  final BattlePokemonState state;
  final Weather weather;
  final Terrain terrain;
  final VoidCallback onChanged;
  final int resetCounter;

  const PokemonPanel({
    super.key,
    required this.state,
    required this.weather,
    required this.terrain,
    required this.onChanged,
    required this.resetCounter,
  });

  @override
  State<PokemonPanel> createState() => _PokemonPanelState();
}

class _PokemonPanelState extends State<PokemonPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _movesSectionKey = GlobalKey();
  final _scrollController = ScrollController();

  BattlePokemonState get s => widget.state;

  void _notify() {
    widget.onChanged();
  }

  void _scrollToMoves() {
    _doScrollToMoves();
    Future.delayed(const Duration(milliseconds: 500), _doScrollToMoves);
  }

  void _doScrollToMoves() {
    final ctx = _movesSectionKey.currentContext;
    if (ctx == null) return;

    final box = ctx.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero).dy;
    final appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
    final target = _scrollController.offset + offset - appBarHeight;

    _scrollController.animateTo(
      target.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  int? _computeResultFor(Move? move, bool isCritical, {
    PokemonType? typeOverride,
    MoveCategory? categoryOverride,
    int? powerOverride,
  }) {
    if (move == null) return null;
    move = move.copyWith(
      type: typeOverride,
      power: powerOverride,
      category: categoryOverride,
    );

    final context = MoveContext(
      weather: widget.weather,
      terrain: widget.terrain,
      rank: s.rank,
      hpPercent: s.hpPercent,
      hasItem: s.selectedItem != null,
      ability: s.selectedAbility,
      status: s.status,
    );
    final transformed = transformMove(move, context);

    final itemEffect = s.selectedItem != null
        ? getItemEffect(s.selectedItem!, move: transformed.move)
        : const ItemEffect();
    final abilityEffect = s.selectedAbility != null
        ? getAbilityEffect(s.selectedAbility!, move: transformed.move,
            hpPercent: s.hpPercent, weather: widget.weather,
            terrain: widget.terrain, status: s.status,
            actualStats: StatCalculator.calculate(
              baseStats: s.baseStats, iv: s.iv, ev: s.ev,
              nature: s.nature, level: s.level,
            ))
        : const AbilityEffect();

    final double abilityStatMod;
    switch (transformed.offensiveStat) {
      case OffensiveStat.attack:
        abilityStatMod = abilityEffect.statModifiers.attack;
      case OffensiveStat.spAttack:
        abilityStatMod = abilityEffect.statModifiers.spAttack;
      case OffensiveStat.defense:
        abilityStatMod = abilityEffect.statModifiers.defense;
      case OffensiveStat.higherAttack:
        abilityStatMod = math.max(
          abilityEffect.statModifiers.attack,
          abilityEffect.statModifiers.spAttack,
        );
    }

    final double statMod = itemEffect.statModifier * abilityStatMod;
    final double powerMod =
        itemEffect.powerModifier * abilityEffect.powerModifier;

    return OffensiveCalculator.calculate(
      baseStats: s.baseStats,
      iv: s.iv,
      ev: s.ev,
      nature: s.nature,
      level: s.level,
      transformed: transformed,
      type1: s.type1,
      type2: s.type2,
      rank: s.rank,
      weather: widget.weather,
      terrain: widget.terrain,
      statModifier: statMod,
      powerModifier: powerMod,
      isCritical: isCritical,
      grounded: isGrounded(
        type1: s.type1,
        type2: s.type2,
        ability: s.selectedAbility,
        item: s.selectedItem,
      ),
      status: s.status,
      hasGuts: s.selectedAbility == 'Guts',
      stabOverride: abilityEffect.stabOverride,
      criticalOverride: abilityEffect.criticalOverride,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(16, 16, 16,
          MediaQuery.of(context).size.height * 0.5 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionCard(
            title: '포켓몬',
            child: PokemonSelector(
              key: ValueKey('pokemon_${widget.resetCounter}'),
              onSelected: (name, type1, type2, baseStats, abilities) {
                setState(() {
                  s.type1 = type1;
                  s.type2 = type2;
                  s.baseStats = baseStats;
                  s.pokemonAbilities = abilities;
                  s.selectedAbility =
                      abilities.isNotEmpty ? abilities.first : null;
                });
                _notify();
              },
            ),
          ),
          const SizedBox(height: 12),

          _sectionCard(
            title: '능력치',
            child: StatInput(
              key: ValueKey('stats_${widget.resetCounter}'),
              level: s.level,
              nature: s.nature,
              iv: s.iv,
              ev: s.ev,
              baseStats: s.baseStats,
              pokemonAbilities: s.pokemonAbilities,
              selectedAbility: s.selectedAbility,
              selectedItem: s.selectedItem,
              rank: s.rank,
              hpPercent: s.hpPercent,
              onLevelChanged: (v) => setState(() { s.level = v; _notify(); }),
              onNatureChanged: (v) => setState(() { s.nature = v; _notify(); }),
              onIvChanged: (v) => setState(() { s.iv = v; _notify(); }),
              onEvChanged: (v) => setState(() { s.ev = v; _notify(); }),
              onAbilityChanged: (v) => setState(() { s.selectedAbility = v; _notify(); }),
              onItemChanged: (v) => setState(() { s.selectedItem = v; _notify(); }),
              onRankChanged: (v) => setState(() { s.rank = v; _notify(); }),
              onHpPercentChanged: (v) => setState(() { s.hpPercent = v; _notify(); }),
            ),
          ),
          const SizedBox(height: 12),

          _sectionCard(
            title: '상태이상',
            child: DropdownButtonFormField<StatusCondition>(
              value: s.status,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: StatusCondition.values
                  .map((st) => DropdownMenuItem(
                      value: st, child: Text(_statusKo(st))))
                  .toList(),
              onChanged: (v) => setState(() { s.status = v!; _notify(); }),
            ),
          ),
          const SizedBox(height: 12),

          _sectionCard(
            key: _movesSectionKey,
            title: '기술',
            child: Column(
              children: [
                _moveHeader(context),
                const Divider(height: 1),
                for (int i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(height: 2),
                  _moveSlot(i),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moveHeader(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('기술명', style: style)),
          SizedBox(width: 40, child: Text('타입', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 32, child: Text('분류', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 44, child: Text('위력', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 28, child: Text('급소', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 60, child: Text('결정력', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _moveSlot(int index) {
    final move = s.moves[index];
    var effectiveType = s.typeOverrides[index] ?? move?.type;
    final effectiveCategory = s.categoryOverrides[index] ?? move?.category;
    final int basePower;
    if (move != null) {
      final ctx = MoveContext(
        weather: widget.weather,
        terrain: widget.terrain,
        rank: s.rank,
        hpPercent: s.hpPercent,
        hasItem: s.selectedItem != null,
        ability: s.selectedAbility,
        status: s.status,
      );
      final transformed = transformMove(move, ctx);
      basePower = transformed.move.power;
      effectiveType = s.typeOverrides[index] ?? transformed.move.type;
    } else {
      basePower = 0;
    }
    final effectivePower = s.powerOverrides[index] ?? basePower;
    final result = _computeResultFor(move, s.criticals[index],
      typeOverride: s.typeOverrides[index],
      categoryOverride: s.categoryOverrides[index],
      powerOverride: s.powerOverrides[index],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: MoveSelector(
              key: ValueKey('move_${index}_${widget.resetCounter}'),
              onTap: _scrollToMoves,
              onSelected: (m) => setState(() {
                s.moves[index] = m;
                s.typeOverrides[index] = null;
                s.categoryOverrides[index] = null;
                s.powerOverrides[index] = null;
                s.criticals[index] = m.hasTag('custom:always_crit');
                _notify();
              }),
            ),
          ),
          SizedBox(
            width: 40,
            child: move != null
                ? PopupMenuButton<PokemonType>(
                    initialValue: effectiveType,
                    padding: EdgeInsets.zero,
                    child: Text(
                      _typeKo(effectiveType!),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: s.typeOverrides[index] != null ? Colors.orange : null,
                      ),
                    ),
                    itemBuilder: (_) => PokemonType.values
                        .map((t) => PopupMenuItem(value: t, child: Text(_typeKo(t), style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onSelected: (t) => setState(() { s.typeOverrides[index] = t; _notify(); }),
                  )
                : const Text('-', textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 32,
            child: move != null
                ? PopupMenuButton<MoveCategory>(
                    initialValue: effectiveCategory,
                    padding: EdgeInsets.zero,
                    child: Text(
                      _categoryKo(effectiveCategory!),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: s.categoryOverrides[index] != null ? Colors.orange : null,
                      ),
                    ),
                    itemBuilder: (_) => [MoveCategory.physical, MoveCategory.special]
                        .map((c) => PopupMenuItem(value: c, child: Text(_categoryKo(c), style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onSelected: (c) => setState(() { s.categoryOverrides[index] = c; _notify(); }),
                  )
                : const Text('-', textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 44,
            child: move != null
                ? SizedBox(
                    height: 28,
                    child: TextFormField(
                      key: ValueKey('power_${index}_${move.name}_$effectivePower'),
                      initialValue: '${effectivePower}',
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                      ),
                      onChanged: (text) {
                        final parsed = int.tryParse(text);
                        if (parsed != null && parsed >= 0) {
                          setState(() { s.powerOverrides[index] = parsed; _notify(); });
                        }
                      },
                    ),
                  )
                : const Text('-', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
          ),
          SizedBox(
            width: 28,
            child: Checkbox(
              value: s.criticals[index],
              onChanged: (v) => setState(() { s.criticals[index] = v ?? false; _notify(); }),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              result != null ? '$result' : '-',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({Key? key, required String title, required Widget child}) {
    return Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  String _statusKo(StatusCondition st) {
    switch (st) {
      case StatusCondition.none: return '없음';
      case StatusCondition.burn: return '화상';
      case StatusCondition.poison: return '독';
      case StatusCondition.badlyPoisoned: return '맹독';
      case StatusCondition.paralysis: return '마비';
      case StatusCondition.sleep: return '잠듦';
      case StatusCondition.freeze: return '얼음';
    }
  }

  String _typeKo(PokemonType t) {
    const map = {
      PokemonType.normal: '노말', PokemonType.fire: '불꽃',
      PokemonType.water: '물', PokemonType.electric: '전기',
      PokemonType.grass: '풀', PokemonType.ice: '얼음',
      PokemonType.fighting: '격투', PokemonType.poison: '독',
      PokemonType.ground: '땅', PokemonType.flying: '비행',
      PokemonType.psychic: '에스퍼', PokemonType.bug: '벌레',
      PokemonType.rock: '바위', PokemonType.ghost: '고스트',
      PokemonType.dragon: '드래곤', PokemonType.dark: '악',
      PokemonType.steel: '강철', PokemonType.fairy: '페어리',
    };
    return map[t] ?? t.name;
  }

  String _categoryKo(MoveCategory c) {
    switch (c) {
      case MoveCategory.physical: return '물리';
      case MoveCategory.special: return '특수';
      case MoveCategory.status: return '변화';
    }
  }
}
