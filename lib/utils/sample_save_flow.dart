import 'package:flutter/material.dart';
import '../data/sample_storage.dart';
import '../models/battle_pokemon.dart';
import '../models/dynamax.dart';
import '../models/terastal.dart';
import '../utils/app_strings.dart';
import '../views/widgets/save_sample_dialog.dart';

/// Outcome of a successful [SampleSaveFlow.run] call. Callers update
/// their own "loaded sample" tracking (calc's `_attackerLoadedName`,
/// team builder's `slot.loadedSampleName`/`slot.sampleId`) from this.
class SaveSampleOutcome {
  /// Final sample name (post-overwrite-confirm, post-dialog edit).
  final String name;

  /// Id of the sample now backing [name] — newly assigned on a fresh
  /// save, or the existing id when the user overwrote.
  final String sampleId;

  const SaveSampleOutcome({required this.name, required this.sampleId});
}

/// End-to-end save flow shared by the calculator's per-side save and
/// the team builder's per-slot save. Opens [SaveSampleDialog],
/// handles the overwrite confirm, performs the save (creating or
/// updating in place), applies the team move if the user picked a
/// different team, and surfaces a "saved" snackbar.
///
/// Returns `null` when the user cancelled the dialog, the overwrite
/// confirm, or hit a hard cap (team-full snackbar fires instead).
class SampleSaveFlow {
  SampleSaveFlow._();

  static Future<SaveSampleOutcome?> run({
    required BuildContext context,
    required BattlePokemonState state,
    String? loadedName,
  }) async {
    final result = await showDialog<SaveSampleDialogResult>(
      context: context,
      builder: (ctx) => SaveSampleDialog(
        defaultName: loadedName ?? state.localizedPokemonName,
        loadedName: loadedName,
      ),
    );
    if (result == null) return null;
    final name = result.name;
    if (name.isEmpty) return null;

    // Strip transient battle state (Tera, Dynamax, Z-Move flags) from
    // the snapshot we save — those toggles model the current turn's
    // situation, not a build property, so persisting them would
    // resurface old turn-state when the sample is loaded into another
    // match. Builds the user actually wants to keep (movesets, EVs,
    // ability, item) survive untouched.
    final saveState = BattlePokemonState.fromJson(state.toJson())
      ..terastal = const TerastalState()
      ..dynamax = DynamaxState.none
      ..zMoves = [false, false, false, false];

    String? savedSampleId;
    final exists = await SampleStorage.sampleExists(name);
    if (exists) {
      if (!context.mounted) return null;
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppStrings.t('sample.duplicateTitle')),
          content: Text(AppStrings.t('sample.duplicateMessage')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.t('action.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.t('action.overwrite')),
            ),
          ],
        ),
      );
      if (overwrite != true) return null;
      // Overwrite the state in place, then honor the dialog's team
      // selection if the user moved the pokemon to a different party
      // (or freshly created one). Without this, picking a new party
      // on the overwrite path silently dropped — the dialog let the
      // user think it would move, but only the state replacement
      // ran.
      await SampleStorage.overwriteSample(name, saveState);
      final overwritten = (await SampleStorage.loadStore())
          .samples
          .where((s) => s.name == name)
          .firstOrNull;
      if (overwritten != null) {
        savedSampleId = overwritten.id;
        String? targetTeamId = result.teamId;
        if (result.newTeamName != null) {
          targetTeamId =
              await SampleStorage.createTeam(result.newTeamName!);
        }
        final currentTeamId = (await SampleStorage.loadStore())
            .teamOf(overwritten.id)
            ?.id;
        if (currentTeamId != targetTeamId) {
          try {
            await SampleStorage.movePokemon(overwritten.id, targetTeamId);
          } on TeamFullException {
            if (!context.mounted) return null;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(AppStrings.t('sample.team.fullSnack')),
            ));
            return null;
          }
        }
      }
    } else {
      // Resolve target team: existing pick, or freshly created if the
      // user chose "+ 새 팀". Wrapped in a try so a TeamFullException
      // surfaces as a snackbar instead of crashing.
      String? teamId = result.teamId;
      if (result.newTeamName != null) {
        teamId = await SampleStorage.createTeam(result.newTeamName!);
      }
      try {
        savedSampleId = await SampleStorage.savePokemon(
            name: name, state: saveState, teamId: teamId);
      } on TeamFullException {
        if (!context.mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppStrings.t('sample.team.fullSnack')),
        ));
        return null;
      }
    }

    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('"$name" 저장 완료'),
          duration: const Duration(seconds: 2)),
    );
    // savedSampleId is set on every non-cancel path above; the
    // fallthrough only happens if overwriteSample raced with an
    // external deletion (extremely unlikely), in which case we bail.
    if (savedSampleId == null) return null;
    return SaveSampleOutcome(name: name, sampleId: savedSampleId);
  }
}
