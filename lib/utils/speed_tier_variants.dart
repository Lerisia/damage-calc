import '../data/champions_usage.dart';
import '../models/nature_profile.dart';
import '../models/pokemon.dart';
import '../models/stats.dart';
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

/// Choice Scarf only shows for Pokémon that actually run one. A
/// listed item isn't enough — the usage tables go ten deep, and Scarf
/// appears somewhere on half the roster. Top five is the cut that
/// separates real Scarf users from incidental ones.
const _scarfTopN = 5;
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

bool _runsChoiceScarf(String pokemonName, ChampionsFormat? format) {
  final usage = championsUsageFor(pokemonName, format: format);
  if (usage == null) return false;
  return usage.items
      .take(_scarfTopN)
      .any((i) => i.name == _scarfItemId);
}
