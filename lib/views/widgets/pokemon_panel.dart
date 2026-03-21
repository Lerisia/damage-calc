import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import '../../models/battle_pokemon.dart';
import '../../models/dynamax.dart';
import '../../models/gender.dart';
import '../../models/terastal.dart';
import '../../models/move.dart';
import '../../models/room.dart';
import '../../models/terrain.dart';
import '../../models/type.dart';
import '../../models/weather.dart';
import '../../models/move_tags.dart';
import '../../utils/battle_facade.dart';
import '../../utils/localization.dart';
import 'move_selector.dart';
import 'pokemon_selector.dart';
import 'stat_input.dart';

/// A reusable panel for configuring one side of a battle (attacker or defender).
class PokemonPanel extends StatefulWidget {
  final BattlePokemonState state;
  final Weather weather;
  final Terrain terrain;
  final RoomConditions room;
  final String label;
  final VoidCallback onChanged;
  final int resetCounter;
  final bool isAttacker;
  final int? opponentSpeed;
  final bool opponentAlwaysLast;
  final int? opponentAttack;
  final Gender? opponentGender;

  const PokemonPanel({
    super.key,
    required this.state,
    required this.weather,
    required this.terrain,
    this.room = const RoomConditions(),
    this.label = '',
    required this.onChanged,
    required this.resetCounter,
    this.isAttacker = true,
    this.opponentSpeed,
    this.opponentAlwaysLast = false,
    this.opponentAttack,
    this.opponentGender,
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

  int? get myEffectiveSpeed {
    if (widget.opponentSpeed == null) return null;
    return BattleFacade.calcSpeed(
      state: s,
      weather: widget.weather,
      terrain: widget.terrain,
    );
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

  /// Public accessor for 결정력 of a specific move slot.
  int? computeResultFor(int moveIndex) {
    return BattleFacade.calcOffensivePower(
      state: s,
      moveIndex: moveIndex,
      weather: widget.weather,
      terrain: widget.terrain,
      room: widget.room,
      opponentSpeed: widget.opponentSpeed,
      opponentAttack: widget.opponentAttack,
      opponentGender: widget.opponentGender ?? Gender.unset,
      myEffectiveSpeed: myEffectiveSpeed,
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
            child: Row(children: [
            Expanded(child: PokemonSelector(
              key: ValueKey('pokemon_${widget.resetCounter}_${s.pokemonName}'),
              initialPokemonName: s.pokemonName,
              onSelected: (pokemon) {
                setState(() {
                  s.pokemonName = pokemon.name;
                  s.pokemonNameKo = pokemon.nameKo;
                  s.finalEvo = pokemon.finalEvo;
                  s.canDynamax = pokemon.canDynamax;
                  s.canGmax = pokemon.canGmax;
                  s.dynamax = DynamaxState.none;
                  s.terastal = const TerastalState();
                  s.genderRate = pokemon.genderRate;
                  if (pokemon.genderRate == -1) {
                    s.gender = Gender.genderless;
                  } else if (pokemon.genderRate == 0) {
                    s.gender = Gender.male;
                  } else if (pokemon.genderRate == 8) {
                    s.gender = Gender.female;
                  } else {
                    s.gender = Gender.unset;
                  }
                  s.type1 = pokemon.type1;
                  s.type2 = pokemon.type2;
                  s.baseStats = pokemon.baseStats;
                  s.pokemonAbilities = pokemon.abilities;
                  s.selectedAbility =
                      pokemon.abilities.isNotEmpty ? pokemon.abilities.first : null;
                  if (pokemon.requiredItem != null) {
                    s.selectedItem = pokemon.requiredItem;
                  }
                });
                _notify();
              },
            )),
            const SizedBox(width: 8),
            _genderIcon(),
            const SizedBox(width: 4),
            _dynamaxIcon(),
            const SizedBox(width: 4),
            _terastalIcon(),
          ]),),
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
              opponentAlwaysLast: widget.opponentAlwaysLast,
              isDynamaxed: s.dynamax != DynamaxState.none,
              tailwind: s.tailwind,
              weather: widget.weather,
              terrain: widget.terrain,
              room: widget.room,
              onHpPercentChanged: (v) => setState(() { s.hpPercent = v; _notify(); }),
              onStatusChanged: (v) => setState(() { s.status = v; _notify(); }),
            ),
          ),
          const SizedBox(height: 12),

          _sectionCard(
            title: '기타 보정',
            child: Row(
              children: [
                if (widget.isAttacker)
                  Expanded(child: _compactCheck('충전', s.charge, (v) {
                    setState(() { s.charge = v; _notify(); });
                  }))
                else
                  const Expanded(child: SizedBox()),
                Expanded(child: _compactCheck('순풍', s.tailwind, (v) {
                  setState(() { s.tailwind = v; _notify(); });
                })),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (widget.isAttacker) ...[
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
            _bulkDisplay(),
          ],
        ],
      ),
    )),
    );
  }

  Widget _bulkDisplay() {
    final bulk = BattleFacade.calcBulk(
      state: s,
      weather: widget.weather,
      room: widget.room,
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
    if (widget.room.trickRoom) parts.add('🔄트릭룸');
    if (widget.room.magicRoom) parts.add('✨매직룸');
    if (widget.room.wonderRoom) parts.add('❓원더룸');
    if (widget.room.gravity) parts.add('🌀중력');

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
    final info = BattleFacade.getMoveSlotInfo(
      state: s,
      moveIndex: index,
      weather: widget.weather,
      terrain: widget.terrain,
      room: widget.room,
      opponentSpeed: widget.opponentSpeed,
      opponentAttack: widget.opponentAttack,
      opponentGender: widget.opponentGender ?? Gender.unset,
      myEffectiveSpeed: myEffectiveSpeed,
    );
    final effectiveType = info.effectiveType ?? move?.type;
    final effectiveCategory = info.effectiveCategory ?? move?.category;
    final displayName = info.displayName ?? move?.nameKo;
    final effectivePower = info.effectivePower;
    final result = info.offensivePower;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: MoveSelector(
              key: ValueKey('move_${index}_${widget.resetCounter}_${s.moves[index]?.name}_${s.dynamax}'),
              initialMoveName: s.moves[index]?.name,
              displayNameOverride: (displayName != null && displayName != move?.nameKo) ? displayName : null,
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

  Widget _genderIcon() {
    final g = s.gender;
    final rate = s.genderRate;
    final bool locked = rate == -1 || rate == 0 || rate == 8;

    String label;
    Color color;
    switch (g) {
      case Gender.male:
        label = '♂';
        color = Colors.blue;
        break;
      case Gender.female:
        label = '♀';
        color = Colors.pink;
        break;
      case Gender.genderless:
        label = '⚪';
        color = Colors.grey;
        break;
      case Gender.unset:
        label = '⚪';
        color = Colors.grey.shade400;
        break;
    }

    return GestureDetector(
      onTap: locked ? null : () {
        setState(() {
          // Cycle: unset -> male -> female -> unset
          switch (s.gender) {
            case Gender.unset:
              s.gender = Gender.male;
              break;
            case Gender.male:
              s.gender = Gender.female;
              break;
            case Gender.female:
              s.gender = Gender.unset;
              break;
            default:
              break;
          }
        });
        _notify();
      },
      child: Text(label, style: TextStyle(fontSize: 22, color: color)),
    );
  }

  Widget _dynamaxIcon() {
    if (!s.canDynamax) {
      return const SizedBox(width: 24);
    }

    String label;
    Color color;
    switch (s.dynamax) {
      case DynamaxState.none:
        label = '🔴';
        color = Colors.grey.shade400;
        break;
      case DynamaxState.dynamax:
        label = '🔴';
        color = Colors.red;
        break;
      case DynamaxState.gigantamax:
        label = '🔴';
        color = Colors.deepOrange;
        break;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          switch (s.dynamax) {
            case DynamaxState.none:
              s.dynamax = DynamaxState.dynamax;
              s.terastal = const TerastalState(); // 테라 해제
              break;
            case DynamaxState.dynamax:
              if (s.canGmax) {
                s.dynamax = DynamaxState.gigantamax;
              } else {
                s.dynamax = DynamaxState.none;
              }
              break;
            case DynamaxState.gigantamax:
              s.dynamax = DynamaxState.none;
              break;
          }
        });
        _notify();
      },
      child: SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: s.dynamax != DynamaxState.none
            ? Text(
                s.dynamax == DynamaxState.gigantamax ? 'G' : 'D',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade700),
              )
            : const Opacity(
                opacity: 0.3,
                child: Text('⬆', style: TextStyle(fontSize: 20)),
              ),
        ),
      ),
    );
  }

  /// Whether this Pokemon is a mega evolution (can't terastal)
  bool get _isMega => s.pokemonName.toLowerCase().startsWith('mega ');

  Widget _terastalIcon() {
    // Mega evolutions can't terastal
    if (_isMega) return const SizedBox(width: 24);

    final isActive = s.terastal.active;
    final teraType = s.terastal.teraType;

    // Type color mapping
    Color _typeColor(PokemonType? t) {
      if (t == null) return Colors.grey;
      const colors = {
        PokemonType.normal: Color(0xFFA8A878), PokemonType.fire: Color(0xFFF08030),
        PokemonType.water: Color(0xFF6890F0), PokemonType.electric: Color(0xFFF8D030),
        PokemonType.grass: Color(0xFF78C850), PokemonType.ice: Color(0xFF98D8D8),
        PokemonType.fighting: Color(0xFFC03028), PokemonType.poison: Color(0xFFA040A0),
        PokemonType.ground: Color(0xFFE0C068), PokemonType.flying: Color(0xFFA890F0),
        PokemonType.psychic: Color(0xFFF85888), PokemonType.bug: Color(0xFFA8B820),
        PokemonType.rock: Color(0xFFB8A038), PokemonType.ghost: Color(0xFF705898),
        PokemonType.dragon: Color(0xFF7038F8), PokemonType.dark: Color(0xFF705848),
        PokemonType.steel: Color(0xFFB8B8D0), PokemonType.fairy: Color(0xFFEE99AC),
        PokemonType.stellar: Color(0xFFE0C0FF),
      };
      return colors[t] ?? Colors.grey;
    }

    return GestureDetector(
      onTap: _showTeraTypePicker,
      child: SizedBox(
        width: 24,
        height: 24,
        child: isActive
          ? Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _typeColor(teraType),
              ),
              child: const Center(
                child: Text('T', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            )
          : const Center(
              child: Opacity(
                opacity: 0.3,
                child: Text('💎', style: TextStyle(fontSize: 20)),
              ),
            ),
      ),
    );
  }

  void _showTeraTypePicker() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('테라스탈 타입'),
        children: PokemonType.values.map((t) {
          final ko = KoStrings.typeKo[t];
          if (ko == null) return const SizedBox.shrink();
          return SimpleDialogOption(
            onPressed: () {
              setState(() {
                s.terastal = TerastalState(active: true, teraType: t);
                s.dynamax = DynamaxState.none;
              });
              _notify();
              Navigator.pop(ctx);
            },
            child: Text(ko),
          );
        }).toList()
          ..insert(0, SimpleDialogOption(
            onPressed: () {
              setState(() {
                s.terastal = const TerastalState();
              });
              _notify();
              Navigator.pop(ctx);
            },
            child: const Text('테라 안함', style: TextStyle(color: Colors.grey)),
          )),
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
