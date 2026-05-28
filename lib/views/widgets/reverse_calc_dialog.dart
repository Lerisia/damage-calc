import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/battle_pokemon.dart';
import '../../models/nature_profile.dart';
import '../../models/room.dart';
import '../../models/terrain.dart';
import '../../models/weather.dart';
import '../../utils/app_strings.dart';
import '../../utils/aura_effects.dart';
import '../../utils/ruin_effects.dart';
import '../../utils/reverse_calc.dart';
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
class ReverseCalcDialog extends StatefulWidget {
  final BattlePokemonState attacker;
  final BattlePokemonState defender;
  final int moveIndex;
  final Weather weather;
  final Terrain terrain;
  final RoomConditions room;
  final AuraToggles auras;
  final RuinToggles ruins;

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
  });

  @override
  State<ReverseCalcDialog> createState() => _ReverseCalcDialogState();
}

class _ReverseCalcDialogState extends State<ReverseCalcDialog> {
  final _damageCtl = TextEditingController();
  ReverseCalcResult? _result;
  bool _searched = false;

  @override
  void dispose() {
    _damageCtl.dispose();
    super.dispose();
  }

  void _run() {
    final raw = int.tryParse(_damageCtl.text);
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
      // Single observation: the damage matches if the candidate's
      // computed range includes the typed value (min ≤ raw ≤ max).
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
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Context line so the user knows what they're reverse-
            // calcing (which opponent + which move).
            Text(
              '${widget.attacker.localizedPokemonName}'
              ' · ${move?.localizedName ?? '-'}',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SelectAllField(
                    initialText: _damageCtl.text,
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
                    ),
                    onChanged: (v) => _damageCtl.text = v,
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
            // Result region: collapsed before first search, then either
            // the candidate list or an empty-state hint.
            Flexible(child: _resultArea(scheme)),
          ],
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          AppStrings.t('reverse.idleHint'),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      );
    }
    if (result == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          AppStrings.t('reverse.invalid'),
          style: TextStyle(fontSize: 12, color: Colors.red.shade400),
        ),
      );
    }
    if (result.candidates.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          AppStrings.t('reverse.noMatch'),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${result.candidates.length} / ${result.searched}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 6),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
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
    final natureLabel = _natureLabel(c.nature);
    final natureColor = c.nature.up == _offenseStat()
        ? Colors.red.shade600
        : c.nature.down == _offenseStat()
            ? Colors.blue.shade600
            : Colors.grey.shade700;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // EV + nature label as the primary value the user wanted.
          // Uses competitive shorthand (e.g. "252+", "252", "0-").
          Text(
            _evLabel(c),
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Text(
            natureLabel,
            style: TextStyle(
                fontSize: 12,
                color: natureColor,
                fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          // Derived damage range so the user can sanity-check the
          // match against what they observed.
          Text(
            '${c.minDamage}~${c.maxDamage}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  /// Competitive-shorthand EV+nature suffix: 252+ / 252 / 252-, etc.
  String _evLabel(ReverseCalcCandidate c) {
    final suffix = c.nature.up == _offenseStat()
        ? '+'
        : c.nature.down == _offenseStat()
            ? '-'
            : '';
    return '${c.ev}$suffix';
  }

  NatureStat _offenseStat() {
    final move = widget.attacker.moves[widget.moveIndex];
    if (move == null) return NatureStat.atk;
    // ReverseCalc skips status moves before we ever render results,
    // so this is always physical or special at display time.
    return move.category.name == 'physical'
        ? NatureStat.atk
        : NatureStat.spa;
  }

  String _natureLabel(NatureProfile n) {
    if (n.up == null && n.down == null) {
      return AppStrings.t('nature.neutralShort');
    }
    String label(NatureStat s) {
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
    final up = n.up != null ? '↑${label(n.up!)}' : '';
    final down = n.down != null ? '↓${label(n.down!)}' : '';
    return '$up$down';
  }
}
