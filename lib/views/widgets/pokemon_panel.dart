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
import '../../utils/aura_effects.dart';
import '../../utils/battle_facade.dart';
import '../../utils/ruin_effects.dart';
import '../../utils/stacking_moves.dart';
import 'type_picker_dialog.dart';
import '../../utils/grounded.dart';
import '../../utils/app_strings.dart';
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
  final AuraToggles auras;
  final RuinToggles ruins;
  final String label;
  final VoidCallback onChanged;
  final int resetCounter;
  final bool isAttacker;
  final int? opponentSpeed;
  final bool opponentAlwaysLast;
  final int? opponentAttack;
  final int? opponentDefense;
  final int? opponentSpDefense;
  final Gender? opponentGender;
  final double? opponentWeight;
  final int? opponentHpPercent;
  final String? opponentItem;
  final String? opponentAbility;
  /// Shared expansion state for the Doubles-only options section, synced
  /// across attacker/defender panels.
  final bool doublesExpanded;
  final VoidCallback? onDoublesExpandToggle;
  final VoidCallback? onSave;
  final VoidCallback? onLoad;
  final VoidCallback? onReset;
  /// Tap target that opens the Pokédex focused on this Pokemon. The
  /// parent screen owns navigation so the panel doesn't need to know
  /// about routing.
  final VoidCallback? onOpenDex;
  final bool useSpMode;
  final ValueChanged<bool>? onSpModeChanged;

  const PokemonPanel({
    super.key,
    required this.state,
    required this.weather,
    required this.terrain,
    this.room = const RoomConditions(),
    this.auras = const AuraToggles(),
    this.ruins = const RuinToggles(),
    this.label = '',
    required this.onChanged,
    required this.resetCounter,
    this.isAttacker = true,
    this.opponentSpeed,
    this.opponentAlwaysLast = false,
    this.opponentAttack,
    this.opponentDefense,
    this.opponentSpDefense,
    this.opponentWeight,
    this.opponentHpPercent,
    this.opponentItem,
    this.opponentAbility,
    this.doublesExpanded = false,
    this.onDoublesExpandToggle,
    this.opponentGender,
    this.onSave,
    this.onLoad,
    this.onReset,
    this.onOpenDex,
    this.useSpMode = false,
    this.onSpModeChanged,
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
  final List<GlobalKey> _moveRowKeys = List.generate(4, (_) => GlobalKey());

  // Power input controllers — one per move slot.
  // Using controllers instead of initialValue + key avoids rebuilding
  // the TextFormField (and dismissing the keyboard) on every keystroke.
  final List<TextEditingController> _powerControllers =
      List.generate(4, (_) => TextEditingController());
  final List<int?> _lastDisplayPower = List.filled(4, null);
  BattlePokemonState get s => widget.state;


  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final c in _powerControllers) {
      c.dispose();
    }
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


  /// Public accessor for 결정력 of a specific move slot (with multi-hit applied).
  int? computeResultFor(int moveIndex) {
    final singleHit = BattleFacade.calcOffensivePower(
      state: s,
      moveIndex: moveIndex,
      weather: widget.weather,
      terrain: widget.terrain,
      room: widget.room,
      auras: widget.auras,
      ruins: widget.ruins,
      opponentSpeed: widget.opponentSpeed,
      opponentAttack: widget.opponentAttack,
      opponentGender: widget.opponentGender ?? Gender.unset,
      myEffectiveSpeed: myEffectiveSpeed,
      opponentWeight: widget.opponentWeight,
      opponentHpPercent: widget.opponentHpPercent,
      opponentAbility: widget.opponentAbility,
    );
    return singleHit;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _updateCachedSpeed();
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 200),
      child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Capture header (weather/terrain/room info)
              _captureHeader(),
              const SizedBox(height: 4),
          _sectionCard(
            title: AppStrings.t('section.species'),
            child: Row(children: [
            Expanded(child: PokemonSelector(
              key: ValueKey('pokemon_${widget.resetCounter}_${s.pokemonName}'),
              initialPokemonName: s.pokemonName,
              onSelected: (pokemon) {
                setState(() => s.applyPokemon(pokemon));
                _notifyParent();
              },
            )),
            if (widget.onOpenDex != null) ...[
              const SizedBox(width: 2),
              IconButton(
                tooltip: AppStrings.t('dex.title'),
                icon: const Icon(Icons.menu_book_outlined, size: 20),
                onPressed: widget.onOpenDex,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
            const SizedBox(width: 4),
            ..._effectiveTypeBadges(),
            const SizedBox(width: 4),
            _dynamaxIcon(),
            const SizedBox(width: 4),
            _terastalIcon(),
          ]),),
          const SizedBox(height: 12),

          _sectionCard(
            key: _statsSectionKey,
            title: AppStrings.t('section.stats'),
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
              onIvChanged: (v) => setState(() { s.iv = v; }),
              onEvChanged: (v) => setState(() { s.ev = v; }),
              onAbilityChanged: (v) => setState(() { s.selectedAbility = v; _notifyParent(); }),
              onItemChanged: (v) => setState(() { s.selectedItem = v; _notifyParent(); }),
              onRankChanged: (v) => setState(() { s.rank = v; _notifyParent(); }),
              onStatEditComplete: _notifyParent,
              opponentSpeed: widget.opponentSpeed,
              opponentAlwaysLast: widget.opponentAlwaysLast,
              isDynamaxed: s.dynamax != DynamaxState.none,
              tailwind: s.tailwind,
              weather: widget.weather,
              terrain: widget.terrain,
              room: widget.room,
              onHpPercentChanged: (v) => setState(() { s.hpPercent = v; _notifyParent(); }),
              onStatusChanged: (v) => setState(() { s.status = v; _notifyParent(); }),
              onItemTap: null,
              onAbilityTap: null,
              isAttacker: widget.isAttacker,
              useSpMode: widget.useSpMode,
              onSpModeChanged: widget.onSpModeChanged,
            ),
          ),
          const SizedBox(height: 12),

          // 기타 보정 (순풍/충전) - hidden for simplicity
          // _sectionCard(
          //   title: '기타 보정',
          //   child: Row(
          //     children: [
          //       Expanded(child: _compactCheck('순풍', s.tailwind, (v) {
          //         setState(() { s.tailwind = v; _notifyParent(); });
          //       })),
          //       if (widget.isAttacker)
          //         Expanded(child: _compactCheck('충전', s.charge, (v) {
          //           setState(() { s.charge = v; });
          //         }))
          //       else
          //         const Expanded(child: SizedBox()),
          //     ],
          //   ),
          // ),

          if (widget.isAttacker) ...[
            _sectionCard(
              key: _movesSectionKey,
              title: AppStrings.t('section.moves'),
              child: Column(
                children: [
                  _moveHeader(context),
                  const Divider(height: 1),
                  const SizedBox(height: 2),
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
          _doublesSection(),
        ],
      ),
    ),
    );
  }

  Widget _bulkDisplay() {
    final bulk = BattleFacade.calcBulk(
      state: s,
      weather: widget.weather,
      terrain: widget.terrain,
      room: widget.room,
      ruins: widget.ruins,
      opponentAbility: widget.opponentAbility,
    );

    return _sectionCard(
      title: AppStrings.t('section.bulk'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(AppStrings.t('section.physBulk'), style: TextStyle(
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
                Text(AppStrings.t('section.specBulk'), style: TextStyle(
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
    final label = widget.label;

    if (label.isEmpty && widget.onSave == null) return const SizedBox.shrink();

    final labelColor = widget.isAttacker ? Colors.red[400] : Colors.blue[400];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Row(
        children: [
          if (label.isNotEmpty)
            Expanded(child: Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: labelColor),
            ))
          else
            const Expanded(child: SizedBox()),
          if (widget.onSave != null)
            TextButton(
              onPressed: widget.onSave,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(AppStrings.t('sample.save'), style: const TextStyle(fontSize: 13)),
            ),
          if (widget.onLoad != null)
            TextButton(
              onPressed: widget.onLoad,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(AppStrings.t('sample.load'), style: const TextStyle(fontSize: 13)),
            ),
          if (widget.onReset != null)
            TextButton(
              onPressed: widget.onReset,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(AppStrings.t('action.reset'), style: const TextStyle(fontSize: 13)),
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
          Expanded(flex: 3, child: Text(AppStrings.t('move.name'), style: style)),
          SizedBox(width: 40, child: Text(AppStrings.t('move.type'), style: style, textAlign: TextAlign.center)),
          SizedBox(width: 32, child: Text(AppStrings.t('move.category'), style: style, textAlign: TextAlign.center)),
          SizedBox(width: 44, child: Text(AppStrings.t('move.power'), style: style, textAlign: TextAlign.center)),
          SizedBox(width: 28, child: Text(AppStrings.t('move.critical'), style: style, textAlign: TextAlign.center)),
          SizedBox(width: 28, child: Center(child: SizedBox(width: 14, height: 14, child: CustomPaint(painter: _ZLogoPainter(color: Theme.of(context).colorScheme.onSurface))))),
          SizedBox(width: 60, child: Text(AppStrings.t('move.offensive'), style: style, textAlign: TextAlign.right)),
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
      auras: widget.auras,
      ruins: widget.ruins,
      opponentSpeed: widget.opponentSpeed,
      opponentAttack: widget.opponentAttack,
      opponentDefense: widget.opponentDefense,
      opponentSpDefense: widget.opponentSpDefense,
      opponentGender: widget.opponentGender ?? Gender.unset,
      myEffectiveSpeed: myEffectiveSpeed,
      opponentWeight: widget.opponentWeight,
      opponentHpPercent: widget.opponentHpPercent,
      opponentItem: widget.opponentItem,
      opponentAbility: widget.opponentAbility,
      attackerGrounded: isGrounded(
        type1: s.type1, type2: s.type2, type3: s.type3,
        ability: s.selectedAbility, item: s.selectedItem,
        gravity: widget.room.gravity,
      ),
    );
    final effectiveType = info.effectiveType ?? move?.type;
    final effectiveCategory = info.effectiveCategory ?? move?.category;
    final displayName = info.displayName ?? move?.localizedName;
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
              key: _moveRowKeys[index],
              onFocusChange: (hasFocus) {
                setState(() => _focusedMoveIndex = hasFocus ? index : null);
              },
              child: Row(
                children: [
                  Expanded(
                    child: MoveSelector(
                      key: ValueKey('move_${index}_${widget.resetCounter}_${s.moves[index]?.name}_${s.dynamax}_${s.zMoves[index]}_${s.pokemonName}'),
                      initialMoveName: s.moves[index]?.name,
                      displayNameOverride: (displayName != null && displayName != move?.localizedName) ? displayName : null,
                      pokemonName: s.pokemonName,
                      pokemonNameKo: s.pokemonNameKo,
                      dexNumber: s.dexNumber,
                      onTap: null,
                      onSelected: (m) {
                        FocusScope.of(context).unfocus();
                        setState(() {
                          _focusedMoveIndex = null;
                          s.moves[index] = m;
                          s.typeOverrides[index] = null;
                          s.categoryOverrides[index] = null;
                          // Stacking-power moves: seed the default tier
                          // (Last Respects ×3, Rage Fist ×1) so the
                          // calc matches the chip's display on load.
                          s.powerOverrides[index] = isStackingPower(m)
                              ? stackingPower(m, stackingDefaultTier(m))
                              : null;
                          s.hitOverrides[index] = null;
                          s.criticals[index] = m.hasTag(MoveTags.alwaysCrit);
                        });
                        _notifyParent();
                      },
                    ),
                  ),
                  if (!isSearching && move != null &&
                      (info.isMultiHit || isStackingPower(move))) ...[
                    () {
                      final stacking = isStackingPower(move);
                      final stackMaxVal = stackingMax(move);
                      final (lo, hi) = stacking
                          ? (1, stackMaxVal!)
                          : (info.minHits, info.maxHits);
                      final current = stacking
                          ? currentStackingTier(move, s.powerOverrides[index])
                          : (s.hitOverrides[index] ?? info.maxHits);
                      final customized = stacking
                          ? current != stackingDefaultTier(move)
                          : s.hitOverrides[index] != null;
                      return GestureDetector(
                        onTap: (!stacking && info.minHits == info.maxHits)
                            ? null
                            : () async {
                                final h = await showDialog<int>(
                                  context: context,
                                  builder: (ctx) => SimpleDialog(
                                    children: [
                                      for (int h = lo; h <= hi; h++)
                                        SimpleDialogOption(
                                          onPressed: () => Navigator.pop(ctx, h),
                                          child: Text('×$h',
                                              style: const TextStyle(fontSize: 14)),
                                        ),
                                    ],
                                  ),
                                );
                                if (h != null) {
                                  setState(() {
                                    if (stacking) {
                                      s.powerOverrides[index] =
                                          stackingPower(move, h);
                                    } else {
                                      s.hitOverrides[index] = h;
                                    }
                                  });
                                  _notifyParent();
                                }
                              },
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Text(
                            '×$current',
                            style: TextStyle(
                              fontSize: 11,
                              color: customized
                                  ? Colors.orange
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      );
                    }(),
                  ],
                ],
              ),
            ),
          ),
          if (!isSearching) SizedBox(
            width: 40,
            child: move != null
                ? effectiveType != null
                  ? GestureDetector(
                      onTap: () async {
                        final t = await showDialog<PokemonType>(
                          context: context,
                          builder: (ctx) => SimpleDialog(
                            children: PokemonType.values.map((t) =>
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(ctx, t),
                                child: Text(KoStrings.getTypeName(t), style: const TextStyle(fontSize: 14)),
                              ),
                            ).toList(),
                          ),
                        );
                        if (t != null) { setState(() { s.typeOverrides[index] = t; }); _notifyParent(); }
                      },
                      child: Text(
                        KoStrings.getTypeName(effectiveType),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: s.typeOverrides[index] != null ? Colors.orange : null,
                        ),
                      ),
                    )
                  : Text('-', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey))
                : const Text('-', textAlign: TextAlign.center),
          ),
          if (!isSearching) SizedBox(
            width: 32,
            child: move != null
                ? GestureDetector(
                    onTap: () async {
                      final c = await showDialog<MoveCategory>(
                        context: context,
                        builder: (ctx) => SimpleDialog(
                          children: [MoveCategory.physical, MoveCategory.special].map((c) =>
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, c),
                              child: Text(KoStrings.getCategoryName(c), style: const TextStyle(fontSize: 14)),
                            ),
                          ).toList(),
                        ),
                      );
                      if (c != null) { setState(() { s.categoryOverrides[index] = c; }); _notifyParent(); }
                    },
                    child: Text(
                      KoStrings.getCategoryName(effectiveCategory!),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: s.categoryOverrides[index] != null ? Colors.orange : null,
                      ),
                    ),
                  )
                : const Text('-', textAlign: TextAlign.center),
          ),
          if (!isSearching) SizedBox(
            width: 44,
            child: move != null
                ? info.isFixedDamage
                    ? Text(AppStrings.t('move.fixed'), textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Colors.grey))
                    : move.isMultiHit
                    ? Text('$displayPower', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: Colors.grey[700]))
                    : _PowerInput(
                        key: ValueKey('power_${index}_${move.name}'),
                        displayPower: displayPower,
                        controller: _powerControllers[index],
                        lastDisplayPower: _lastDisplayPower,
                        slotIndex: index,
                        onPowerChanged: (parsed) {
                          setState(() { s.powerOverrides[index] = parsed; });
                        },
                        onPowerCleared: () {
                          setState(() { s.powerOverrides[index] = null; });
                          _notifyParent();
                        },
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
            width: 28,
            child: Checkbox(
              value: s.zMoves[index],
              onChanged: (_isMega || s.dynamax != DynamaxState.none || s.terastal.active)
                  ? null
                  : (v) { setState(() { s.zMoves[index] = v ?? false; }); _notifyParent(); },
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
    // Terastal overrides everything for defensive purposes — show a
    // single Tera-styled chip and lock editing while Tera is active.
    final teraActive = s.terastal.active && s.terastal.teraType != null;
    if (teraActive) {
      return [_typeBadge(s.terastal.teraType!, isTera: true)];
    }
    final override = getAbilityTypeOverride(
      ability: s.selectedAbility,
      pokemonName: s.pokemonName,
      weather: widget.weather,
      terrain: widget.terrain,
      heldItem: s.selectedItem,
    );
    // Ability-driven overrides (Multitype, RKS, Forecast …) win for
    // display purposes — chips are read-only when an ability is
    // forcing the type.
    final overridden = override != null;
    final type1 = override?.type1 ?? s.type1;
    final type2 = override != null ? override.type2 : s.type2;
    final type3 = override != null ? null : s.type3;

    final chips = [
      _typeBadge(type1, onTap: overridden ? null : _openTypePicker),
      if (type2 != null) ...[
        const SizedBox(width: 2),
        _typeBadge(type2, onTap: overridden ? null : _openTypePicker),
      ],
      if (type3 != null) ...[
        const SizedBox(width: 2),
        _typeBadge(type3, onTap: overridden ? null : _openTypePicker),
      ],
    ];
    return chips;
  }

  Future<void> _openTypePicker() async {
    final result = await showTypePickerDialog(
      context: context,
      currentType1: s.type1,
      currentType2: s.type2,
      currentType3: s.type3,
      pokemonName: s.pokemonName,
    );
    if (result == null || !mounted) return;
    setState(() {
      s.type1 = result.type1;
      s.type2 = result.type2;
      s.type3 = result.type3;
    });
    _notifyParent();
  }

  Widget _typeBadge(PokemonType type, {bool isTera = false, VoidCallback? onTap}) {
    final color = type == PokemonType.typeless
        ? Theme.of(context).colorScheme.outline
        : KoStrings.getTypeColor(type);
    final label = type == PokemonType.typeless
        ? AppStrings.t('type.none')
        : KoStrings.getTypeName(type);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: isTera ? Border.all(color: Colors.white, width: 1.5) : null,
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: chip,
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
              s.zMoves = [false, false, false, false];
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
          painter: DynamaxPainter(state: s.dynamax, isGmax: s.dynamax == DynamaxState.gigantamax),
        ),
      ),
    );
  }

  /// Whether this Pokemon is a mega evolution (can't terastal)
  bool get _isMega => s.isMega;

  bool get _isTerapagosTerastal => s.pokemonName == 'terapagos-terastal';
  bool get _isTerapagosStellar => s.pokemonName == 'terapagos-stellar';

  /// Switch between Terapagos forms, preserving all user settings.
  Future<void> _switchTerapagosForm(String targetFormName) async {
    final pokedex = await loadPokedex();
    final target = pokedex.firstWhere((p) => p.name == targetFormName);
    setState(() {
      s.pokemonName = target.name;
      s.pokemonNameKo = target.nameKo;
      s.pokemonNameJa = target.nameJa;
      s.pokemonNameEn = target.nameEn;
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
          painter: TerastalPainter(
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
        s.zMoves = [false, false, false, false];
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
        title: Text(AppStrings.t('label.terastal')),
        children: PokemonType.values.map((t) {
          final name = KoStrings.typeEn[t]; // use typeEn to check if valid type
          if (name == null) return const SizedBox.shrink();
          return SimpleDialogOption(
            onPressed: () {
              setState(() {
                s.terastal = TerastalState(active: true, teraType: t);
                s.dynamax = DynamaxState.none;
                s.zMoves = [false, false, false, false];
              });
              _notifyParent();
              Navigator.pop(ctx);
            },
            child: Text(KoStrings.getTypeName(t)),
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
            child: Text(AppStrings.t('label.noTera'), style: const TextStyle(color: Colors.grey)),
          )),
      ),
    );
  }

  /// Doubles-only attacker scenario toggles. Always shown (collapsed by
  /// default) — singles users simply leave it closed.
  Widget _doublesSection() {
    return _collapsibleSectionCard(
      title: AppStrings.t('section.doubles'),
      expanded: widget.doublesExpanded,
      onToggle: () => widget.onDoublesExpandToggle?.call(),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          _doublesCheck(AppStrings.t('damage.spread'), s.spreadTargets, (v) {
            setState(() { s.spreadTargets = v; _notifyParent(); });
          }),
          _doublesCheck(AppStrings.t('damage.helpingHand'), s.helpingHand, (v) {
            setState(() { s.helpingHand = v; _notifyParent(); });
          }),
          _doublesCheck(AppStrings.t('damage.allyPowerSpot'), s.allyPowerSpot, (v) {
            setState(() { s.allyPowerSpot = v; _notifyParent(); });
          }),
          _doublesCheck(AppStrings.t('damage.allyBattery'), s.allyBattery, (v) {
            setState(() { s.allyBattery = v; _notifyParent(); });
          }),
          _doublesCheck(AppStrings.t('damage.allyFlowerGift'), s.allyFlowerGift, (v) {
            setState(() { s.allyFlowerGift = v; _notifyParent(); });
          }),
          _doublesCheck(AppStrings.t('damage.allyPlusMinus'), s.allyPlusMinus, (v) {
            setState(() { s.allyPlusMinus = v; _notifyParent(); });
          }),
          _doublesCheck(AppStrings.t('damage.allyFriendGuard'), s.allyFriendGuard, (v) {
            setState(() { s.allyFriendGuard = v; _notifyParent(); });
          }),
          _doublesCheck(AppStrings.t('damage.tailwind'), s.tailwind, (v) {
            setState(() { s.tailwind = v; _notifyParent(); });
          }),
        ],
      ),
    );
  }

  /// True when a field-state ability (Aura / Aura Break / Ruin) is
  /// already active via either side's selected ability — the checkbox
  /// should be locked ON so the user never sees a contradictory "off".
  bool _abilityForced(String ability) =>
      s.selectedAbility == ability || widget.opponentAbility == ability;

  Widget _doublesCheck(String label, bool value, ValueChanged<bool> onChanged,
      {bool forced = false}) {
    final effectiveValue = forced || value;
    return InkWell(
      onTap: forced ? null : () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20, height: 20,
              child: Checkbox(
                value: effectiveValue,
                onChanged: forced ? null : (v) => onChanged(v ?? false),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  /// Variant of [_sectionCard] with a tappable title that expands or
  /// collapses [child]. Used for the Doubles-only options so it stays
  /// hidden by default.
  Widget _collapsibleSectionCard({
    Key? key,
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.isAttacker
        ? (isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444))
        : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6));

    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                  Icon(
                    expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    size: 18,
                    color: accent,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            child,
          ],
        ],
      ),
    );
  }

  Widget _sectionCard({Key? key, required String title, required Widget child}) {
    // Borderless, flat, separated by whitespace. Title uses the attacker/
    // defender accent color so users always know which side they're editing.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.isAttacker
        ? (isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444))
        : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6));

    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

}

/// Dynamax icon: circle with radiating energy cross.
/// Inactive: grey outline + faint arrow. Active: red/orange filled.
class DynamaxPainter extends CustomPainter {
  final DynamaxState state;
  final bool isGmax;
  DynamaxPainter({required this.state, required this.isGmax});

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
  bool shouldRepaint(covariant DynamaxPainter old) => old.state != state || old.isGmax != isGmax;
}

/// Terastal icon: hexagonal crystal with pointed vertices (star-hexagon).
/// Inactive: grey outline. Active: filled with type color + facet lines.
class TerastalPainter extends CustomPainter {
  final bool active;
  final Color typeColor;
  TerastalPainter({required this.active, required this.typeColor});

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
  bool shouldRepaint(covariant TerastalPainter old) => old.active != active || old.typeColor != typeColor;
}

/// Stateful widget for power input that safely handles controller updates.
/// Prevents crashes by deferring controller text updates to post-frame
/// callbacks and tracking focus to avoid overwriting user input.
class _PowerInput extends StatefulWidget {
  final int displayPower;
  final TextEditingController controller;
  final List<int?> lastDisplayPower;
  final int slotIndex;
  final ValueChanged<int> onPowerChanged;
  final VoidCallback? onPowerCleared;

  const _PowerInput({
    super.key,
    required this.displayPower,
    required this.controller,
    required this.lastDisplayPower,
    required this.slotIndex,
    required this.onPowerChanged,
    this.onPowerCleared,
  });

  @override
  State<_PowerInput> createState() => _PowerInputState();
}

class _PowerInputState extends State<_PowerInput> {
  final _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    // Always initialize controller text (widget is keyed by move name)
    widget.controller.text = '${widget.displayPower}';
    widget.lastDisplayPower[widget.slotIndex] = widget.displayPower;
  }

  void _onFocusChange() {
    _hasFocus = _focusNode.hasFocus;
    if (!_hasFocus && mounted) {
      // When losing focus, commit the value or reset to display power
      final text = widget.controller.text;
      final parsed = int.tryParse(text);
      if (parsed == null || parsed <= 0 || text.isEmpty) {
        // Clear override → display power reverts to move's base power
        widget.onPowerCleared?.call();
        // Update controller text after parent rebuilds with new displayPower
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.controller.text = '${widget.displayPower}';
            widget.lastDisplayPower[widget.slotIndex] = widget.displayPower;
          }
        });
      }
    }
  }

  @override
  void didUpdateWidget(_PowerInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update controller text when external power changes AND user is not typing
    if (!_hasFocus && oldWidget.displayPower != widget.displayPower) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasFocus) {
          widget.controller.text = '${widget.displayPower}';
          widget.lastDisplayPower[widget.slotIndex] = widget.displayPower;
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        ),
        onChanged: (text) {
          final parsed = int.tryParse(text);
          if (parsed != null && parsed > 0) {
            widget.lastDisplayPower[widget.slotIndex] = parsed;
            widget.onPowerChanged(parsed);
          } else if (text.isEmpty) {
            widget.onPowerCleared?.call();
          }
        },
      ),
    );
  }
}

/// Angular Z logo inspired by Z-Move crystal mark.
/// Sharp pointed Z with top stroke extending right and bottom stroke extending left.
class _ZLogoPainter extends CustomPainter {
  _ZLogoPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Angular Z: top bar pointed right, diagonal, bottom bar pointed left
    final path = Path()
      // Top bar (left edge to right point)
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.18)
      // Diagonal down-left
      ..lineTo(w * 0.28, h * 0.82)
      // Bottom bar (extends left with point)
      ..lineTo(w, h * 0.82)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(0, h * 0.82)
      // Diagonal up-right
      ..lineTo(w * 0.72, h * 0.18)
      ..lineTo(0, h * 0.18)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
