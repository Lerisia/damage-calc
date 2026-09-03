import '../data/champions_usage.dart';
import '../models/nature_profile.dart';
import '../models/pokemon.dart';
import '../models/stats.dart';
import 'app_strings.dart';
import 'champions_format_controller.dart';
import 'champions_mode.dart';
import 'stat_calculator.dart';

/// The spreads a Champions speed tier lists a Pokémon under.
enum SpeedVariantKind {
  /// 무보정 — neutral nature, no SP.
  neutral,

  /// 준보정 — neutral nature, full SP.
  invested,

  /// 극보정 — boosting nature, full SP.
  boosted,

  /// 준스카프 — [invested] under a Choice Scarf.
  scarfInvested,

  /// 극스카프 — [boosted] under a Choice Scarf.
  scarfBoosted,
}

extension SpeedVariantKindX on SpeedVariantKind {
  bool get isScarf =>
      this == SpeedVariantKind.scarfInvested ||
      this == SpeedVariantKind.scarfBoosted;
}

class SpeedVariant {
  final SpeedVariantKind kind;

  /// Realized Lv50 Speed.
  final int speed;

  const SpeedVariant(this.kind, this.speed);
}

/// Choice Scarf only shows for Pokémon that actually run one.
///
/// Presence isn't enough: the usage tables go ten deep and Scarf turns
/// up on about half the roster, at a median of under 5%. Ranking by
/// position doesn't help either — a top-five cut still let 113 species
/// through in singles. Threshold on the adoption rate instead, which
/// keeps its meaning as the data refreshes.
///
/// 40% sits above the crowded middle. Sorted by adoption the values
/// run nearly continuously up to ~54%, then jump 15 points to the
/// Pokémon that are simply expected to hold one — the Rotom formes,
/// Ditto, Hydreigon. Cutting at 40 keeps that group plus the clear
/// Scarf users just below it (Tyrantrum, Basculegion, Meowscarada,
/// Excadrill) and drops the long tail of incidental sets: about ten
/// species per format, versus 55 at a 10% cut.
const _scarfMinPct = 40.0;
const _scarfItemId = 'choice-scarf';

/// The speeds [pokemon] should appear at in the realized-value tier
/// table, in ascending order.
///
/// Always three tiers; two more when the Pokémon runs a Choice Scarf
/// in [format] (defaults to the format currently being viewed). The
/// Scarf check is per-format on purpose — a singles Scarf habit
/// shouldn't leak into the doubles table.
List<SpeedVariant> speedVariantsFor(
  Pokemon pokemon, {
  ChampionsFormat? format,
}) {
  int speedWith({required int sp, required bool boosting}) {
    final stats = StatCalculator.calculate(
      baseStats: pokemon.baseStats,
      iv: ChampionsMode.fixedIv,
      ev: Stats(
        hp: 0,
        attack: 0,
        defense: 0,
        spAttack: 0,
        spDefense: 0,
        speed: ChampionsMode.spToEv(sp),
      ),
      nature: boosting
          ? const NatureProfile(up: NatureStat.spe, down: NatureStat.atk)
          : NatureProfile.neutral,
      level: ChampionsMode.level,
    );
    return stats.speed;
  }

  final neutral = speedWith(sp: 0, boosting: false);
  final invested =
      speedWith(sp: ChampionsMode.maxPerStat, boosting: false);
  final boosted = speedWith(sp: ChampionsMode.maxPerStat, boosting: true);

  final variants = <SpeedVariant>[
    SpeedVariant(SpeedVariantKind.neutral, neutral),
    SpeedVariant(SpeedVariantKind.invested, invested),
    SpeedVariant(SpeedVariantKind.boosted, boosted),
  ];

  if (_runsChoiceScarf(pokemon.name, format)) {
    variants.add(SpeedVariant(
        SpeedVariantKind.scarfInvested, (invested * 1.5).floor()));
    variants.add(SpeedVariant(
        SpeedVariantKind.scarfBoosted, (boosted * 1.5).floor()));
  }
  return variants;
}

/// Label for a chip on the realized speed table.
///
/// Pass [withIcon] false when the Choice Scarf icon can't be shown —
/// it ships in the sprite pack, so a user without one (or on a pack
/// predating items/) would otherwise see a Scarf chip reading exactly
/// like the plain spread it modifies, sitting at a different speed
/// with nothing to explain the gap. Then the word carries it instead.
String speedVariantLabel(SpeedVariantKind kind, {required bool withIcon}) {
  if (kind.isScarf && !withIcon) {
    return AppStrings.t(kind == SpeedVariantKind.scarfInvested
        ? 'speedTier.spread.scarfInvested'
        : 'speedTier.spread.scarfBoosted');
  }
  return switch (kind) {
    SpeedVariantKind.neutral => AppStrings.t('speedTier.spread.neutral'),
    SpeedVariantKind.invested ||
    SpeedVariantKind.scarfInvested =>
      AppStrings.t('speedTier.spread.invested'),
    SpeedVariantKind.boosted ||
    SpeedVariantKind.scarfBoosted =>
      AppStrings.t('speedTier.spread.boosted'),
  };
}

bool _runsChoiceScarf(String pokemonName, ChampionsFormat? format) {
  final usage = championsUsageFor(pokemonName, format: format);
  if (usage == null) return false;
  for (final i in usage.items) {
    if (i.name == _scarfItemId) return (i.pct ?? 0) >= _scarfMinPct;
  }
  return false;
}
