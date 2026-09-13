part of '../team_coverage_screen.dart';

/// One slot in the team-builder. We keep just the bits that affect
/// type matchups — full BattlePokemonState is overkill here and would
/// drag along EV/level/move state nobody fills out.
class _TeamSlot {
  Pokemon? pokemon;
  String? ability;
  String? heldItem; // currently only used to honour Air Balloon / Iron Ball
  /// Up to 4 moves used for the offensive coverage matrix. Indexes
  /// are stable; null entries render as empty pickers in the UI.
  /// State-dependent moves (Tera Blast, Ivy Cudgel, …) resolve via
  /// [coverageMoveFromMove] when the matrix is built.
  final List<Move?> moves = List<Move?>.filled(4, null, growable: false);
  /// Source sample id when this slot was hydrated from a saved
  /// sample (via party load or single-slot load). Used by
  /// `_saveAsParty` to update existing samples in place on overwrite
  /// — so a custom rename like "한카리아스 (특수형)" survives a
  /// re-save when the species hasn't changed. Stays set across
  /// ability / item / move edits (the binding is to the saved
  /// sample, not to its current data).
  String? sampleId;

  /// Display name of the loaded sample (parallel to [sampleId]) —
  /// surfaced as the default name in the per-slot save dialog so
  /// re-saves overwrite the same sample by default. Populated by
  /// both single-slot load and party load, kept in sync with
  /// [sampleId]. Survives edits like the calc's loaded-name field.
  String? loadedSampleName;
  /// User-applied type override (Soak / Forest's Curse / Burn Up /
  /// 3-type combos). `null` means "use the species' natural types";
  /// when non-null, all three slots are explicit (type2/type3 may
  /// still be null individually to mean "no second/third type").
  ({PokemonType type1, PokemonType? type2, PokemonType? type3})? typeOverride;
  /// Effort values + nature, populated when a sample is loaded into
  /// this slot. Surfaced read-only in the summary card; the team
  /// builder doesn't expose an EV/nature editor yet, so the only
  /// path to non-zero values is loading a saved sample.
  Stats? evs;
  NatureProfile? nature;

  /// Show the alternate-color (shiny / 이로치) sprite for this slot.
  /// Visual only — no calc impact. Persisted across save/load:
  /// _saveSlotAsSample / _saveAsParty include it in the
  /// BattlePokemonState; _loadParty / _loadSampleInto rehydrate it.
  bool shiny = false;

  /// Effective type1 — override wins, else species natural type1.
  PokemonType? get effectiveType1 =>
      typeOverride?.type1 ?? pokemon?.type1;

  /// Effective type2 — explicitly null when override sets it null.
  PokemonType? get effectiveType2 =>
      typeOverride != null ? typeOverride!.type2 : pokemon?.type2;

  /// Effective type3 — only ever set via override (Forest's Curse).
  PokemonType? get effectiveType3 => typeOverride?.type3;
}

/// Process-lifetime team state — survives navigating away from the
/// screen so the user doesn't lose their picks the moment they pop
/// back to the calculator. Cleared only on app restart. (Persistent
/// disk storage will hook into the existing sample save/load slot.)
class _TeamCoverageStore {
  static const int maxTeamSize = 6;
  static final List<_TeamSlot> team =
      List.generate(maxTeamSize, (_) => _TeamSlot());
  /// Opponent slots — dynamically grown via the "+ 상대 추가" button,
  /// capped at [maxTeamSize]. Cleared on full reset and never saved
  /// as part of a party (opponents are situational scratch data).
  static final List<_TeamSlot> opponents = <_TeamSlot>[];
  /// Name of the saved party most recently loaded into [team]. Used
  /// by `_saveAsParty` to default the save dialog name and to detect
  /// the overwrite case. Cleared on full reset.
  static String? loadedPartyName;
  /// Lineup-mode toggle ("선출 보기"). When true, the matrix dims
  /// every column and the summary collapses to 0/0; tapping a
  /// header pokemon name toggles its slot index in [lineup], which
  /// brings that column back to full opacity and adds it to the
  /// summary count.
  static bool lineupMode = false;
  /// Slot indices (within [team]) currently included in the lineup —
  /// opponent columns are never lineup-eligible. Cleared on full
  /// reset.
  static final Set<int> lineup = <int>{};
}
