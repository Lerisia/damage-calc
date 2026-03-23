import 'dart:math' as _math;
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
import '../../data/pokedex.dart';
import '../../models/pokemon.dart';
import '../../utils/ability_effects.dart' show getAbilityTypeOverride;
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
  final double? opponentWeight;
  final VoidCallback? onSave;
  final VoidCallback? onLoad;
  final VoidCallback? onReset;

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
    this.opponentWeight,
    this.opponentGender,
    this.onSave,
    this.onLoad,
    this.onReset,
  });

  @override
  State<PokemonPanel> createState() => PokemonPanelState();
}

class PokemonPanelState extends State<PokemonPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _movesSectionKey = GlobalKey();
  final _statsSectionKey = GlobalKey();
  final _scrollController = ScrollController();
  final _screenshotController = ScreenshotController();
  int? _focusedMoveIndex;

  BattlePokemonState get s => widget.state;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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

  /// Propagate to parent — triggers full screen rebuild.
  /// Use only for changes that affect the OTHER panel (speed, pokemon switch, gender).
  void _notifyParent() {
    widget.onChanged();
  }

  /// Notify parent only if effective speed actually changed.
  /// For IV/EV/rank changes that usually don't affect speed.
  void _notifyIfSpeedChanged() {
    final newSpeed = BattleFacade.calcSpeed(
      state: s,
      weather: widget.weather,
      terrain: widget.terrain,
      room: widget.room,
    );
    if (newSpeed != _cachedSpeed) {
      _notifyParent();
    }
  }

  // Cached per build cycle — computed once in build(), used by all 4 move slots.
  int? _cachedSpeed;

  int? get myEffectiveSpeed => _cachedSpeed;

  void _updateCachedSpeed() {
    _cachedSpeed = widget.opponentSpeed == null
        ? null
        : BattleFacade.calcSpeed(
            state: s,
            weather: widget.weather,
            terrain: widget.terrain,
            room: widget.room,
          );
  }

  void _scrollToSection(GlobalKey key) {
    _doScrollToSection(key);
    // Retry after keyboard animation completes
    Future.delayed(const Duration(milliseconds: 500), () => _doScrollToSection(key));
  }

  void _scrollToMoves() => _scrollToSection(_movesSectionKey);
  void _scrollToStats() => _scrollToSection(_statsSectionKey);

  void _doScrollToSection(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null || !_scrollController.hasClients) return;

    final box = ctx.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero).dy;
    // Account for AppBar + TabBar + status bar
    final topBarHeight = kToolbarHeight + kTextTabBarHeight +
        MediaQuery.of(context).padding.top;
    final target = _scrollController.offset + offset - topBarHeight - 8;

    _scrollController.animateTo(
      target.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  /// Public accessor for 결정력 of a specific move slot (with multi-hit applied).
  int? computeResultFor(int moveIndex) {
    final singleHit = BattleFacade.calcOffensivePower(
      state: s,
      moveIndex: moveIndex,
      weather: widget.weather,
      terrain: widget.terrain,
      room: widget.room,
      opponentSpeed: widget.opponentSpeed,
      opponentAttack: widget.opponentAttack,
      opponentGender: widget.opponentGender ?? Gender.unset,
      myEffectiveSpeed: myEffectiveSpeed,
      opponentWeight: widget.opponentWeight,
    );
    return singleHit;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _updateCachedSpeed();
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(16, 8, 16,
          MediaQuery.of(context).viewInsets.bottom > 0
              ? MediaQuery.of(context).size.height * 0.5 + MediaQuery.of(context).viewInsets.bottom
              : 120),
      child: Screenshot(
        controller: _screenshotController,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Capture header (weather/terrain/room info)
              _captureHeader(),
              const SizedBox(height: 4),
          _sectionCard(
            title: '종',
            child: Row(children: [
            Expanded(child: PokemonSelector(
              key: ValueKey('pokemon_${widget.resetCounter}_${s.pokemonName}'),
              initialPokemonName: s.pokemonName,
              onSelected: (pokemon) {
                setState(() => s.applyPokemon(pokemon));
                _notifyParent();
              },
            )),
            const SizedBox(width: 4),
            ..._effectiveTypeBadges(),
            const SizedBox(width: 4),
            _genderIcon(),
            const SizedBox(width: 4),
            _dynamaxIcon(),
            const SizedBox(width: 4),
            _terastalIcon(),
          ]),),
          const SizedBox(height: 12),

          _sectionCard(
            key: _statsSectionKey,
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
              onLevelChanged: (v) => setState(() { s.level = v; _notifyParent(); }),
              onNatureChanged: (v) => setState(() { s.nature = v; _notifyParent(); }),
              onIvChanged: (v) => setState(() { s.iv = v; _notifyIfSpeedChanged(); }),
              onEvChanged: (v) => setState(() { s.ev = v; _notifyIfSpeedChanged(); }),
              onAbilityChanged: (v) => setState(() { s.selectedAbility = v; _notifyParent(); }),
              onItemChanged: (v) => setState(() { s.selectedItem = v; _notifyParent(); }),
              onRankChanged: (v) => setState(() { s.rank = v; _notifyIfSpeedChanged(); }),
              opponentSpeed: widget.opponentSpeed,
              opponentAlwaysLast: widget.opponentAlwaysLast,
              isDynamaxed: s.dynamax != DynamaxState.none,
              tailwind: s.tailwind,
              weather: widget.weather,
              terrain: widget.terrain,
              room: widget.room,
              onHpPercentChanged: (v) => setState(() { s.hpPercent = v; }),
              onStatusChanged: (v) => setState(() { s.status = v; _notifyParent(); }),
              onItemTap: _scrollToStats,
              onAbilityTap: _scrollToStats,
            ),
          ),
          const SizedBox(height: 12),

          _sectionCard(
            title: '기타 보정',
            child: Row(
              children: [
                Expanded(child: _compactCheck('순풍', s.tailwind, (v) {
                  setState(() { s.tailwind = v; _notifyParent(); });
                })),
                if (widget.isAttacker)
                  Expanded(child: _compactCheck('충전', s.charge, (v) {
                    setState(() { s.charge = v; });
                  }))
                else
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
      terrain: widget.terrain,
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

    if (parts.isEmpty && widget.onSave == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Row(
        children: [
          Expanded(child: Text(
            parts.join(' | '),
            style: TextStyle(
              fontSize: 12,
              color: widget.isAttacker ? Colors.red[400] : Colors.blue[400],
            ),
          )),
          if (widget.onSave != null)
            IconButton(
              icon: const Icon(Icons.save_outlined, size: 22),
              tooltip: '샘플 저장',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: widget.onSave,
            ),
          if (widget.onLoad != null)
            IconButton(
              icon: const Icon(Icons.folder_open_outlined, size: 22),
              tooltip: '샘플 불러오기',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: widget.onLoad,
            ),
          if (widget.onReset != null)
            IconButton(
              icon: const Icon(Icons.refresh, size: 22),
              tooltip: '초기화',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: widget.onReset,
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
      opponentWeight: widget.opponentWeight,
    );
    final effectiveType = info.effectiveType ?? move?.type;
    final effectiveCategory = info.effectiveCategory ?? move?.category;
    final displayName = info.displayName ?? move?.nameKo;
    // Power already includes multi-hit total from transformMove
    final displayPower = info.effectivePower;
    final result = info.offensivePower;

    final isSearching = _focusedMoveIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Focus(
              onFocusChange: (hasFocus) {
                setState(() => _focusedMoveIndex = hasFocus ? index : null);
              },
              child: Row(
                children: [
                  Expanded(
                    child: MoveSelector(
                      key: ValueKey('move_${index}_${widget.resetCounter}_${s.moves[index]?.name}_${s.dynamax}'),
                      initialMoveName: s.moves[index]?.name,
                      displayNameOverride: (displayName != null && displayName != move?.nameKo) ? displayName : null,
                      onTap: _scrollToMoves,
                      onSelected: (m) {
                        FocusScope.of(context).unfocus();
                        setState(() {
                          _focusedMoveIndex = null;
                          s.moves[index] = m;
                          s.typeOverrides[index] = null;
                          s.categoryOverrides[index] = null;
                          s.powerOverrides[index] = null;
                          s.hitOverrides[index] = null;
                          s.criticals[index] = m.hasTag(MoveTags.alwaysCrit);
                        });
                        _notifyParent();
                      },
                    ),
                  ),
                  if (!isSearching && move != null && move.isMultiHit && s.dynamax == DynamaxState.none)
                    PopupMenuButton<int>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      popUpAnimationStyle: AnimationStyle(duration: const Duration(milliseconds: 100)),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          '×${s.hitOverrides[index] ?? move.maxHits}',
                          style: TextStyle(
                            fontSize: 11,
                            color: s.hitOverrides[index] != null ? Colors.orange : Colors.grey[600],
                          ),
                        ),
                      ),
                      itemBuilder: (_) => [
                        for (int h = move.minHits; h <= move.maxHits; h++)
                          PopupMenuItem(
                            value: h,
                            height: 32,
                            child: Text('×$h', style: const TextStyle(fontSize: 13)),
                          ),
                      ],
                      onSelected: (h) { setState(() { s.hitOverrides[index] = h; }); _notifyParent(); },
                    ),
                ],
              ),
            ),
          ),
          if (!isSearching) SizedBox(
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
                    onSelected: (t) { setState(() { s.typeOverrides[index] = t; }); _notifyParent(); },
                  )
                : const Text('-', textAlign: TextAlign.center),
          ),
          if (!isSearching) SizedBox(
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
                    onSelected: (c) { setState(() { s.categoryOverrides[index] = c; }); _notifyParent(); },
                  )
                : const Text('-', textAlign: TextAlign.center),
          ),
          if (!isSearching) SizedBox(
            width: 44,
            child: move != null
                ? (move.hasTag(MoveTags.fixedLevel) || move.hasTag(MoveTags.fixedHalfHp) ||
                    move.hasTag(MoveTags.fixed20) || move.hasTag(MoveTags.fixed40))
                    ? const Text('고정', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey))
                    : move.isMultiHit
                    ? Text('$displayPower', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: Colors.grey[700]))
                    : SizedBox(
                        height: 28,
                        child: TextFormField(
                          key: ValueKey('power_${index}_${move.name}'),
                          initialValue: '$displayPower',
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
                              setState(() { s.powerOverrides[index] = parsed; });
                              _notifyParent();
                            }
                          },
                        ),
                      )
                : const Text('-', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
          ),
          if (!isSearching) SizedBox(
            width: 28,
            child: Checkbox(
              value: s.criticals[index],
              onChanged: (v) { setState(() { s.criticals[index] = v ?? false; }); _notifyParent(); },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          if (!isSearching) SizedBox(
            width: 60,
            child: Text(
              result != null
                  ? '$result'
                  : '-',
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
              child: Text(label, style: const TextStyle(fontSize: 14)),
            )),
          ],
        ),
      ),
    );
  }

  List<Widget> _effectiveTypeBadges() {
    final override = getAbilityTypeOverride(
      ability: s.selectedAbility,
      pokemonName: s.pokemonName,
      weather: widget.weather,
      terrain: widget.terrain,
      heldItem: s.selectedItem,
    );
    final type1 = override?.type1 ?? s.type1;
    final type2 = override != null ? override.type2 : s.type2;

    return [
      _typeBadge(type1),
      if (type2 != null) ...[
        const SizedBox(width: 2),
        _typeBadge(type2),
      ],
    ];
  }

  Widget _typeBadge(PokemonType type, {bool isTera = false}) {
    final color = KoStrings.getTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: isTera ? Border.all(color: Colors.white, width: 1.5) : null,
      ),
      child: Text(
        KoStrings.getTypeKo(type),
        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
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
        label = '♂'; color = Colors.blue;
      case Gender.female:
        label = '♀'; color = Colors.pink;
      case Gender.genderless:
        label = '-'; color = Colors.grey.shade500;
      case Gender.unset:
        label = '⚥'; color = Colors.purple.shade300;
    }

    return GestureDetector(
      onTap: locked ? null : () {
        setState(() {
          switch (s.gender) {
            case Gender.unset:
              s.gender = Gender.male;
            case Gender.male:
              s.gender = Gender.female;
            case Gender.female:
              s.gender = Gender.unset;
            default:
              break;
          }
        });
        _notifyParent();
      },
      child: SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(label, style: TextStyle(fontSize: 22, color: color, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _dynamaxIcon() {
    if (!s.canDynamax) {
      return const SizedBox(width: 24);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          switch (s.dynamax) {
            case DynamaxState.none:
              s.dynamax = DynamaxState.dynamax;
              s.terastal = const TerastalState();
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
        _notifyParent();
      },
      child: SizedBox(
        width: 26,
        height: 26,
        child: CustomPaint(
          painter: _DynamaxPainter(state: s.dynamax, isGmax: s.dynamax == DynamaxState.gigantamax),
        ),
      ),
    );
  }

  /// Whether this Pokemon is a mega evolution (can't terastal)
  bool get _isMega => s.pokemonName.toLowerCase().startsWith('mega ');

  bool get _isTerapagosTerastal => s.pokemonName == 'terapagos-terastal';
  bool get _isTerapagosStellar => s.pokemonName == 'terapagos-stellar';

  /// Switch between Terapagos forms, preserving all user settings.
  Future<void> _switchTerapagosForm(String targetFormName) async {
    final pokedex = await loadPokedex();
    final target = pokedex.firstWhere((p) => p.name == targetFormName);
    setState(() {
      s.pokemonName = target.name;
      s.pokemonNameKo = target.nameKo;
      s.type1 = target.type1;
      s.type2 = target.type2;
      s.weight = target.weight;
      s.baseStats = target.baseStats;
      s.pokemonAbilities = target.abilities;
      s.selectedAbility = target.abilities.isNotEmpty ? target.abilities.first : null;
    });
    _notifyParent();
  }

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
        width: 26,
        height: 26,
        child: CustomPaint(
          painter: _TerastalPainter(
            active: isActive,
            typeColor: isActive ? _typeColor(teraType) : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  void _showTeraTypePicker() {
    // Terapagos Terastal: only Stellar type, auto-switch to Stellar Form
    if (_isTerapagosTerastal) {
      setState(() {
        s.terastal = TerastalState(active: true, teraType: PokemonType.stellar);
        s.dynamax = DynamaxState.none;
      });
      _switchTerapagosForm('terapagos-stellar');
      return;
    }

    // Terapagos Stellar: toggle off → switch back to Terastal Form
    if (_isTerapagosStellar && s.terastal.active) {
      setState(() {
        s.terastal = const TerastalState();
      });
      _switchTerapagosForm('terapagos-terastal');
      return;
    }

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
              _notifyParent();
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
              _notifyParent();
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

/// Dynamax icon: circle with radiating energy cross.
/// Inactive: grey outline + faint arrow. Active: red/orange filled.
class _DynamaxPainter extends CustomPainter {
  final DynamaxState state;
  final bool isGmax;
  _DynamaxPainter({required this.state, required this.isGmax});

  /// Build the Dynamax X silhouette inspired by the original logo.
  /// Features: narrow upper prongs, center horn, thick lower prongs.
  Path _buildDmaxX(double s) {
    final path = Path();
    final cx = s / 2;
    final cy = s * 0.40;

    // Start from center-top horn tip
    path.moveTo(cx, s * 0.02);

    // Left side of center horn → top-left prong
    path.lineTo(cx - s * 0.06, cy - s * 0.06);
    path.lineTo(s * 0.05, s * 0.05);   // top-left tip
    path.lineTo(s * 0.15, s * 0.18);   // inner edge of top-left prong
    path.lineTo(cx - s * 0.10, cy + s * 0.02);

    // Down to bottom-left prong (thick, heavy)
    path.lineTo(s * -0.02, s * 0.98);  // bottom-left outer tip (wide)
    path.lineTo(s * 0.10, s * 0.90);
    path.lineTo(s * 0.14, s * 0.95);
    path.lineTo(s * 0.22, s * 0.85);
    path.lineTo(s * 0.26, s * 0.88);
    path.lineTo(s * 0.38, s * 0.68);   // inner edge
    path.lineTo(cx - s * 0.03, cy + s * 0.12);

    // Cross to right side
    path.lineTo(cx + s * 0.03, cy + s * 0.12);

    // Bottom-right prong (thick, heavy)
    path.lineTo(s * 0.62, s * 0.68);
    path.lineTo(s * 0.74, s * 0.88);
    path.lineTo(s * 0.78, s * 0.85);
    path.lineTo(s * 0.86, s * 0.95);
    path.lineTo(s * 0.90, s * 0.90);
    path.lineTo(s * 1.02, s * 0.98);   // bottom-right outer tip (wide)

    // Up to top-right prong
    path.lineTo(cx + s * 0.10, cy + s * 0.02);
    path.lineTo(s * 0.85, s * 0.18);
    path.lineTo(s * 0.95, s * 0.05);   // top-right tip
    path.lineTo(cx + s * 0.06, cy - s * 0.06);

    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final path = _buildDmaxX(s);

    if (state == DynamaxState.none) {
      canvas.drawPath(path, Paint()
        ..color = Colors.grey.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeJoin = StrokeJoin.round);
      return;
    }

    final baseColor = Colors.red.shade600;

    if (isGmax) {
      // Gigantamax: ominous multi-layered glow
      canvas.drawPath(path, Paint()
        ..color = Colors.red.shade200.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawPath(path, Paint()
        ..color = Colors.red.shade400.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawPath(path, Paint()
        ..color = baseColor
        ..style = PaintingStyle.fill);
      canvas.drawPath(path, Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8);
    } else {
      // Dynamax: simple solid fill
      canvas.drawPath(path, Paint()
        ..color = Colors.red.shade300.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      canvas.drawPath(path, Paint()
        ..color = baseColor
        ..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant _DynamaxPainter old) => old.state != state || old.isGmax != isGmax;
}

/// Terastal icon: hexagonal crystal with pointed vertices (star-hexagon).
/// Inactive: grey outline. Active: filled with type color + facet lines.
class _TerastalPainter extends CustomPainter {
  final bool active;
  final Color typeColor;
  _TerastalPainter({required this.active, required this.typeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2;
    final innerR = outerR * 0.65;

    // Star-hexagon: alternate between outer points and inner edges
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final outerA = i * _math.pi / 3 - _math.pi / 2;
      final innerA = outerA + _math.pi / 6;
      final ox = c.dx + outerR * _math.cos(outerA);
      final oy = c.dy + outerR * _math.sin(outerA);
      final ix = c.dx + innerR * _math.cos(innerA);
      final iy = c.dy + innerR * _math.sin(innerA);
      if (i == 0) { path.moveTo(ox, oy); } else { path.lineTo(ox, oy); }
      path.lineTo(ix, iy);
    }
    path.close();

    if (active) {
      canvas.drawPath(path, Paint()..color = typeColor..style = PaintingStyle.fill);
      canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 0.8);
      // Facet lines for crystal sparkle
      final fp = Paint()..color = Colors.white.withValues(alpha: 0.35)..style = PaintingStyle.stroke..strokeWidth = 0.6;
      for (int i = 0; i < 6; i++) {
        final a = i * _math.pi / 3 - _math.pi / 2;
        canvas.drawLine(c, Offset(c.dx + outerR * _math.cos(a), c.dy + outerR * _math.sin(a)), fp);
      }
    } else {
      canvas.drawPath(path, Paint()..color = Colors.grey.shade400..style = PaintingStyle.stroke..strokeWidth = 1.2);
    }
  }

  @override
  bool shouldRepaint(covariant _TerastalPainter old) => old.active != active || old.typeColor != typeColor;
}
