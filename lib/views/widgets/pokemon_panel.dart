import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import '../../models/battle_pokemon.dart';
import '../../models/move.dart';
import '../../models/room.dart';
import '../../models/nature.dart';
import '../../models/rank.dart';
import '../../models/stats.dart';
import '../../models/status.dart';
import '../../models/terrain.dart';
import '../../models/type.dart';
import '../../models/weather.dart';
import '../../models/move_tags.dart';
import '../../utils/ability_effects.dart';
import '../../utils/grounded.dart';
import '../../utils/item_effects.dart';
import '../../utils/localization.dart';
import '../../utils/move_transform.dart';
import '../../utils/defensive_calculator.dart';
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
  final Room room;
  final String label;
  final VoidCallback onChanged;
  final int resetCounter;
  final bool isAttacker;
  final int? opponentSpeed;

  const PokemonPanel({
    super.key,
    required this.state,
    required this.weather,
    required this.terrain,
    this.room = Room.none,
    this.label = '',
    required this.onChanged,
    required this.resetCounter,
    this.isAttacker = true,
    this.opponentSpeed,
  });

  @override
  State<PokemonPanel> createState() => PokemonPanelState();
}

class PokemonPanelState extends State<PokemonPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _movesSectionKey = GlobalKey();
  final _scrollController = ScrollController();
  final _screenshotController = ScreenshotController();

  BattlePokemonState get s => widget.state;




  Future<Uint8List?> captureScreenshot() async {
    try {
      return await _screenshotController.capture(
        delay: const Duration(milliseconds: 100),
        pixelRatio: 2.0,
      );
    } catch (e) {
      return null;
    }
  }

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
        ? getItemEffect(s.selectedItem!, move: transformed.move, pokemonName: s.pokemonName)
        : const ItemEffect();
    final abilityEffect = s.selectedAbility != null
        ? getAbilityEffect(s.selectedAbility!, move: transformed.move,
            hpPercent: s.hpPercent, weather: widget.weather,
            terrain: widget.terrain, status: s.status,
            heldItem: s.selectedItem,
            opponentSpeed: widget.opponentSpeed,
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

    double statMod = itemEffect.statModifier * abilityStatMod;
    double powerMod = itemEffect.powerModifier * abilityEffect.powerModifier;

    // Ally boost effects
    if (s.helpingHand) powerMod *= 1.5;
    if (s.charge && move.type == PokemonType.electric) powerMod *= 2.0;
    if (s.battery && move.category == MoveCategory.special) powerMod *= 1.3;
    if (s.powerSpot) powerMod *= 1.3;
    if (s.flowerGift && move.category == MoveCategory.physical &&
        (widget.weather == Weather.sun || widget.weather == Weather.harshSun)) statMod *= 1.5;
    if (s.steelySpirit && move.type == PokemonType.steel) powerMod *= 1.5;

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
      child: Screenshot(
        controller: _screenshotController,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Capture header (weather/terrain/room info)
              _captureHeader(),
              const SizedBox(height: 8),
          _sectionCard(
            title: '포켓몬',
            child: PokemonSelector(
              key: ValueKey('pokemon_${widget.resetCounter}_${s.pokemonName}'),
              initialPokemonName: s.pokemonName,
              onSelected: (name, type1, type2, baseStats, abilities, finalEvo, requiredItem) {
                setState(() {
                  s.pokemonName = name;
                  s.finalEvo = finalEvo;
                  s.type1 = type1;
                  s.type2 = type2;
                  s.baseStats = baseStats;
                  s.pokemonAbilities = abilities;
                  s.selectedAbility =
                      abilities.isNotEmpty ? abilities.first : null;
                  // Auto-select required item for mega/form-change Pokemon
                  if (requiredItem != null) {
                    s.selectedItem = requiredItem;
                  }
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
              status: s.status,
              onLevelChanged: (v) => setState(() { s.level = v; _notify(); }),
              onNatureChanged: (v) => setState(() { s.nature = v; _notify(); }),
              onIvChanged: (v) => setState(() { s.iv = v; _notify(); }),
              onEvChanged: (v) => setState(() { s.ev = v; _notify(); }),
              onAbilityChanged: (v) => setState(() { s.selectedAbility = v; _notify(); }),
              onItemChanged: (v) => setState(() { s.selectedItem = v; _notify(); }),
              onRankChanged: (v) => setState(() { s.rank = v; _notify(); }),
              opponentSpeed: widget.opponentSpeed,
              onHpPercentChanged: (v) => setState(() { s.hpPercent = v; _notify(); }),
              onStatusChanged: (v) => setState(() { s.status = v; _notify(); }),
            ),
          ),
          const SizedBox(height: 12),

          if (widget.isAttacker) ...[
            _sectionCard(
              title: '기타 보정',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _compactCheck('도우미', s.helpingHand, (v) {
                        setState(() { s.helpingHand = v; _notify(); });
                      })),
                      Expanded(child: _compactCheck('배터리', s.battery, (v) {
                        setState(() { s.battery = v; _notify(); });
                      })),
                      Expanded(child: _compactCheck('파워스폿', s.powerSpot, (v) {
                        setState(() { s.powerSpot = v; _notify(); });
                      })),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _compactCheck('충전', s.charge, (v) {
                        setState(() { s.charge = v; _notify(); });
                      })),
                      Expanded(child: _compactCheck('강철정신', s.steelySpirit, (v) {
                        setState(() { s.steelySpirit = v; _notify(); });
                      })),
                      Expanded(child: _compactCheck('플라워기프트', s.flowerGift, (v) {
                        setState(() { s.flowerGift = v; _notify(); });
                      })),
                    ],
                  ),
                ],
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
          ] else ...[
            _sectionCard(
              title: '기타 보정',
              child: Row(
                children: [
                  Expanded(child: _compactCheck('플라워기프트', s.flowerGift, (v) {
                    setState(() { s.flowerGift = v; _notify(); });
                  })),
                  const Expanded(child: SizedBox()),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _bulkDisplay(),
          ],
        ],
      ),
    )),
    );
  }

  Widget _bulkDisplay() {
    final bulk = DefensiveCalculator.calculate(
      baseStats: s.baseStats,
      iv: s.iv,
      ev: s.ev,
      nature: s.nature,
      level: s.level,
      type1: s.type1,
      type2: s.type2,
      rank: s.rank,
      weather: widget.weather,
      ability: s.selectedAbility,
      item: s.selectedItem,
      finalEvo: s.finalEvo,
      status: s.status,
      flowerGift: s.flowerGift,
    );

    return _sectionCard(
      title: '내구',
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text('물리 내구', style: TextStyle(
                  fontSize: 12, color: Colors.blue[400],
                )),
                const SizedBox(height: 4),
                Text('${bulk.physical}', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                )),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.blue.withValues(alpha: 0.2)),
          Expanded(
            child: Column(
              children: [
                Text('특수 내구', style: TextStyle(
                  fontSize: 12, color: Colors.blue[400],
                )),
                const SizedBox(height: 4),
                Text('${bulk.special}', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _captureHeader() {
    final parts = <String>[];
    if (widget.label.isNotEmpty) parts.add(widget.label);
    if (widget.weather != Weather.none) parts.add(KoStrings.weatherKoWithIcon[widget.weather]!);
    if (widget.terrain != Terrain.none) parts.add(KoStrings.terrainKoWithIcon[widget.terrain]!);
    if (widget.room != Room.none) parts.add(KoStrings.roomKoWithIcon[widget.room]!);

    if (parts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text(
        parts.join(' | '),
        style: TextStyle(
          fontSize: 12,
          color: widget.isAttacker ? Colors.red[400] : Colors.blue[400],
        ),
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
              key: ValueKey('move_${index}_${widget.resetCounter}_${s.moves[index]?.name}'),
              initialMoveName: s.moves[index]?.name,
              onTap: _scrollToMoves,
              onSelected: (m) => setState(() {
                s.moves[index] = m;
                s.typeOverrides[index] = null;
                s.categoryOverrides[index] = null;
                s.powerOverrides[index] = null;
                s.criticals[index] = m.hasTag(MoveTags.alwaysCrit);
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
                      KoStrings.getTypeKo(effectiveType!),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: s.typeOverrides[index] != null ? Colors.orange : null,
                      ),
                    ),
                    itemBuilder: (_) => PokemonType.values
                        .map((t) => PopupMenuItem(value: t, child: Text(KoStrings.getTypeKo(t), style: const TextStyle(fontSize: 12))))
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
                      KoStrings.getCategoryKo(effectiveCategory!),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: s.categoryOverrides[index] != null ? Colors.orange : null,
                      ),
                    ),
                    itemBuilder: (_) => [MoveCategory.physical, MoveCategory.special]
                        .map((c) => PopupMenuItem(value: c, child: Text(KoStrings.getCategoryKo(c), style: const TextStyle(fontSize: 12))))
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

  Widget _compactCheck(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22, height: 22,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: const TextStyle(fontSize: 13)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({Key? key, required String title, required Widget child}) {
    final accentColor = widget.isAttacker ? Colors.red : Colors.blue;
    final cardColor = Color.lerp(Theme.of(context).cardColor, accentColor, 0.06);
    final titleColor = widget.isAttacker ? Colors.red[700] : Colors.blue[700];

    return Card(
      key: key,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: titleColor,
            )),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

}
