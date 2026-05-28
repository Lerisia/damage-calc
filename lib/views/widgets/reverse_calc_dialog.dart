import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/battle_pokemon.dart';
import '../../models/move.dart';
import '../../models/nature_profile.dart';
import '../../models/room.dart';
import '../../models/stats.dart';
import '../../models/terrain.dart';
import '../../models/weather.dart';
import '../../utils/app_strings.dart';
import '../../utils/aura_effects.dart';
import '../../utils/champions_mode.dart';
import '../../utils/reverse_calc.dart';
import '../../utils/ruin_effects.dart';
import 'stat_input.dart';

/// "역산" dialog — user types the damage they actually took, we run
/// [ReverseCalc.run] against the current calc state and show the
/// (Atk/SpA EV, nature) candidates that could have produced it.
///
/// Defender = `defender` arg (the user's own pokemon in the calc).
/// Attacker = `attacker` arg, with `moveIndex` already set on the
/// move the user observed. Item / ability / rank / tera / etc.
/// come straight from `attacker`; the dialog only varies the
/// offensive EV and nature.
///
/// `onApply` is invoked when the user taps a candidate row — the
/// caller installs the chosen (EV, nature) onto its attacker state
/// and closes the dialog. Without it, the rows are read-only.
class ReverseCalcDialog extends StatefulWidget {
  final BattlePokemonState attacker;
  final BattlePokemonState defender;
  final int moveIndex;
  final Weather weather;
  final Terrain terrain;
  final RoomConditions room;
  final AuraToggles auras;
  final RuinToggles ruins;
  final ValueChanged<ReverseCalcCandidate>? onApply;

  const ReverseCalcDialog({
    super.key,
    required this.attacker,
    required this.defender,
    required this.moveIndex,
    required this.weather,
    required this.terrain,
    required this.room,
    required this.auras,
    required this.ruins,
    this.onApply,
  });

  @override
  State<ReverseCalcDialog> createState() => _ReverseCalcDialogState();
}

class _ReverseCalcDialogState extends State<ReverseCalcDialog> {
  // The dialog accepts the damage observation either as a direct
  // HP number or — more conveniently — as "HP before" / "HP after"
  // values the user reads off their pokemon. Editing before/after
  // auto-syncs the damage field; editing the damage field is also
  // allowed (manual override). SelectAllField owns its own
  // controllers; these mirrors are updated on every onChanged so
  // _run / _syncDamage can read without reaching into the widgets.
  String _beforeText = '';
  String _afterText = '';
  String _damageText = '';
  ReverseCalcResult? _result;
  bool _searched = false;

  void _unfocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _onBeforeChanged(String v) {
    _beforeText = v;
    _syncDamageFromHp();
  }

  void _onAfterChanged(String v) {
    _afterText = v;
    _syncDamageFromHp();
  }

  void _onDamageChanged(String v) {
    // Direct edit on the damage field — leave the HP-before/after
    // fields alone. User now has the value they want directly.
    _damageText = v;
  }

  void _syncDamageFromHp() {
    final b = int.tryParse(_beforeText);
    final a = int.tryParse(_afterText);
    if (b == null || a == null) return;
    final d = b - a;
    if (d < 0) return;
    // SelectAllField.didUpdateWidget syncs the controller text
    // from initialText when the field isn't focused. Damage field
    // is not focused while user is typing in HP fields, so this
    // propagates correctly without clobbering the active field.
    setState(() => _damageText = '$d');
  }

  void _run() {
    // Dropping focus on submit lets the IME collapse — otherwise
    // the keyboard sits over the result list and the user has to
    // tap outside to see anything.
    _unfocus();
    final raw = int.tryParse(_damageText);
    if (raw == null || raw <= 0) {
      setState(() {
        _result = null;
        _searched = true;
      });
      return;
    }
    final result = ReverseCalc.run(
      defender: widget.defender,
      attackerTemplate: widget.attacker,
      moveIndex: widget.moveIndex,
      // Single observation: candidate matches if its computed range
      // includes the typed value (min ≤ raw ≤ max).
      observedMin: raw,
      observedMax: raw,
      weather: widget.weather,
      terrain: widget.terrain,
      room: widget.room,
      auras: widget.auras,
      ruins: widget.ruins,
    );
    setState(() {
      _result = result;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final move = widget.attacker.moves[widget.moveIndex];
    return AlertDialog(
      // Two-part title: primary action ("역산") in the headline
      // weight, subtitle ("상대 노력치 추정") as muted aside so it
      // doesn't compete with the main label.
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(AppStrings.t('reverse.title')),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              AppStrings.t('reverse.subtitle'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      content: GestureDetector(
        // Tap on empty content area drops focus so the IME collapses
        // without the user hunting for an outside tap target.
        behavior: HitTestBehavior.translucent,
        onTap: _unfocus,
        child: SizedBox(
          width: 360,
          // Fixed height so the dialog doesn't grow when the result
          // list appears — keeps the position stable on the screen
          // through search → result transitions.
          height: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Context line so the user knows what they're reverse-
              // calcing (which opponent + which move).
              Text(
                '${widget.attacker.localizedPokemonName}'
                ' · ${move?.localizedName ?? '-'}',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              // HP before / after — the most natural way to read the
              // observation off the screen during a real battle.
              // When both are filled, the damage field auto-updates.
              Row(
                children: [
                  Expanded(child: _hpField(
                    label: AppStrings.t('reverse.hpBefore'),
                    initial: _beforeText,
                    onChanged: _onBeforeChanged,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _hpField(
                    label: AppStrings.t('reverse.hpAfter'),
                    initial: _afterText,
                    onChanged: _onAfterChanged,
                  )),
                ],
              ),
              const SizedBox(height: 8),
              // Damage row — auto-filled from before-after, also
              // directly editable for users who happen to know the
              // damage already.
              Row(
                children: [
                  Expanded(child: _hpField(
                    label: AppStrings.t('reverse.observed'),
                    initial: _damageText,
                    onChanged: _onDamageChanged,
                    onSubmitted: (_) => _run(),
                  )),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _run,
                    child: Text(AppStrings.t('reverse.run')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: _resultArea(scheme)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.t('action.close')),
        ),
      ],
    );
  }

  /// Tiny helper so the three HP-related fields share styling
  /// without duplicating the SelectAllField scaffolding.
  Widget _hpField({
    required String label,
    required String initial,
    required ValueChanged<String> onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return SelectAllField(
      initialText: initial,
      keyboardType: TextInputType.number,
      textInputAction:
          onSubmitted != null ? TextInputAction.done : TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }

  Widget _resultArea(ColorScheme scheme) {
    final result = _result;
    if (!_searched) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          AppStrings.t('reverse.idleHint'),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      );
    }
    if (result == null) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          AppStrings.t('reverse.invalid'),
          style: TextStyle(fontSize: 12, color: Colors.red.shade400),
        ),
      );
    }
    if (result.candidates.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          AppStrings.t('reverse.noMatch'),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      );
    }
    // Group by nature bucket so the user reads "this nature → SP
    // range" instead of scrolling through individual rows. The
    // 'safest' candidate inside each bucket is the max-SP one
    // (largest possible offensive investment the observation is
    // consistent with) — that's what tap-apply installs, because
    // calculating defensive lines against the worst case is the
    // safer assumption when prepping for the next turn.
    final stat = _offenseStat();
    final boost = <ReverseCalcCandidate>[];
    final neutral = <ReverseCalcCandidate>[];
    final drop = <ReverseCalcCandidate>[];
    for (final c in result.candidates) {
      if (c.nature.up == stat) {
        boost.add(c);
      } else if (c.nature.down == stat) {
        drop.add(c);
      } else {
        neutral.add(c);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.t('reverse.countLine')
              .replaceAll('{n}', '${result.candidates.length}'),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView(
            children: [
              _bucketRow(
                scheme,
                label: AppStrings.t('nature.boostShort'),
                color: Colors.red.shade600,
                candidates: boost,
              ),
              const Divider(height: 1),
              _bucketRow(
                scheme,
                label: AppStrings.t('nature.neutralShort'),
                color: Colors.grey.shade700,
                candidates: neutral,
              ),
              const Divider(height: 1),
              _bucketRow(
                scheme,
                label: AppStrings.t('nature.dropShort'),
                color: Colors.blue.shade600,
                candidates: drop,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bucketRow(
    ColorScheme scheme, {
    required String label,
    required Color color,
    required List<ReverseCalcCandidate> candidates,
  }) {
    final tapToApply = widget.onApply != null && candidates.isNotEmpty;
    final stat = _offenseStat();
    final statLabel = _statLabel(stat);
    // Bucket-wide SP range. Candidates inside a bucket all share
    // the same nature multiplier, so any SP in [minSp, maxSp]
    // produces a damage that overlaps the observation.
    String rangeText;
    ReverseCalcCandidate? topPick;
    if (candidates.isEmpty) {
      rangeText = '—';
    } else {
      final sps = candidates.map((c) => ChampionsMode.evToSp(c.ev)).toList();
      final minSp = sps.reduce((a, b) => a < b ? a : b);
      final maxSp = sps.reduce((a, b) => a > b ? a : b);
      rangeText =
          minSp == maxSp ? '$statLabel $maxSp' : '$statLabel $minSp–$maxSp';
      // Tap installs the max-SP candidate — the safest defensive
      // assumption (opponent invested as much as the observation
      // allows).
      topPick = candidates.reduce(
          (a, b) => ChampionsMode.evToSp(a.ev) >= ChampionsMode.evToSp(b.ev)
              ? a
              : b);
    }
    return InkWell(
      onTap: tapToApply
          ? () {
              widget.onApply!(topPick!);
              Navigator.pop(context);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            // Nature label, color-coded to match the result's
            // direction (red boost / grey neutral / blue drop).
            SizedBox(
              width: 88,
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
            ),
            Expanded(
              child: Text(
                rangeText,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: candidates.isEmpty
                      ? Colors.grey.shade400
                      : null,
                ),
              ),
            ),
            // Hint that the row is tappable when we have something
            // to apply; absent when the bucket has no candidates.
            if (tapToApply)
              Icon(Icons.chevron_right,
                  size: 18, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  NatureStat _offenseStat() {
    final move = widget.attacker.moves[widget.moveIndex];
    if (move == null || move.category != MoveCategory.physical) {
      return NatureStat.spa;
    }
    return NatureStat.atk;
  }

  String _statLabel(NatureStat s) {
    switch (s) {
      case NatureStat.atk:
        return AppStrings.t('stat.attack');
      case NatureStat.def:
        return AppStrings.t('stat.defense');
      case NatureStat.spa:
        return AppStrings.t('stat.spAttack');
      case NatureStat.spd:
        return AppStrings.t('stat.spDefense');
      case NatureStat.spe:
        return AppStrings.t('stat.speed');
    }
  }
}

/// Helper used by the calc screens to install a chosen candidate
/// onto an attacker state. Lifted out of the screens to keep them
/// stat-mutation-free (and so the team builder / dex can reuse the
/// same logic later).
void applyReverseCalcCandidate(
  BattlePokemonState attacker,
  ReverseCalcCandidate c,
  MoveCategory category,
) {
  final isPhysical = category == MoveCategory.physical;
  attacker.ev = Stats(
    hp: attacker.ev.hp,
    attack: isPhysical ? c.ev : attacker.ev.attack,
    defense: attacker.ev.defense,
    spAttack: isPhysical ? attacker.ev.spAttack : c.ev,
    spDefense: attacker.ev.spDefense,
    speed: attacker.ev.speed,
  );
  attacker.nature = c.nature;
}
