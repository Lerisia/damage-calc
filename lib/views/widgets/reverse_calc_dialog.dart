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
  /// Mirror of the SelectAllField's text. SelectAllField owns its
  /// own controller; this is a relay updated on every onChanged so
  /// _run can read the current value without reaching into the
  /// widget's internals.
  String _typed = '';
  ReverseCalcResult? _result;
  bool _searched = false;

  void _unfocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _run() {
    // Dropping focus on submit lets the IME collapse — otherwise
    // the keyboard sits over the result list and the user has to
    // tap outside to see anything.
    _unfocus();
    final raw = int.tryParse(_typed);
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
      title: Text(AppStrings.t('reverse.title')),
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
          height: 420,
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
              Row(
                children: [
                  Expanded(
                    child: SelectAllField(
                      initialText: _typed,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: AppStrings.t('reverse.observed'),
                        hintText: AppStrings.t('reverse.observedHint'),
                        isDense: true,
                        border: const OutlineInputBorder(),
                        // Always-floating label so the field caption +
                        // hint are both visible before the user taps
                        // (default behaviour hides the hint until the
                        // field is focused, which read as confusing).
                        floatingLabelBehavior:
                            FloatingLabelBehavior.always,
                      ),
                      onChanged: (v) => _typed = v,
                      // Enter / 완료 키 submission triggers the same
                      // run + unfocus flow the explicit button does,
                      // so the user doesn't have to hunt for the
                      // button after typing.
                      onSubmitted: (_) => _run(),
                    ),
                  ),
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
          child: ListView.separated(
            itemCount: result.candidates.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) =>
                _candidateRow(scheme, result.candidates[i]),
          ),
        ),
      ],
    );
  }

  Widget _candidateRow(ColorScheme scheme, ReverseCalcCandidate c) {
    final tapToApply = widget.onApply != null;
    final stat = _offenseStat();
    final boost = c.nature.up == stat;
    final drop = c.nature.down == stat;
    // EV displayed in Champions SP units (0-32) per the project's
    // standard display rule — never raw 0-252 EVs outside the calc's
    // own input field.
    final sp = ChampionsMode.evToSp(c.ev);
    final statLabel = _statLabel(stat);
    return InkWell(
      onTap: tapToApply
          ? () {
              widget.onApply!(c);
              Navigator.pop(context);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            // Stat + SP value, e.g. "공격 32".
            Text(
              '$statLabel $sp',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            // Boost / neutral / drop indicator — ONLY the relevant
            // offensive stat's modifier. The 'down' stat in the
            // candidate's NatureProfile is one of several
            // equally-plausible drops (e.g. an Atk-boost nature
            // could drop SpA, SpD, Def, or Spe), so showing the
            // specific drop stat would mislead. Plain "상승/하락/
            // 무보정 성격" text instead of arrows because the user
            // found the bare arrows ambiguous.
            Text(
              boost
                  ? AppStrings.t('nature.boostShort')
                  : drop
                      ? AppStrings.t('nature.dropShort')
                      : AppStrings.t('nature.neutralShort'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: boost
                    ? Colors.red.shade600
                    : drop
                        ? Colors.blue.shade600
                        : Colors.grey.shade700,
              ),
            ),
            const Spacer(),
            // Derived damage range so the user can sanity-check the
            // match against what they observed.
            Text(
              '${c.minDamage}~${c.maxDamage}',
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade600),
            ),
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
