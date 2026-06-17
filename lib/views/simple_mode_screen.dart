import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/battle_pokemon.dart';
import '../models/move.dart';
import '../models/move_tags.dart';
import '../models/nature_profile.dart';
import '../models/pokemon.dart';
import '../models/room.dart';
import '../models/stats.dart';
import '../models/status.dart';
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
import 'widgets/offensive_power_breakdown.dart';
import 'widgets/move_selector.dart';
import 'widgets/pokemon_panel.dart' show DynamaxPainter, TerastalPainter;
import 'widgets/pokemon_selector.dart';
import 'widgets/pokemon_sprite.dart';
import 'widgets/type_picker_dialog.dart';
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
  final _defAtkSpCtl = TextEditingController(text: '0');
  final _defDefSpCtl = TextEditingController(text: '0');
  final _defSpdSpCtl = TextEditingController(text: '0');
  final _defSpeSpCtl = TextEditingController(text: '0');

  final _multCtl = TextEditingController(text: '1.0');

  // Per-controller focus nodes for the SP / multiplier fields. Lazy-
  // created via [_focusFor] so we don't hard-code one node per
  // controller; the listener selects the controller's full text on
  // focus gain so tapping a number readies the field for replacement
  // (typing a digit wipes the previous value instead of inserting
  // next to the caret).
  final Map<TextEditingController, FocusNode> _spFocusNodes = {};

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
    _defAtkSpCtl.text = '${ChampionsMode.evToSp(_def.ev.attack)}';
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
                      _defHpSpCtl, _defAtkSpCtl, _defDefSpCtl, _defSpdSpCtl, _defSpeSpCtl,
                      _multCtl, _atkAbilityCtl, _atkItemCtl,
                      _defAbilityCtl, _defItemCtl]) {
      c.dispose();
    }
    for (final f in [_atkAbilityFocus, _atkItemFocus,
                      _defAbilityFocus, _defItemFocus]) {
      f.dispose();
    }
    for (final f in _spFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  /// Returns a long-lived [FocusNode] for [c]. The node's listener
  /// selects [c]'s full text on focus gain (deferred to post-frame so
  /// the framework's own caret placement doesn't overwrite our
  /// selection) and, on focus loss, replaces an empty field with
  /// [emptyFallback] so deleting all digits doesn't leave the field
  /// visually blank — the underlying parser already falls back to 0
  /// for SP, but the display needs to mirror that.
  ///
  /// [emptyFallback] is null for the multiplier field (whose hint
  /// "1.0" already conveys the default visually).
  ///
  /// Lazy so we don't pre-allocate a node per controller — the
  /// multiplier and the 9 SP fields each get one on first use. The
  /// emptyFallback captured here must match every call site for [c],
  /// since putIfAbsent locks it in on the first invocation.
  FocusNode _focusFor(TextEditingController c, {String? emptyFallback}) {
    return _spFocusNodes.putIfAbsent(c, () {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!node.hasFocus) return;
            final text = c.text;
            if (text.isEmpty) return;
            c.selection =
                TextSelection(baseOffset: 0, extentOffset: text.length);
          });
          return;
        }
        if (emptyFallback != null && c.text.isEmpty) {
          c.text = emptyFallback;
        }
      });
      return node;
    });
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
      // applyPokemon already seeds curated defaults (ability, item,
      // nature, default moves, EV spread) and pins requiredItem for
      // mega forms. Don't overwrite selectedItem here — that wiped
      // out the curated top item (Black Glasses on Kingambit, etc.).
      _atk.applyPokemon(p);
      _rebuildSortedAbilitiesFor(attacker: true);
      // Re-pull every local controller from the freshly-applied state
      // — applyPokemon now also sets the EV spread, so the SP input
      // fields would otherwise keep showing the previous Pokémon's
      // numbers until the user touched them.
      _hydrateFromState();
    });
    widget.onChanged();
  }

  void _applyDefenderPokemon(Pokemon p) {
    setState(() {
      _def.applyPokemon(p);
      _rebuildSortedAbilitiesFor(attacker: false);
      _hydrateFromState();
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
        // Attack is normally unused on the defender, but Foul Play
        // (속임수) reads it. Plumbed through so the attacker-side
        // "공격(상대)" slot can edit it directly.
        attack: ChampionsMode.spToEv(_parseSp(_defAtkSpCtl)),
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

  /// Whether the defender slot should expose SpD (vs Def). Tracks
  /// [_effectiveIsSpecial] except that special moves tagged
  /// `target_phys_def` (Psyshock / Psystrike / Secret Sword) hit the
  /// physical Defense stat — so the defender's Def must be the editable
  /// slot even though the attacker still uses SpA.
  bool get _effectiveDefIsSpecial {
    final move = _atk.moves[0];
    if (move != null && move.hasTag(MoveTags.targetPhysDef)) return false;
    return _effectiveIsSpecial;
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
      // UnfocusDisposition.scope drops focus to the enclosing
      // FocusScope rather than bouncing it back to the previously-
      // focused child — without this, a tap on a non-focusable area
      // can snap focus onto an earlier field instead of releasing it.
      onTap: () => FocusManager.instance.primaryFocus
          ?.unfocus(disposition: UnfocusDisposition.scope),
      behavior: HitTestBehavior.translucent,
      child: Align(
        // Horizontally centered, vertically top-aligned: on tall
        // screens the layout should sit at the top, not drift to the
        // middle.
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            // Tighter bottom padding so the bottom nav (collapsed = 16
            // px strip; expanded = ~56 px) doesn't push the speed row
            // off-screen in simple mode. Outer 12-px padding kept for
            // top/horizontal so the card edges still breathe.
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _attackerCard(),
                // 3-px nudge between attacker and defender — small
                // enough to read as a single boundary zone, large
                // enough to visibly separate the red and blue rules.
                const SizedBox(height: 3),
                _defenderCard(),
                // Inter-card spacing dropped slightly (10→6, 8→4) to
                // reclaim vertical room for the bottom nav. The two
                // result blocks still read as visually grouped.
                const SizedBox(height: 6),
                _resultCard(),
                const SizedBox(height: 4),
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
    // Foul Play (속임수) reads the defender's Attack instead of the
    // attacker's. Re-bind the attacker's offensive slot to the
    // defender's controller / nature / rank so the user can edit
    // those values directly here without an extra row on the
    // defender card.
    final isFoulPlay = move?.hasTag(MoveTags.useOpponentAtk) ?? false;
    // Offensive slot follows the effective stat — Atk / SpA for normal
    // moves, Def when a `use_defense` move (Body Press) is picked.
    final offStat = isFoulPlay ? NatureStat.atk : _effectiveOffensiveStat;
    final offLabel = AppStrings.t(switch (offStat) {
      NatureStat.atk => 'stat.attack',
      NatureStat.spa => 'stat.spAttack',
      NatureStat.def => 'stat.defense',
      _ => 'stat.attack',
    });
    final offSubLabel = isFoulPlay ? AppStrings.t('label.foe') : null;
    final offCtl = isFoulPlay
        ? _defAtkSpCtl
        : switch (offStat) {
            NatureStat.atk => _atkAtkSpCtl,
            NatureStat.spa => _atkSpaSpCtl,
            NatureStat.def => _atkDefSpCtl,
            _ => _atkAtkSpCtl,
          };
    final offSync = isFoulPlay ? _syncDefEvs : _syncAtkEvs;

    return _card(
      accent: accent,
      title: AppStrings.t('tab.attacker'),
      saveLoadSide: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _speciesHeader(attacker: true),
          const SizedBox(height: 8),
          // Ability | Item | Burn check (attacker only — burn halves
          // physical Atk and is the most-toggled in-battle condition,
          // so it's the only status promoted to the main row here).
          Row(children: [
            Expanded(child: _abilityField(attacker: true)),
            const SizedBox(width: 8),
            Expanded(child: _itemField(attacker: true)),
            const SizedBox(width: 4),
            _burnCheck(),
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
                  // Simple Mode never surfaces status moves regardless
                  // of the global toggle — its layout has no slot for
                  // them and they'd just clutter the search.
                  allowStatus: false,
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
                  sublabel: offSubLabel,
                  stat: offStat,
                  spCtl: offCtl,
                  onSpChanged: offSync,
                  // Foul Play: nature-chip + rank-chip should also
                  // operate on the defender, since the defender's
                  // Attack is what's actually scaled.
                  attacker: !isFoulPlay,
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

  Widget _burnCheck() {
    final burn = _atk.status == StatusCondition.burn;
    return InkWell(
      onTap: () {
        setState(() {
          _atk.status = burn ? StatusCondition.none : StatusCondition.burn;
        });
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
                value: burn,
                onChanged: (v) {
                  setState(() {
                    _atk.status = (v ?? false)
                        ? StatusCondition.burn
                        : StatusCondition.none;
                  });
                  widget.onChanged();
                },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            Text(AppStrings.t('status.burn'),
                style: const TextStyle(fontSize: 13)),
          ],
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
    // same auto-switch as on the attacker side. Psyshock / Psystrike /
    // Secret Sword stay on Def even though they're special.
    final isSpecial = _effectiveDefIsSpecial;
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

  /// Damage range (as % of defender's max HP) for the currently
  /// selected attacking move. Returns null when no move is set or
  /// the move deals no damage (status / immunity). Same calculation
  /// path as the result panel; computing it twice per frame is fine
  /// — simple mode is not on a hot path.
  ({double minPct, double maxPct})? _defenderDamageRangePct() {
    final move = _atk.moves[0];
    if (move == null) return null;
    final defActualStats = StatCalculator.calculate(
      baseStats: _def.baseStats, iv: _def.iv, ev: _def.ev,
      nature: _def.nature, level: _def.level, rank: _def.rank);
    final atkEffSpeed = BattleFacade.calcSpeed(
      state: _atk, weather: widget.weather, terrain: widget.terrain, room: widget.room);
    final defEffSpeed = BattleFacade.calcSpeed(
      state: _def, weather: widget.weather, terrain: widget.terrain, room: widget.room);
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
    final result = _applyMultiplier(baseResult, _parseMultiplier());
    if (result.maxDamage == 0) return null;
    final defMaxHp = _defenderHp();
    if (defMaxHp <= 0) return null;
    return (
      minPct: result.minDamage / defMaxHp * 100,
      maxPct: result.maxDamage / defMaxHp * 100,
    );
  }

  Widget _hpPercentField() {
    final pct = _def.hpPercent;
    final dmg = _defenderDamageRangePct();
    // Tint the slider green → orange → red as HP drops, to match
    // what players see in-game at a glance. Above 100 % (e.g.
    // Dynamax HP doubling, Pollen Puff heals, residual mid-turn
    // damage estimates) we tint cyan to make it obvious the bar
    // is above the normal cap.
    final Color color = pct > 100
        ? Colors.cyan
        : pct >= 50
            ? Colors.green
            : pct >= 20
                ? Colors.orange
                : Colors.red;
    const sliderMax = 150;
    // Display whole percents as `94%` (no trailing `.0`); decimal
    // entries (e.g. 6.25 % for 1/16 chip damage) render with up to
    // two trailing digits, dropping a redundant trailing zero
    // (`6.5 %` not `6.50 %`).
    final pctText = pct == pct.roundToDouble()
        ? pct.toStringAsFixed(0)
        : (() {
            final s = pct.toStringAsFixed(2);
            return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
          })();
    // Visual marker for the 100 % anchor sits at this fraction of
    // the track. RoundSliderThumbShape radius (8) is the horizontal
    // padding the slider reserves on each side for the thumb.
    const thumbRadius = 8.0;
    const hundredFraction = 100 / sliderMax;
    // Damage-range overlay is painted inside the slider's track —
    // see [_DamageRangeTrackShape]. Painting it as part of the
    // track means (a) the thumb sits ON TOP of it (user direction:
    // 원 아래로 뜨게 해주세요 — the active-track region right under
    // the thumb stays its normal colour, only further-left damage
    // shows), and (b) the overlay is positioned RELATIVE TO the
    // thumb's interpolated centre, so during drag the red moves in
    // lockstep with the thumb instead of jittering one snap-point
    // behind (the previous Stack/Positioned approach computed
    // overlay positions from the snapped `pct` while the slider's
    // thumb visually interpolated between snaps — that's what felt
    // "기괴").
    final double minDmgFrac =
        dmg == null ? 0 : (dmg.minPct / sliderMax).clamp(0.0, 1.0);
    final double maxDmgFrac =
        dmg == null ? 0 : (dmg.maxPct / sliderMax).clamp(0.0, 1.0);
    final bool hasDmgOverlay = dmg != null && pct > 0 && dmg.maxPct > 0;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 28,
            child: LayoutBuilder(
              builder: (ctx, c) {
                final trackWidth = c.maxWidth - thumbRadius * 2;
                final markerLeft = thumbRadius + hundredFraction * trackWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: markerLeft - 1,
                      top: (c.maxHeight - 12) / 2,
                      child: IgnorePointer(
                        child: Container(
                          width: 2,
                          height: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        overlayShape: SliderComponentShape.noOverlay,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 8),
                        activeTrackColor: color,
                        inactiveTrackColor: color.withValues(alpha: 0.25),
                        thumbColor: color,
                        trackShape: hasDmgOverlay
                            ? _DamageRangeTrackShape(
                                minDmgFraction: minDmgFrac,
                                maxDmgFraction: maxDmgFrac,
                              )
                            : null,
                      ),
                      child: Slider(
                        value: pct.clamp(0, sliderMax).toDouble(),
                        min: 0,
                        max: sliderMax.toDouble(),
                        // 1 % steps — landing on a precise sub-percent
                        // value via the slider is too fiddly. For
                        // chip-damage fractions (1/16 = 6.25 %, …),
                        // the user taps the % label and types it.
                        divisions: sliderMax,
                        onChanged: (v) {
                          var rounded = v.round();
                          if ((rounded - 100).abs() <= 2) rounded = 100;
                          setState(
                              () => _def.hpPercent = rounded.toDouble());
                          widget.onChanged();
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        // Tappable % label — the slider can only do 1 % steps so
        // chip-damage fractions like 6.25 % go through this editor.
        // The pencil icon + outlined chip styling makes the tap
        // affordance obvious; without it users assumed the label
        // was a passive readout.
        InkWell(
          onTap: _editHpPercent,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$pctText%',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit,
                    size: 12,
                    color: Theme.of(context).colorScheme.outline),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Tap-to-edit dialog for fine HP control — the slider snaps to
  /// 1 % steps, so chip-damage fractions like 1/16 (6.25 %) need a
  /// keyboard entry path.
  Future<void> _editHpPercent() async {
    final controller = TextEditingController(
      text: _def.hpPercent == _def.hpPercent.roundToDouble()
          ? _def.hpPercent.toStringAsFixed(0)
          : _def.hpPercent.toStringAsFixed(2),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: TextField(
          controller: controller,
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(r'^\d{0,3}(\.\d{0,2})?')),
          ],
          decoration: const InputDecoration(
            suffixText: '%',
            isDense: true,
          ),
          onSubmitted: (text) {
            final v = double.tryParse(text);
            Navigator.pop(ctx, v?.clamp(0.0, 999.0));
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.t('action.cancel')),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text);
              Navigator.pop(ctx, v?.clamp(0.0, 999.0));
            },
            child: Text(AppStrings.t('action.confirm')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    setState(() => _def.hpPercent = result);
    widget.onChanged();
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
    /// Tiny qualifier line shown under the main label (e.g. "(상대)"
    /// for Foul Play, where the attacker-side "공격" slot actually
    /// edits the *defender*'s Attack stat).
    String? sublabel,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              if (sublabel != null)
                Text(sublabel,
                    style: TextStyle(fontSize: 9, color: Colors.grey[600])),
            ],
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 40, height: 30,
          child: TextField(
            controller: spCtl,
            focusNode: _focusFor(spCtl, emptyFallback: '0'),
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
      // Enter on the ability field auto-picks the first matching
      // ability (mirrors Extended Mode's behaviour). Saves a tap.
      onSubmittedPick: (text) {
        if (text.isEmpty) return null;
        final q = text.toLowerCase();
        final matches = sorted.where((a) =>
            a.toLowerCase().contains(q) ||
            (_abilityNames[a] ?? '').toLowerCase().contains(q));
        return matches.isNotEmpty ? matches.first : null;
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
      // Enter on the item field auto-picks the first matching item
      // (mirrors Extended Mode + the ability field above).
      onSubmittedPick: (text) {
        if (text.isEmpty) return null;
        final q = text.toLowerCase();
        final matches = allItems.where((k) =>
            k.toLowerCase().contains(q) ||
            (_itemNames[k] ?? '').toLowerCase().contains(q));
        return matches.isNotEmpty ? matches.first : null;
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
      focusNode: _focusFor(_multCtl),
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
      // Box-style sprite to the left of the name. Shows a neutral
      // placeholder until the sprite pack is available. Tap toggles
      // shiny — visual only, stored on the BattlePokemonState so
      // saves preserve it. Box icons themselves aren't shiny yet
      // (regular icon stays); the big sprite at the side panel
      // honours the flag once one is shown.
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => state.shiny = !state.shiny),
        child: PokemonSprite(
            pokemonName: state.pokemonName,
            size: 30,
            useBoxIcon: true,
            shiny: state.shiny),
      ),
      const SizedBox(width: 6),
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
    // Terastal collapses the chip stack to the single Tera type and
    // disables editing — defense uses only the Tera type, picker is
    // pointless until Tera is turned off.
    final teraActive = state.terastal.active && state.terastal.teraType != null;
    if (teraActive) {
      return [_typeChipBadge(state.terastal.teraType!, isTera: true)];
    }
    final override = getAbilityTypeOverride(
      ability: state.selectedAbility,
      pokemonName: state.pokemonName,
      weather: widget.weather,
      terrain: widget.terrain,
      heldItem: state.selectedItem,
    );
    final overridden = override != null;
    final type1 = override?.type1 ?? state.type1;
    final type2 = override != null ? override.type2 : state.type2;
    final type3 = override != null ? null : state.type3;
    final tap = overridden ? null : () => _openTypePicker(state);
    return [
      _typeChipBadge(type1, onTap: tap),
      if (type2 != null) ...[
        const SizedBox(width: 2),
        _typeChipBadge(type2, onTap: tap),
      ],
      if (type3 != null) ...[
        const SizedBox(width: 2),
        _typeChipBadge(type3, onTap: tap),
      ],
    ];
  }

  Future<void> _openTypePicker(BattlePokemonState state) async {
    final result = await showTypePickerDialog(
      context: context,
      currentType1: state.type1,
      currentType2: state.type2,
      currentType3: state.type3,
      pokemonName: state.pokemonName,
    );
    if (result == null || !mounted) return;
    setState(() {
      state.type1 = result.type1;
      state.type2 = result.type2;
      state.type3 = result.type3;
    });
    widget.onChanged();
  }

  Widget _typeChipBadge(PokemonType type, {bool isTera = false, VoidCallback? onTap}) {
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

    final offensiveNotes = <String>[];
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
      notesOut: offensiveNotes,
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

    final panel = DamageResultPanel(
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
      showRolls: false,
      // Reverse-calc affordance deferred to 1.10 — the dialog wiring
      // (above) is intentionally absent for the 1.9.x line. Module
      // and dialog code stay on main so re-enabling later is a
      // one-line change.
    );
    // Tap anywhere on the result block → 결정력 breakdown popup.
    // No affordance (per design) — discoverable via tap, doesn't
    // clutter the snappy result view.
    if (offensivePower == null) return panel;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showOffensivePowerBreakdown(
        context,
        power: offensivePower,
        moveDisplayName: result.move?.localizedName ?? '',
        notes: offensiveNotes,
        abilityNameMap: _abilityNames,
        itemNameMap: _itemNames,
      ),
      child: panel,
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

/// Slider track shape that paints the standard rounded active/
/// inactive tracks first, then overlays the defender damage-range
/// bands on top of the active track.
///
/// Two-tone overlay anchored to [thumbCenter] (the slider's
/// interpolated thumb position — NOT the snapped value) so the red
/// stays glued to the thumb during drags, no matter how the slider
/// interpolates between division snap points:
///   - dark red, width = minDmgFraction × trackWidth, ending at
///     thumbCenter — the defender loses AT LEAST this much in the
///     worst roll for them (smallest damage roll).
///   - light red, width = (maxDmg − minDmg)/sliderMax × trackWidth,
///     ending where the dark band starts — uncertain zone that may
///     or may not be lost depending on the roll.
///
/// Both bands clamp at the track's left edge so very large damages
/// (certain KO) collapse into a single dark band covering the full
/// active region. The slider's thumb paints AFTER this track paint
/// pass, so it visually sits on top of the overlay — user direction
/// was to keep the thumb visually unobstructed.
class _DamageRangeTrackShape extends RoundedRectSliderTrackShape {
  final double minDmgFraction;
  final double maxDmgFraction;

  const _DamageRangeTrackShape({
    required this.minDmgFraction,
    required this.maxDmgFraction,
  });

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
    required TextDirection textDirection,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
      textDirection: textDirection,
    );

    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final maxDmgPx = maxDmgFraction * trackRect.width;
    final minDmgPx = minDmgFraction * trackRect.width;

    final darkLeft = math.max(trackRect.left, thumbCenter.dx - minDmgPx);
    final darkRight = math.max(trackRect.left, thumbCenter.dx);
    if (darkRight > darkLeft) {
      context.canvas.drawRect(
        Rect.fromLTRB(darkLeft, trackRect.top, darkRight, trackRect.bottom),
        Paint()..color = const Color(0xFFC62828),
      );
    }

    final lightRight = darkLeft;
    final lightLeft = math.max(trackRect.left, thumbCenter.dx - maxDmgPx);
    if (lightRight > lightLeft) {
      context.canvas.drawRect(
        Rect.fromLTRB(lightLeft, trackRect.top, lightRight, trackRect.bottom),
        Paint()..color = const Color(0xFFEF9A9A),
      );
    }
  }
}
