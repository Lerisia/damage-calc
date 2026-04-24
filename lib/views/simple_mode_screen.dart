import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/battle_pokemon.dart';
import '../models/move.dart';
import '../models/move_tags.dart';
import '../models/nature_profile.dart';
import '../models/pokemon.dart';
import '../models/room.dart';
import '../models/stats.dart';
import '../models/terrain.dart';
import '../models/type.dart';
import '../models/weather.dart';
import '../utils/app_strings.dart';
import '../utils/aura_effects.dart';
import '../utils/battle_facade.dart';
import '../utils/champions_mode.dart';
import '../utils/stacking_moves.dart';
import '../utils/stat_calculator.dart';
import '../utils/damage_calculator.dart';
import '../utils/localization.dart';
import '../models/dynamax.dart';
import '../models/terastal.dart';
import '../utils/ability_effects.dart' show getAbilityTypeOverride;
import '../utils/ruin_effects.dart';
import 'widgets/damage_result_panel.dart';
import 'widgets/move_selector.dart';
import 'widgets/pokemon_panel.dart' show DynamaxPainter, TerastalPainter;
import 'widgets/pokemon_selector.dart';
import 'widgets/typeahead_helpers.dart';

/// Compact in-battle calculator. Shares the attacker/defender state
/// with Normal Mode — the user flip-flopping between the two sees the
/// same Pokemon, and every calc runs through the identical damage
/// pipeline. The only difference is the input surface.
class SimpleModeView extends StatefulWidget {
  final BattlePokemonState attacker;
  final BattlePokemonState defender;
  final Weather weather;
  final Terrain terrain;
  final RoomConditions room;
  final AuraToggles auras;
  final RuinToggles ruins;
  final int resetCounter;
  final VoidCallback onChanged;
  /// Localized ability/item name maps, owned and cached by the parent
  /// screen. Simple Mode reuses them as-is — no separate dex load.
  final Map<String, String> abilityNameMap;
  final Map<String, String> itemNameMap;
  /// Set of ability keys allowed in the picker (i.e. mainline only).
  /// Owned by the parent so Simple and Extended share the same
  /// filter; the full [abilityNameMap] still contains every ability
  /// for key→name lookups.
  final Set<String> pickableAbilities;
  /// Per-side "save current loadout" / "load saved loadout" / "reset"
  /// hooks — routed to the parent's [sample_storage]-backed flow so
  /// Simple Mode and Extended Mode share the same saved-sample list
  /// and the same reset behavior.
  /// side: 0 = attacker, 1 = defender.
  final ValueChanged<int> onSaveSide;
  final ValueChanged<int> onLoadSide;
  final ValueChanged<int> onResetSide;
  /// Open the Pokédex focused on the given species.
  /// side: 0 = attacker, 1 = defender.
  final ValueChanged<int>? onOpenDexForSide;

  const SimpleModeView({
    super.key,
    required this.attacker,
    required this.defender,
    required this.weather,
    required this.terrain,
    required this.room,
    required this.auras,
    required this.ruins,
    required this.resetCounter,
    required this.onChanged,
    required this.abilityNameMap,
    required this.itemNameMap,
    required this.pickableAbilities,
    required this.onSaveSide,
    required this.onLoadSide,
    required this.onResetSide,
    this.onOpenDexForSide,
  });

  @override
  State<SimpleModeView> createState() => _SimpleModeViewState();
}

/// Tri-state a nature chip can hold on a stat.
enum _NatureDir { neutral, up, down }

/// Accepts only 0-based integers up to [ChampionsMode.maxPerStat] (32).
/// Clamps down on the fly, so typing '65' becomes '32' without having
/// to wait for the onChanged handler to back-correct.
class _SpRangeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue newV) {
    if (newV.text.isEmpty) return newV;
    if (!RegExp(r'^\d+$').hasMatch(newV.text)) return old;
    final parsed = int.parse(newV.text);
    if (parsed > ChampionsMode.maxPerStat) {
      const clamped = '${ChampionsMode.maxPerStat}';
      return const TextEditingValue(
        text: clamped,
        selection: TextSelection.collapsed(offset: clamped.length),
      );
    }
    return newV;
  }
}

class _SimpleModeViewState extends State<SimpleModeView> {
  // Shared with Normal Mode — mutations are echoed to the parent via
  // [widget.onChanged] so weather/terrain auto-set and every other
  // normal-mode side-effect stays in sync.
  BattlePokemonState get _atk => widget.attacker;
  BattlePokemonState get _def => widget.defender;

  // Attacker SP controllers (offensive-stat slot + Speed). Defense is
  // included because Body Press (and similar "use_defense" moves) treat
  // Def as the offensive stat, so the attacker's offensive slot swaps
  // to this controller when such a move is selected.
  final _atkAtkSpCtl = TextEditingController(text: '0');
  final _atkDefSpCtl = TextEditingController(text: '0');
  final _atkSpaSpCtl = TextEditingController(text: '0');
  final _atkSpeSpCtl = TextEditingController(text: '0');

  // Defender SP controllers for HP / Def / SpDef / Spe.
  final _defHpSpCtl = TextEditingController(text: '0');
  final _defDefSpCtl = TextEditingController(text: '0');
  final _defSpdSpCtl = TextEditingController(text: '0');
  final _defSpeSpCtl = TextEditingController(text: '0');

  final _multCtl = TextEditingController(text: '1.0');

  // Parent-owned localized name maps (shared with Normal Mode — one
  // copy per screen, not per panel). Access via these getters instead
  // of re-reading the dex. Typeahead base lists and sorted ability
  // lists are cached separately and invalidated only on species/
  // language change.
  Map<String, String> get _abilityNames => widget.abilityNameMap;
  Map<String, String> get _itemNames => widget.itemNameMap;
  List<String> _itemKeys = const [];
  List<String> _atkSortedAbilities = const [];
  List<String> _defSortedAbilities = const [];
  final _atkAbilityCtl = TextEditingController();
  final _atkItemCtl = TextEditingController();
  final _defAbilityCtl = TextEditingController();
  final _defItemCtl = TextEditingController();
  final _atkAbilityFocus = FocusNode();
  final _atkItemFocus = FocusNode();
  final _defAbilityFocus = FocusNode();
  final _defItemFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _itemKeys = _itemNames.keys.toList();
    _rebuildSortedAbilitiesFor(attacker: true);
    _rebuildSortedAbilitiesFor(attacker: false);
    _hydrateFromState();
  }

  @override
  void didUpdateWidget(SimpleModeView old) {
    super.didUpdateWidget(old);
    // Parent may have swapped in a new name map (first async load, or
    // language change). Re-derive the derived caches in that case.
    final mapsChanged = old.abilityNameMap != widget.abilityNameMap ||
        old.itemNameMap != widget.itemNameMap;
    if (mapsChanged) {
      _itemKeys = _itemNames.keys.toList();
      _rebuildSortedAbilitiesFor(attacker: true);
      _rebuildSortedAbilitiesFor(attacker: false);
      _atkAbilityCtl.text = _abilityLabel(_atk.selectedAbility);
      _defAbilityCtl.text = _abilityLabel(_def.selectedAbility);
      _atkItemCtl.text = _itemDisplayText(_atk.selectedItem);
      _defItemCtl.text = _itemDisplayText(_def.selectedItem);
    }
    // Reset/language bump also re-hydrates per-side controllers.
    if (old.resetCounter != widget.resetCounter) {
      // Default unfocus tries to hand focus to the "previously
      // focused child", which on swap bounces it from the attacker's
      // ability typeahead straight into the defender's — triggering
      // its gained-focus listener (clears text, opens dropdown).
      // Using UnfocusDisposition.scope drops focus to the enclosing
      // FocusScope so no specific widget gets it.
      _atkAbilityFocus.unfocus(disposition: UnfocusDisposition.scope);
      _defAbilityFocus.unfocus(disposition: UnfocusDisposition.scope);
      _atkItemFocus.unfocus(disposition: UnfocusDisposition.scope);
      _defItemFocus.unfocus(disposition: UnfocusDisposition.scope);
      _rebuildSortedAbilitiesFor(attacker: true);
      _rebuildSortedAbilitiesFor(attacker: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _hydrateFromState();
        // Belt-and-suspenders: after hydrate, force-drop any focus
        // that might have snuck back in (TypeAhead's internal
        // controllers occasionally re-focus during the remount).
        FocusManager.instance.primaryFocus?.unfocus(
            disposition: UnfocusDisposition.scope);
      });
    }
  }

  void _rebuildSortedAbilitiesFor({required bool attacker}) {
    final state = attacker ? _atk : _def;
    final own = <String>[];
    for (final a in state.pokemonAbilities) {
      if (a == 'Supreme Overlord') {
        for (int i = 0; i <= 5; i++) {
          final key = 'Supreme Overlord $i';
          if (_abilityNames.containsKey(key)) own.add(key);
        }
      } else {
        own.add(a);
      }
    }
    // Pokemon's own abilities are always shown (they're legit
    // gameplay abilities). The rest-of-world list is filtered to
    // mainline-only so the Colosseum/spin-off placeholders don't
    // pollute the typeahead.
    final pickable = widget.pickableAbilities;
    final rest = _abilityNames.keys
        .where((a) => !own.contains(a) && pickable.contains(a))
        .toList()
      ..sort((a, b) => (_abilityNames[a] ?? a).compareTo(_abilityNames[b] ?? b));
    final combined = [...own, ...rest];
    if (attacker) {
      _atkSortedAbilities = combined;
    } else {
      _defSortedAbilities = combined;
    }
  }

  /// Pull local SP controllers, nature chip state, and ability/item
  /// labels from the shared [BattlePokemonState]s.
  void _hydrateFromState() {
    _atkAtkSpCtl.text = '${ChampionsMode.evToSp(_atk.ev.attack)}';
    _atkDefSpCtl.text = '${ChampionsMode.evToSp(_atk.ev.defense)}';
    _atkSpaSpCtl.text = '${ChampionsMode.evToSp(_atk.ev.spAttack)}';
    _atkSpeSpCtl.text = '${ChampionsMode.evToSp(_atk.ev.speed)}';
    _defHpSpCtl.text = '${ChampionsMode.evToSp(_def.ev.hp)}';
    _defDefSpCtl.text = '${ChampionsMode.evToSp(_def.ev.defense)}';
    _defSpdSpCtl.text = '${ChampionsMode.evToSp(_def.ev.spDefense)}';
    _defSpeSpCtl.text = '${ChampionsMode.evToSp(_def.ev.speed)}';
    _atkAbilityCtl.text = _abilityNames[_atk.selectedAbility ?? ''] ?? '';
    _defAbilityCtl.text = _abilityNames[_def.selectedAbility ?? ''] ?? '';
    _atkItemCtl.text = _itemDisplayText(_atk.selectedItem);
    _defItemCtl.text = _itemDisplayText(_def.selectedItem);
  }

  /// Display text for an item key — "없음" for null/empty, localized
  /// item name otherwise. Mirrors the normal-mode StatInput behavior
  /// so the empty state reads as "없음" rather than a blank field.
  String _itemDisplayText(String? key) {
    if (key == null || key.isEmpty) return AppStrings.t('label.none');
    return _itemNames[key] ?? key;
  }

  String _abilityLabel(String? key) {
    if (key == null || key.isEmpty) return '';
    return _abilityNames[key] ?? key;
  }


  @override
  void dispose() {
    for (final c in [_atkAtkSpCtl, _atkDefSpCtl, _atkSpaSpCtl, _atkSpeSpCtl,
                      _defHpSpCtl, _defDefSpCtl, _defSpdSpCtl, _defSpeSpCtl,
                      _multCtl, _atkAbilityCtl, _atkItemCtl,
                      _defAbilityCtl, _defItemCtl]) {
      c.dispose();
    }
    for (final f in [_atkAbilityFocus, _atkItemFocus,
                      _defAbilityFocus, _defItemFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  int _parseSp(TextEditingController c) {
    final v = int.tryParse(c.text) ?? 0;
    return v.clamp(0, ChampionsMode.maxPerStat);
  }

  double _parseMultiplier() {
    final v = double.tryParse(_multCtl.text);
    if (v == null || v.isNaN || v.isInfinite) return 1.0;
    return v.clamp(0.0, 100.0);
  }

  void _applyAttackerPokemon(Pokemon p) {
    setState(() {
      _atk.applyPokemon(p);
      // Simple Mode: item always defaults to 없음 on species change
      // unless the new species literally requires one (e.g. Giratina-O).
      _atk.selectedItem = p.requiredItem;
      _rebuildSortedAbilitiesFor(attacker: true);
      _atkAbilityCtl.text = _abilityNames[_atk.selectedAbility ?? ''] ?? '';
      _atkItemCtl.text = _itemDisplayText(_atk.selectedItem);
    });
    widget.onChanged();
  }

  void _applyDefenderPokemon(Pokemon p) {
    setState(() {
      _def.applyPokemon(p);
      _def.selectedItem = p.requiredItem;
      _rebuildSortedAbilitiesFor(attacker: false);
      _defAbilityCtl.text = _abilityNames[_def.selectedAbility ?? ''] ?? '';
      _defItemCtl.text = _itemDisplayText(_def.selectedItem);
    });
    widget.onChanged();
  }

  void _syncAtkEvs() {
    setState(() {
      _atk.ev = Stats(
        hp: 0,
        attack: ChampionsMode.spToEv(_parseSp(_atkAtkSpCtl)),
        defense: ChampionsMode.spToEv(_parseSp(_atkDefSpCtl)),
        spAttack: ChampionsMode.spToEv(_parseSp(_atkSpaSpCtl)),
        spDefense: 0,
        speed: ChampionsMode.spToEv(_parseSp(_atkSpeSpCtl)),
      );
    });
    widget.onChanged();
  }

  void _syncDefEvs() {
    setState(() {
      _def.ev = Stats(
        hp: ChampionsMode.spToEv(_parseSp(_defHpSpCtl)),
        attack: 0,
        defense: ChampionsMode.spToEv(_parseSp(_defDefSpCtl)),
        spAttack: 0,
        spDefense: ChampionsMode.spToEv(_parseSp(_defSpdSpCtl)),
        speed: ChampionsMode.spToEv(_parseSp(_defSpeSpCtl)),
      );
    });
    widget.onChanged();
  }

  /// Current direction of the nature chip for [s] on the given side.
  /// Reads directly from the shared [NatureProfile] on state so we
  /// never drift from the canonical value (and so ↓s loaded from
  /// Extended Mode render faithfully).
  _NatureDir _natureDir(NatureStat s, {required bool attacker}) {
    final profile = (attacker ? _atk : _def).nature;
    if (profile.up == s) return _NatureDir.up;
    if (profile.down == s) return _NatureDir.down;
    return _NatureDir.neutral;
  }

  /// Whether the attacker is currently treated as a special attacker
  /// for UI purposes. When a move is picked the move's category is
  /// authoritative; otherwise we pick the higher of base Atk / base
  /// SpA, with ability overrides for physical-forcing abilities
  /// (Huge Power / Pure Power / Tough Claws) pushing the default
  /// back to physical regardless of base stats.
  bool get _effectiveIsSpecial {
    final move = _atk.moves[0];
    if (move != null) return move.category == MoveCategory.special;
    final ability = _atk.selectedAbility;
    if (ability == 'Huge Power' ||
        ability == 'Pure Power' ||
        ability == 'Tough Claws') {
      return false;
    }
    return _atk.baseStats.spAttack > _atk.baseStats.attack;
  }

  /// Which stat drives the attacker's damage output. Normally Atk or
  /// SpA per [_effectiveIsSpecial]; swaps to Def for moves tagged
  /// `use_defense` (Body Press). The simple-mode offensive EV slot is
  /// bound to this stat so the user invests in the right place.
  NatureStat get _effectiveOffensiveStat {
    final move = _atk.moves[0];
    if (move != null && move.hasTag(MoveTags.useDefense)) {
      return NatureStat.def;
    }
    return _effectiveIsSpecial ? NatureStat.spa : NatureStat.atk;
  }

  /// Toggle a stat's nature chip between neutral and ↑ (no ↓ state in
  /// Simple Mode). Going up auto-fills the ↓ slot with the opposite so
  /// the applied Nature is a real one; going back to neutral clears
  /// both slots.
  void _cycleNature(NatureStat s, {required bool attacker}) {
    final current = _natureDir(s, attacker: attacker);
    setState(() {
      final state = attacker ? _atk : _def;
      // Each chip now only touches its own stat — no auto-pairing.
      // Neutral → ↑ on this stat. ↑ → neutral. ↓ (which can only
      // appear if loaded from Extended Mode) → neutral. Every other
      // stat's slot is preserved.
      if (current == _NatureDir.up) {
        state.nature = state.nature.copyWith(clearUp: true);
      } else if (current == _NatureDir.down) {
        state.nature = state.nature.copyWith(clearDown: true);
      } else {
        // Neutral tap — set this stat as ↑, leave ↓ slot alone.
        state.nature = state.nature.copyWith(up: s);
      }
    });
    widget.onChanged();
  }

  /// Read current rank stage for [s] on the given side. HP is
  /// rankless — always returns 0.
  int _rankStage(BattlePokemonState state, NatureStat s) {
    switch (s) {
      case NatureStat.atk: return state.rank.attack;
      case NatureStat.def: return state.rank.defense;
      case NatureStat.spa: return state.rank.spAttack;
      case NatureStat.spd: return state.rank.spDefense;
      case NatureStat.spe: return state.rank.speed;
    }
  }

  void _setRank(BattlePokemonState state, NatureStat s, int value) {
    setState(() {
      switch (s) {
        case NatureStat.atk:
          state.rank = state.rank.copyWith(attack: value); break;
        case NatureStat.def:
          state.rank = state.rank.copyWith(defense: value); break;
        case NatureStat.spa:
          state.rank = state.rank.copyWith(spAttack: value); break;
        case NatureStat.spd:
          state.rank = state.rank.copyWith(spDefense: value); break;
        case NatureStat.spe:
          state.rank = state.rank.copyWith(speed: value); break;
      }
    });
    widget.onChanged();
  }

  /// Compact rank chip: colorless "±" when at 0, colored `+N` / `-N`
  /// otherwise. Taps open a ±6 picker popup.
  Widget _rankChip(NatureStat stat, {required bool attacker}) {
    final state = attacker ? _atk : _def;
    final value = _rankStage(state, stat);
    final active = value != 0;
    // Neutral state shows a small language-specific label (ko 랭크,
    // en Rnk, ja 段階) so users don't have to tap to discover what
    // the chip controls. Active state keeps the larger numeric font.
    final String label;
    final double fontSize;
    if (!active) {
      label = AppStrings.t('simple.rankNeutral');
      fontSize = 11;
    } else {
      label = value > 0 ? '+$value' : '$value';
      fontSize = 12;
    }
    final Color neutralFg = Theme.of(context).colorScheme.onSurface;
    final Color activeFg = value > 0 ? Colors.red : Colors.blue;
    final Color fg = active ? activeFg : neutralFg;
    final s = _chipScale;
    return InkWell(
      onTap: () => _showRankPicker(state, stat),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 32 * s, height: 28 * s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? activeFg.withValues(alpha: 0.18) : null,
          border: Border.all(
            color: active ? activeFg : neutralFg.withValues(alpha: 0.7),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize * s, fontWeight: FontWeight.w700, color: fg,
          ),
        ),
      ),
    );
  }

  void _showRankPicker(BattlePokemonState state, NatureStat stat) {
    final current = _rankStage(state, stat);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              for (int v = 6; v >= -6; v--)
                InkWell(
                  onTap: () {
                    _setRank(state, stat, v);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 44, height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: v == current
                          ? (v > 0 ? Colors.red : v < 0 ? Colors.blue : Colors.grey)
                              .withValues(alpha: 0.25)
                          : null,
                      border: Border.all(
                        color: v == current
                            ? (v > 0 ? Colors.red : v < 0 ? Colors.blue : Colors.grey)
                            : Colors.grey.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      v > 0 ? '+$v' : '$v',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: v > 0
                            ? Colors.red
                            : v < 0
                                ? Colors.blue
                                : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Align(
        // Horizontally centered, vertically top-aligned: on tall
        // screens the layout should sit at the top, not drift to the
        // middle.
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _attackerCard(),
                // A 3px nudge between attacker and defender — small
                // enough to read as a single boundary zone, large
                // enough to visibly separate the red and blue rules.
                const SizedBox(height: 3),
                _defenderCard(),
                const SizedBox(height: 10),
                _resultCard(),
                const SizedBox(height: 8),
                _speedResultRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Attacker side
  // ────────────────────────────────────────────────────────────────────────

  Widget _attackerCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444);
    final move = _atk.moves[0];
    // Offensive slot follows the effective stat — Atk / SpA for normal
    // moves, Def when a `use_defense` move (Body Press) is picked.
    final offStat = _effectiveOffensiveStat;
    final offLabel = AppStrings.t(switch (offStat) {
      NatureStat.atk => 'stat.attack',
      NatureStat.spa => 'stat.spAttack',
      NatureStat.def => 'stat.defense',
      _ => 'stat.attack',
    });
    final offCtl = switch (offStat) {
      NatureStat.atk => _atkAtkSpCtl,
      NatureStat.spa => _atkSpaSpCtl,
      NatureStat.def => _atkDefSpCtl,
      _ => _atkAtkSpCtl,
    };

    return _card(
      accent: accent,
      title: AppStrings.t('tab.attacker'),
      saveLoadSide: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _speciesHeader(attacker: true),
          const SizedBox(height: 8),
          // Ability | Item
          Row(children: [
            Expanded(child: _abilityField(attacker: true)),
            const SizedBox(width: 8),
            Expanded(child: _itemField(attacker: true)),
          ]),
          const SizedBox(height: 6),
          // Move | Critical | × multiplier — sits above the stat row
          // so picking a special move (which flips the offensive stat
          // slot from Atk to SpA) doesn't blow away the user's
          // just-entered SP after the fact.
          Row(
            // Align to the bottom so the move-selector's underline
            // sits at the same Y as the multiplier field's underline
            // — the multiplier now has a floating label that makes
            // its total height taller, and with center alignment the
            // two underlines drifted apart by the label's height.
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: MoveSelector(
                  key: ValueKey('atk_move_${widget.resetCounter}_${move?.name ?? ""}'),
                  initialMoveName: move?.name,
                  pokemonName: _atk.pokemonName,
                  pokemonNameKo: _atk.pokemonNameKo,
                  dexNumber: _atk.dexNumber,
                  onSelected: (m) {
                    setState(() {
                      _atk.moves[0] = m;
                      // Drop any stale hit-count override so the new
                      // move starts at its own default (or collapses
                      // out entirely if it isn't multi-hit).
                      _atk.hitOverrides[0] = null;
                      // Stacking-power moves (Last Respects, Rage Fist)
                      // need a pre-set powerOverride so the calc
                      // matches the chip's default tier (e.g. Last
                      // Respects starts at ×3).
                      _atk.powerOverrides[0] = isStackingPower(m)
                          ? stackingPower(m, stackingDefaultTier(m))
                          : null;
                      // Mirror Extended Mode: moves tagged as always-
                      // crit (Frost Breath, Storm Throw, Wicked Blow,
                      // Surging Strikes, Zippy Zap, etc.) auto-tick
                      // the crit checkbox so the user doesn't have to
                      // remember per move.
                      _atk.criticals[0] = m.hasTag(MoveTags.alwaysCrit);
                    });
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 6),
              _hitCountChip(),
              SizedBox(width: 70, child: _multiplierField()),
              const SizedBox(width: 6),
              _criticalCheck(),
            ],
          ),
          // Reserve a fixed slot for move-info so picking a move doesn't
          // jerk the rest of the layout down. Info uses the transformed
          // move so Hidden Power / Tera Blast / Gyro Ball etc. show the
          // effective type/category/power rather than the raw defaults.
          const SizedBox(height: 4),
          SizedBox(
            height: 16,
            child: move != null
                ? _moveInfoRow(BattleFacade.getMoveSlotInfo(
                    state: _atk,
                    moveIndex: 0,
                    weather: widget.weather,
                    terrain: widget.terrain,
                    room: widget.room,
                    auras: widget.auras,
                    ruins: widget.ruins,
                    // Weight-based (Low Kick, Heavy Slam) and
                    // speed-based (Gyro Ball) moves need the full
                    // opponent context to compute effective power.
                    opponentSpeed: BattleFacade.calcSpeed(
                      state: _def, weather: widget.weather,
                      terrain: widget.terrain, room: widget.room),
                    myEffectiveSpeed: BattleFacade.calcSpeed(
                      state: _atk, weather: widget.weather,
                      terrain: widget.terrain, room: widget.room),
                    opponentWeight: BattleFacade.effectiveWeight(_def),
                    opponentAbility: _def.selectedAbility,
                    opponentItem: _def.selectedItem,
                    opponentHpPercent: _def.hpPercent,
                  ))
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 10),
          // Offensive stat (Atk↔SpA auto) + Speed share one row. Extra
          // vertical padding around the row enlarges the vertical tap
          // zone around each mini-button without growing the row
          // horizontally.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statGroup(
                  label: offLabel,
                  stat: offStat,
                  spCtl: offCtl,
                  onSpChanged: _syncAtkEvs,
                  attacker: true,
                ),
                _statGroup(
                  label: AppStrings.t('stat.speedShort'),
                  stat: NatureStat.spe,
                  spCtl: _atkSpeSpCtl,
                  onSpChanged: _syncAtkEvs,
                  attacker: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom-of-screen speed readout. No arrows — just "공격측이
  /// 방어측보다 n 빠름" style text so it reads clearly.
  Widget _speedResultRow() {
    final atkSpeed = BattleFacade.calcSpeed(
      state: _atk, weather: widget.weather, terrain: widget.terrain, room: widget.room);
    final defSpeed = BattleFacade.calcSpeed(
      state: _def, weather: widget.weather, terrain: widget.terrain, room: widget.room);
    final diff = (atkSpeed - defSpeed).abs();
    // Mirror match: fall back to 공격측/방어측 so the line isn't
    // ambiguous. Otherwise show the actual species names.
    final mirror = _atk.pokemonName == _def.pokemonName;
    String namedFasterBy(BattlePokemonState faster, BattlePokemonState slower) {
      final a = faster.localizedPokemonName;
      final b = slower.localizedPokemonName;
      return AppStrings.t('simple.namedFasterBy')
          .replaceAll('{a}', a)
          .replaceAll('{p}', AppStrings.koSubjectParticle(a))
          .replaceAll('{b}', b)
          .replaceAll('{n}', '$diff');
    }

    final String label;
    final Color color;
    if (atkSpeed > defSpeed) {
      label = mirror
          ? AppStrings.t('simple.atkFasterBy').replaceAll('{n}', '$diff')
          : namedFasterBy(_atk, _def);
      color = Colors.red;
    } else if (atkSpeed < defSpeed) {
      label = mirror
          ? AppStrings.t('simple.defFasterBy').replaceAll('{n}', '$diff')
          : namedFasterBy(_def, _atk);
      color = Colors.blue;
    } else {
      label = AppStrings.t('simple.tiedSpeed');
      color = Colors.grey;
    }
    return Center(
      child: Text(label, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: color,
      )),
    );
  }

  /// ×N chip — rendered for multi-hit moves AND stacking-power moves
  /// (Last Respects, Rage Fist). Multi-hit stores the tier in
  /// [BattlePokemonState.hitOverrides] (same semantics as Extended
  /// Mode); stacking moves store an absolute power in
  /// [BattlePokemonState.powerOverrides] so the calc picks up the
  /// boosted power without having to teach transformMove a new case.
  Widget _hitCountChip() {
    final move = _atk.moves[0];
    if (move == null) return const SizedBox.shrink();
    final stacking = isStackingPower(move);
    final multiHit = move.isMultiHit && move.minHits != move.maxHits;
    if (!stacking && !multiHit) return const SizedBox.shrink();
    final current = stacking
        ? currentStackingTier(move, _atk.powerOverrides[0])
        : (_atk.hitOverrides[0] ?? move.maxHits);
    final s = _chipScale;
    return Padding(
      padding: EdgeInsets.only(right: 4 * s),
      child: InkWell(
        onTap: () => _showHitCountPicker(move),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 4 * s),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '×$current',
            style: TextStyle(
                fontSize: 13 * s, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  void _showHitCountPicker(Move move) {
    final stacking = isStackingPower(move);
    final stackMaxVal = stackingMax(move);
    final (lo, hi) = stacking
        ? (1, stackMaxVal!)
        : (move.minHits, move.maxHits);
    final current = stacking
        ? currentStackingTier(move, _atk.powerOverrides[0])
        : (_atk.hitOverrides[0] ?? move.maxHits);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              for (int n = lo; n <= hi; n++)
                InkWell(
                  onTap: () {
                    setState(() {
                      if (stacking) {
                        _atk.powerOverrides[0] = stackingPower(move, n);
                      } else {
                        _atk.hitOverrides[0] = n;
                      }
                    });
                    widget.onChanged();
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 44, height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: n == current
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
                          : null,
                      border: Border.all(
                        color: n == current
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('×$n',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _criticalCheck() {
    final crit = _atk.criticals[0];
    return InkWell(
      onTap: () {
        setState(() => _atk.criticals[0] = !crit);
        widget.onChanged();
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20, height: 20,
              child: Checkbox(
                value: crit,
                onChanged: (v) {
                  setState(() => _atk.criticals[0] = v ?? false);
                  widget.onChanged();
                },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            Text(AppStrings.t('move.critical'),
                style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Defender side
  // ────────────────────────────────────────────────────────────────────────

  Widget _defenderCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
    // Attacker's move category drives which defensive stat is visible —
    // same auto-switch as on the attacker side. When no move is picked
    // yet, falls back to the attacker's base-stat / ability heuristic
    // so both sides agree on Atk-vs-SpA.
    final isSpecial = _effectiveIsSpecial;
    final defStat = isSpecial ? NatureStat.spd : NatureStat.def;
    final defLabel = AppStrings.t(isSpecial ? 'stat.spDefense' : 'stat.defense');
    final defCtl = isSpecial ? _defSpdSpCtl : _defDefSpCtl;

    return _card(
      accent: accent,
      title: AppStrings.t('tab.defender'),
      saveLoadSide: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _speciesHeader(attacker: false),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _abilityField(attacker: false)),
            const SizedBox(width: 8),
            Expanded(child: _itemField(attacker: false)),
          ]),
          const SizedBox(height: 14),
          // HP on its own row — label+SP+flip on the left, residual HP
          // slider fills the right since HP has no nature or rank.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                _statGroup(
                  label: AppStrings.t('stat.hp'),
                  stat: null,
                  spCtl: _defHpSpCtl,
                  onSpChanged: _syncDefEvs,
                  attacker: false,
                  canNature: false,
                ),
                const SizedBox(width: 10),
                Expanded(child: _hpPercentField()),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Def/SpD (auto by move) + Speed share one row.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statGroup(
                  label: defLabel,
                  stat: defStat,
                  spCtl: defCtl,
                  onSpChanged: _syncDefEvs,
                  attacker: false,
                ),
                _statGroup(
                  label: AppStrings.t('stat.speedShort'),
                  stat: NatureStat.spe,
                  spCtl: _defSpeSpCtl,
                  onSpChanged: _syncDefEvs,
                  attacker: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hpPercentField() {
    final pct = _def.hpPercent;
    // Tint the slider green → orange → red as HP drops, to match
    // what players see in-game at a glance.
    final Color color = pct >= 50
        ? Colors.green
        : pct >= 20
            ? Colors.orange
            : Colors.red;
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.25),
              thumbColor: color,
            ),
            child: Slider(
              value: pct.toDouble(),
              min: 0, max: 100, divisions: 100,
              onChanged: (v) {
                setState(() => _def.hpPercent = v.round());
                widget.onChanged();
              },
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Shared components
  // ────────────────────────────────────────────────────────────────────────

  Widget _card({
    required Color accent,
    required String title,
    required Widget child,
    int? saveLoadSide,
  }) {
    // iOS-style section: thin horizontal rule top and bottom, no left/
    // right borders or padding. Dividers pick up the side's accent
    // colour (공격측 red, 방어측 blue) so the section is instantly
    // identifiable and adjacent cards' lines read as a red→blue
    // transition at the boundary.
    final rule = Divider(
      height: 1,
      thickness: 1,
      color: accent.withValues(alpha: 0.6),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        rule,
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title,
                      style: TextStyle(
                          color: accent, fontWeight: FontWeight.w700)),
                  if (saveLoadSide != null) ...[
                    const Spacer(),
                    _titleActionBtn(
                      AppStrings.t('sample.save'),
                      () => widget.onSaveSide(saveLoadSide),
                    ),
                    _titleActionBtn(
                      AppStrings.t('sample.load'),
                      () => widget.onLoadSide(saveLoadSide),
                    ),
                    _titleActionBtn(
                      AppStrings.t('action.reset'),
                      () => widget.onResetSide(saveLoadSide),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              child,
            ],
          ),
        ),
        rule,
      ],
    );
  }

  Widget _titleActionBtn(String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }

  /// Compact single-stat widget — all five controls squeeze onto one
  /// line so a pair of stats fits in a single row: [label][SP][0][MAX]
  /// [무/↑/↓]. HP is natureless so [canNature] hides the cycle chip.
  Widget _statGroup({
    required String label,
    required NatureStat? stat,
    required TextEditingController spCtl,
    required VoidCallback onSpChanged,
    required bool attacker,
    bool canNature = true,
  }) {
    void setSp(String v) {
      spCtl.text = v;
      spCtl.selection = TextSelection.collapsed(offset: v.length);
      onSpChanged();
    }

    // Single flip button replaces the old 0/MAX pair — shows the
    // destination value, so tapping always moves the SP there. From
    // anywhere → 32, from 32 → 0.
    final isMaxed = (int.tryParse(spCtl.text) ?? 0) == ChampionsMode.maxPerStat;
    final flipLabel = isMaxed ? '0' : '${ChampionsMode.maxPerStat}';

    // Fixed label slot so every row's SP field starts at the same X.
    // Width varies per language because "특방" / "特防" / "SpD" have
    // noticeably different glyph widths at 13pt bold — a Korean-sized
    // slot clips the Japanese/English versions.
    final double labelSlot = switch (AppStrings.current) {
      AppLanguage.ko => 28,
      AppLanguage.en => 32,
      AppLanguage.ja => 30,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: labelSlot,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 40, height: 30,
          child: TextField(
            controller: spCtl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _SpRangeFormatter(),
            ],
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              isDense: true,
              isCollapsed: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
            onChanged: (_) => onSpChanged(),
          ),
        ),
        const SizedBox(width: 2),
        _miniBtn(flipLabel, () => setSp(flipLabel)),
        if (canNature && stat != null) ...[
          const SizedBox(width: 2),
          _natureCycleChip(stat, attacker: attacker),
        ],
        if (stat != null) ...[
          const SizedBox(width: 2),
          _rankChip(stat, attacker: attacker),
        ],
      ],
    );
  }

  /// Horizontal scale for the stat-row chips. Baseline 360px → 1.0×;
  /// narrow phones bottom out at 0.85× and larger phones / tablets
  /// grow up to 1.3× so the chips aren't lost in all that extra width.
  /// Used by _miniBtn, _natureCycleChip, _rankChip, and _hitCountChip
  /// for consistent sizing across the row.
  double get _chipScale =>
      (MediaQuery.sizeOf(context).width / 360).clamp(0.85, 1.3);

  Widget _miniBtn(String label, VoidCallback onTap) {
    // Fixed width sized for the widest label we ever show ("32") so
    // toggling 0 ↔ 32 doesn't shove neighbouring widgets sideways.
    final fg = Theme.of(context).colorScheme.onSurface;
    final s = _chipScale;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 30 * s, height: 28 * s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: fg.withValues(alpha: 0.7)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12 * s, fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }

  Widget _natureCycleChip(NatureStat stat, {required bool attacker}) {
    final dir = _natureDir(stat, attacker: attacker);
    final Color neutralFg = Theme.of(context).colorScheme.onSurface;
    // Neutral state shows a small language-specific label (ko 성격,
    // en Nat, ja 性格). Active state keeps the larger ↑ / ↓ arrow.
    final (label, color, fontSize) = switch (dir) {
      _NatureDir.neutral =>
          (AppStrings.t('simple.natureNeutral'), neutralFg, 11.0),
      _NatureDir.up => ('↑', Colors.red, 14.0),
      _NatureDir.down => ('↓', Colors.blue, 14.0),
    };
    final isActive = dir != _NatureDir.neutral;
    final s = _chipScale;
    return InkWell(
      onTap: () => _cycleNature(stat, attacker: attacker),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 30 * s, height: 28 * s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.18) : null,
          border: Border.all(
            color: isActive ? color : neutralFg.withValues(alpha: 0.7),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize * s, fontWeight: FontWeight.w700, color: color,
          ),
        ),
      ),
    );
  }

  Widget _abilityField({required bool attacker}) {
    final controller = attacker ? _atkAbilityCtl : _defAbilityCtl;
    final focus = attacker ? _atkAbilityFocus : _defAbilityFocus;
    final state = attacker ? _atk : _def;
    // Pokemon's own abilities float to the top, full catalog below —
    // same ordering Normal Mode uses. Precomputed cache; rebuilt only
    // on species/language change.
    final sorted = attacker ? _atkSortedAbilities : _defSortedAbilities;
    // Own ability keys (including Supreme Overlord's numbered variants)
    // — used to gray out entries that don't legitimately belong to this
    // pokemon, same visual language as non-learnable moves.
    final ownSet = <String>{
      for (final a in state.pokemonAbilities)
        if (a == 'Supreme Overlord')
          for (int i = 0; i <= 5; i++) 'Supreme Overlord $i'
        else
          a,
    };

    // Key ties TypeAhead instance to resetCounter so any swap/reset
    // tears down the widget (dropping its internal SuggestionsController
    // state) and rebuilds it fresh — no leftover "dropdown open"
    // state across the transition.
    return KeyedSubtree(
      key: ValueKey('atk_${attacker}_ability_${widget.resetCounter}'),
      child: buildTypeAhead<String>(
      controller: controller,
      focusNode: focus,
      suggestionsCallback: (query) {
        if (query.isEmpty) return sorted;
        final q = query.toLowerCase();
        return sorted
            .where((a) =>
                a.toLowerCase().contains(q) ||
                (_abilityNames[a] ?? '').toLowerCase().contains(q))
            .toList();
      },
      decoration: InputDecoration(
        labelText: AppStrings.t('label.ability'),
        isDense: true,
      ),
      itemBuilder: (context, ability) {
        final isOwn = ownSet.contains(ability);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            _abilityNames[ability] ?? ability,
            style: TextStyle(
              fontSize: 14,
              color: isOwn ? null : Colors.grey,
            ),
          ),
        );
      },
      onSelected: (v) {
        setState(() {
          if (attacker) {
            _atk.selectedAbility = v;
          } else {
            _def.selectedAbility = v;
          }
          final text = _abilityNames[v] ?? v;
          controller.text = text;
          // Collapse the selection — without this, TypeAhead re-selects
          // the whole field after picking, making the field look stuck
          // in "select all" mode.
          controller.selection = TextSelection.collapsed(offset: text.length);
          focus.unfocus();
        });
        widget.onChanged();
      },
    ),
    );
  }

  Widget _itemField({required bool attacker}) {
    final controller = attacker ? _atkItemCtl : _defItemCtl;
    final focus = attacker ? _atkItemFocus : _defItemFocus;
    final allItems = _itemKeys;

    return KeyedSubtree(
      key: ValueKey('atk_${attacker}_item_${widget.resetCounter}'),
      child: buildTypeAhead<String>(
      controller: controller,
      focusNode: focus,
      suggestionsCallback: (query) {
        if (query.isEmpty) return ['', ...allItems];
        final q = query.toLowerCase();
        return allItems.where((k) =>
            k.toLowerCase().contains(q) ||
            (_itemNames[k] ?? '').toLowerCase().contains(q)).toList();
      },
      decoration: InputDecoration(
        labelText: AppStrings.t('label.item'),
        isDense: true,
      ),
      itemBuilder: (context, key) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          key.isEmpty
              ? AppStrings.t('label.none')
              : (_itemNames[key] ?? key),
          style: const TextStyle(fontSize: 14),
        ),
      ),
      onSelected: (v) {
        setState(() {
          final effective = v.isEmpty ? null : v;
          if (attacker) {
            _atk.selectedItem = effective;
          } else {
            _def.selectedItem = effective;
          }
          final text = _itemDisplayText(effective);
          controller.text = text;
          controller.selection = TextSelection.collapsed(offset: text.length);
          focus.unfocus();
        });
        widget.onChanged();
      },
    ),
    );
  }

  Widget _multiplierField() {
    // Persistent '×' prefix so the field always reads as a multiplier,
    // even before anything's typed. Floating labelText mirrors the
    // ability/item field styling so the field is self-describing.
    return TextField(
      controller: _multCtl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: AppStrings.t('label.otherModifier'),
        labelStyle: const TextStyle(fontSize: 12),
        prefixText: '× ',
        prefixStyle: const TextStyle(fontSize: 14),
        hintText: '1.0',
        hintStyle: const TextStyle(fontSize: 14),
        isDense: true,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _moveInfoRow(MoveSlotInfo slot) {
    final type = slot.effectiveType;
    final category = slot.effectiveCategory;
    final typeName = type != null ? KoStrings.getTypeName(type) : '—';
    final categoryName = category == MoveCategory.physical
        ? AppStrings.t('damage.physical')
        : category == MoveCategory.special
            ? AppStrings.t('damage.special')
            : AppStrings.t('damage.moveNotSet');
    final power = slot.effectivePower > 0 ? '${slot.effectivePower}' : '—';
    final style = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
    );
    return Row(children: [
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: type != null ? _typeColor(type) : Colors.grey,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      Text('$typeName · $categoryName · $power', style: style),
    ]);
  }

  Color _typeColor(PokemonType t) => KoStrings.getTypeColor(t);

  /// Species row: PokemonSelector + effective type badges + Dynamax
  /// toggle + Terastal toggle. Mirrors the normal mode's header.
  Widget _speciesHeader({required bool attacker}) {
    final state = attacker ? _atk : _def;
    final onOpenDex = widget.onOpenDexForSide;
    return Row(children: [
      Expanded(
        child: PokemonSelector(
          // Key includes resetCounter + species name so the selector
          // rebuilds on reset and on language change (the parent
          // bumps resetCounter when the user switches languages),
          // picking up the newly-localized species label.
          key: ValueKey('${attacker ? "atk" : "def"}_species_'
              '${widget.resetCounter}_${state.pokemonName}'),
          initialPokemonName: state.pokemonName,
          onSelected: attacker ? _applyAttackerPokemon : _applyDefenderPokemon,
        ),
      ),
      if (onOpenDex != null) ...[
        const SizedBox(width: 2),
        IconButton(
          tooltip: AppStrings.t('dex.title'),
          icon: const Icon(Icons.menu_book_outlined, size: 20),
          onPressed: () => onOpenDex(attacker ? 0 : 1),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
      const SizedBox(width: 4),
      ..._effectiveTypeBadges(state),
      const SizedBox(width: 4),
      _dynamaxIcon(state),
      const SizedBox(width: 4),
      _terastalIcon(state),
    ]);
  }

  List<Widget> _effectiveTypeBadges(BattlePokemonState state) {
    final override = getAbilityTypeOverride(
      ability: state.selectedAbility,
      pokemonName: state.pokemonName,
      weather: widget.weather,
      terrain: widget.terrain,
      heldItem: state.selectedItem,
    );
    final type1 = override?.type1 ?? state.type1;
    final type2 = override != null ? override.type2 : state.type2;
    return [
      _typeChipBadge(type1),
      if (type2 != null) ...[
        const SizedBox(width: 2),
        _typeChipBadge(type2),
      ],
    ];
  }

  Widget _typeChipBadge(PokemonType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: KoStrings.getTypeColor(type),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        KoStrings.getTypeName(type),
        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _dynamaxIcon(BattlePokemonState state) {
    if (!state.canDynamax) return const SizedBox(width: 24);
    return GestureDetector(
      onTap: () => setState(() {
        switch (state.dynamax) {
          case DynamaxState.none:
            state.dynamax = DynamaxState.dynamax;
            state.terastal = const TerastalState();
            break;
          case DynamaxState.dynamax:
            state.dynamax = state.canGmax ? DynamaxState.gigantamax : DynamaxState.none;
            break;
          case DynamaxState.gigantamax:
            state.dynamax = DynamaxState.none;
            break;
        }
      }),
      child: SizedBox(
        width: 26, height: 26,
        child: CustomPaint(
          painter: DynamaxPainter(
            state: state.dynamax,
            isGmax: state.dynamax == DynamaxState.gigantamax,
          ),
        ),
      ),
    );
  }

  Widget _terastalIcon(BattlePokemonState state) {
    if (state.isMega) return const SizedBox(width: 24);
    final isActive = state.terastal.active;
    final teraType = state.terastal.teraType;
    return GestureDetector(
      onTap: () => _showTeraPicker(state),
      child: SizedBox(
        width: 26, height: 26,
        child: CustomPaint(
          painter: TerastalPainter(
            active: isActive,
            typeColor: isActive && teraType != null
                ? KoStrings.getTypeColor(teraType)
                : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  void _showTeraPicker(BattlePokemonState state) {
    // Compact type grid. Tapping a type toggles Terastal on; tapping
    // the currently-active type turns it off.
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              for (final t in PokemonType.values
                  .where((t) => t != PokemonType.typeless))
                InkWell(
                  onTap: () {
                    setState(() {
                      final already = state.terastal.active &&
                          state.terastal.teraType == t;
                      state.terastal = already
                          ? const TerastalState()
                          : TerastalState(active: true, teraType: t);
                      // Terastal and Dynamax are mutually exclusive.
                      if (!already) state.dynamax = DynamaxState.none;
                    });
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: KoStrings.getTypeColor(t),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      KoStrings.getTypeName(t),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Result
  // ────────────────────────────────────────────────────────────────────────

  Widget _resultCard() {
    final move = _atk.moves[0];
    if (move == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        child: Text(
          AppStrings.t('simple.noMove'),
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    final mult = _parseMultiplier();

    // Full opponent context — same inputs Normal Mode feeds the
    // calculators, so moves whose power scales with the opponent
    // (Gyro Ball, Low Kick, Heavy Slam, Foul Play, …) compute right.
    final defActualStats = StatCalculator.calculate(
      baseStats: _def.baseStats, iv: _def.iv, ev: _def.ev,
      nature: _def.nature, level: _def.level, rank: _def.rank);
    final atkEffSpeed = BattleFacade.calcSpeed(
      state: _atk, weather: widget.weather, terrain: widget.terrain, room: widget.room);
    final defEffSpeed = BattleFacade.calcSpeed(
      state: _def, weather: widget.weather, terrain: widget.terrain, room: widget.room);
    final defWeight = BattleFacade.effectiveWeight(_def);

    final baseResult = DamageCalculator.calculate(
      attacker: _atk,
      defender: _def,
      moveIndex: 0,
      weather: widget.weather,
      terrain: widget.terrain,
      room: widget.room,
      auras: widget.auras,
      ruins: widget.ruins,
      opponentAttack: defActualStats.attack,
      opponentSpeed: defEffSpeed,
      myEffectiveSpeed: atkEffSpeed,
      opponentGender: _def.gender,
    );
    // Apply extra multiplier by rescaling min/max; rebuilds a
    // DamageResult so the shared panel's KO / percent rendering stays
    // consistent with the scaled numbers.
    final result = _applyMultiplier(baseResult, mult);

    final rawOffensivePower = BattleFacade.calcOffensivePower(
      state: _atk,
      moveIndex: 0,
      weather: widget.weather,
      terrain: widget.terrain,
      room: widget.room,
      auras: widget.auras,
      ruins: widget.ruins,
      opponentSpeed: defEffSpeed,
      opponentAttack: defActualStats.attack,
      opponentGender: _def.gender,
      myEffectiveSpeed: atkEffSpeed,
      opponentWeight: defWeight,
      opponentHpPercent: _def.hpPercent,
      opponentItem: _def.selectedItem,
      opponentAbility: _def.selectedAbility,
    );
    // The extra multiplier scales the damage panel's rolls; do the
    // same to the displayed 결정력 so both numbers stay consistent
    // with the user's typed-in adjustment.
    final offensivePower =
        rawOffensivePower != null ? (rawOffensivePower * mult).round() : null;
    final bulk = BattleFacade.calcBulk(
      state: _def,
      weather: widget.weather,
      terrain: widget.terrain,
      room: widget.room,
      ruins: widget.ruins,
      opponentAbility: _atk.selectedAbility,
    );
    final defMaxHp = _defenderHp();
    final defCurrentHp = (defMaxHp * _def.hpPercent / 100).floor();

    return DamageResultPanel(
      attacker: _atk,
      defender: _def,
      result: result,
      offensivePower: offensivePower,
      physBulk: bulk.physical,
      specBulk: bulk.special,
      defCurrentHp: defCurrentHp,
      defMaxHp: defMaxHp,
      abilityNameMap: _abilityNames,
      itemNameMap: _itemNames,
      showHeader: false,
    );
  }

  DamageResult _applyMultiplier(DamageResult r, double mult) {
    if (mult == 1.0 || r.effectiveness == 0) return r;
    // Scale all rolls + endpoints. Percent and KO are re-derived by
    // DamageResult's own getters from the scaled fields, so no manual
    // recomputation needed — mirrors how the main damage calculator
    // builds its results.
    final scaledRolls = r.allRolls.map((v) => (v * mult).floor()).toList();
    return DamageResult(
      move: r.move,
      baseDamage: (r.baseDamage * mult).floor(),
      minDamage: (r.minDamage * mult).floor(),
      maxDamage: (r.maxDamage * mult).floor(),
      allRolls: scaledRolls,
      effectiveness: r.effectiveness,
      isPhysical: r.isPhysical,
      targetPhysDef: r.targetPhysDef,
      defenderHp: r.defenderHp,
      modifierNotes: [
        ...r.modifierNotes,
        'custom:×$mult',
      ],
    );
  }

  int _defenderHp() {
    final base = _def.baseStats.hp;
    final iv = _def.iv.hp;
    final ev = _def.ev.hp;
    final level = _def.level;
    return (((2 * base + iv + ev ~/ 4) * level) ~/ 100) + level + 10;
  }
}
