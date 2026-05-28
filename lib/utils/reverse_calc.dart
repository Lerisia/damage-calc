import '../models/battle_pokemon.dart';
import '../models/move.dart';
import '../models/nature_profile.dart';
import '../models/room.dart';
import '../models/stats.dart';
import '../models/terrain.dart';
import '../models/weather.dart';
import 'aura_effects.dart';
import 'champions_mode.dart';
import 'damage_calculator.dart';
import 'ruin_effects.dart';

/// One viable (offensive EV, nature) candidate for the attacker that
/// produces a damage range overlapping the observed value.
///
/// `ev` is the EV on the offensive stat the move scales off of
/// (Attack for physical, Sp. Atk for special). `nature` is the
/// attacker's nature; only the up/down on the offensive stat
/// affects the calc.
class ReverseCalcCandidate {
  final int ev;
  final NatureProfile nature;
  /// Computed damage range under this (ev, nature) combo, in HP
  /// points (NOT percent). Lets the UI show the implied roll spread
  /// next to each candidate so the user can see how tight the
  /// match is.
  final int minDamage;
  final int maxDamage;

  const ReverseCalcCandidate({
    required this.ev,
    required this.nature,
    required this.minDamage,
    required this.maxDamage,
  });
}

class ReverseCalcResult {
  final List<ReverseCalcCandidate> candidates;
  /// Total (ev, nature) combos that were evaluated. Useful for the
  /// UI to show "47 / 192 spreads match" so the user knows how
  /// loose vs tight their observation pinned things.
  final int searched;
  const ReverseCalcResult({
    required this.candidates,
    required this.searched,
  });
}

/// Reverse-calc engine: given a known defender, an attacker template
/// with everything fixed EXCEPT the offensive EV and nature, and an
/// observed damage range, enumerate the (EV, nature) combos that
/// could have produced that damage.
///
/// Search space when ability / item / rank / tera / etc. are all
/// pinned by the caller:
///   - SP (Champions stat-point grid, 0..32) → 33 values. We
///     iterate SP-not-EV so each row in the UI corresponds to a
///     visually-distinct spread; iterating raw EVs in step-4 chunks
///     produced multiple EV values mapping to the same SP after
///     display conversion (e.g. EV 60 and EV 64 both → SP 8) and
///     the candidate list showed visible duplicates.
///   - Nature: 3 states (boost / neutral / drop on the offensive
///     stat)
///   → 99 combos × 16-roll damage calc each. Still effectively
///   instant.
///
/// The defender state passed in is consumed verbatim — typically
/// it's the user's own pokemon (fully known). The attacker template
/// must already have the move at [moveIndex] set; the move's
/// category (physical / special) decides which stat we iterate.
class ReverseCalc {
  ReverseCalc._();

  static ReverseCalcResult run({
    required BattlePokemonState defender,
    required BattlePokemonState attackerTemplate,
    required int moveIndex,
    required int observedMin,
    required int observedMax,
    Weather weather = Weather.none,
    Terrain terrain = Terrain.none,
    RoomConditions room = const RoomConditions(),
    AuraToggles auras = AuraToggles.inactive,
    RuinToggles ruins = RuinToggles.inactive,
  }) {
    final move = attackerTemplate.moves[moveIndex];
    if (move == null || move.category == MoveCategory.status) {
      return const ReverseCalcResult(candidates: [], searched: 0);
    }
    if (observedMin > observedMax) {
      return const ReverseCalcResult(candidates: [], searched: 0);
    }

    final isPhysical = move.category == MoveCategory.physical;
    // Three nature buckets keyed by what they do to the offensive
    // stat the move uses. Symmetric with the user's mental model
    // ("이 공격은 보정 / 비보정 / 감소"), and three states is what
    // a single offensive-stat modifier can produce.
    final natureOptions = isPhysical
        ? const [
            NatureProfile(up: NatureStat.atk, down: NatureStat.spa),
            NatureProfile.neutral,
            NatureProfile(up: NatureStat.spa, down: NatureStat.atk),
          ]
        : const [
            NatureProfile(up: NatureStat.spa, down: NatureStat.atk),
            NatureProfile.neutral,
            NatureProfile(up: NatureStat.atk, down: NatureStat.spa),
          ];

    final candidates = <ReverseCalcCandidate>[];
    int searched = 0;
    for (int sp = 0; sp <= ChampionsMode.maxPerStat; sp++) {
      final ev = ChampionsMode.spToEv(sp);
      for (final nature in natureOptions) {
        searched++;
        final candidate = _withEvAndNature(
          attackerTemplate, ev, nature, isPhysical: isPhysical);
        final result = DamageCalculator.calculate(
          attacker: candidate,
          defender: defender,
          moveIndex: moveIndex,
          weather: weather,
          terrain: terrain,
          room: room,
          auras: auras,
          ruins: ruins,
        );
        if (result.allRolls.isEmpty) continue;
        // Overlap check: any roll in [result.min, result.max] falls
        // inside [observedMin, observedMax]?
        if (result.maxDamage < observedMin) continue;
        if (result.minDamage > observedMax) continue;
        candidates.add(ReverseCalcCandidate(
          ev: ev,
          nature: nature,
          minDamage: result.minDamage,
          maxDamage: result.maxDamage,
        ));
      }
    }

    _sortByLikelihood(candidates, isPhysical: isPhysical);
    return ReverseCalcResult(candidates: candidates, searched: searched);
  }

  /// Plausibility heuristic — competitive spreads cluster at
  /// extremes. Order:
  ///   1. Offensive-boost natures first (Adamant / Modest etc.).
  ///   2. Higher EVs first (252, 248, 244, …).
  /// The neutral and drop natures still appear in the list, just
  /// after the boost-nature candidates with the same EV bracket.
  static void _sortByLikelihood(List<ReverseCalcCandidate> list,
      {required bool isPhysical}) {
    final boostStat = isPhysical ? NatureStat.atk : NatureStat.spa;
    int bucket(NatureProfile n) {
      if (n.up == boostStat) return 0; // boost
      if (n.down == boostStat) return 2; // drop
      return 1; // neutral
    }
    list.sort((a, b) {
      final bucketCmp = bucket(a.nature).compareTo(bucket(b.nature));
      if (bucketCmp != 0) return bucketCmp;
      return b.ev.compareTo(a.ev); // higher EV first within a bucket
    });
  }

  /// Returns a deep-cloned attacker state with the offensive EV and
  /// nature overridden. Other fields (HP / Def / SpD / item / ability
  /// / rank / tera / etc.) are preserved verbatim.
  static BattlePokemonState _withEvAndNature(
      BattlePokemonState template, int ev, NatureProfile nature,
      {required bool isPhysical}) {
    // toJson/fromJson roundtrip is the cheapest fully-correct deep
    // clone — keeps every nullable + list field in sync without us
    // having to thread the constructor by hand each time
    // BattlePokemonState grows a new field.
    final clone = BattlePokemonState.fromJson(template.toJson());
    final templateEv = template.ev;
    clone.ev = Stats(
      hp: templateEv.hp,
      attack: isPhysical ? ev : templateEv.attack,
      defense: templateEv.defense,
      spAttack: isPhysical ? templateEv.spAttack : ev,
      spDefense: templateEv.spDefense,
      speed: templateEv.speed,
    );
    clone.nature = nature;
    return clone;
  }
}
