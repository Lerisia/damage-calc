import '../data/abilitydex.dart';
import '../data/champions_usage.dart';
import '../data/pokedex.dart';
import '../models/rank.dart';
import '../models/nature_profile.dart';
import '../models/status.dart';
import '../models/terrain.dart';
import '../models/weather.dart';
import 'ability_effects.dart';
import '../models/pokemon.dart';
import '../models/stats.dart';
import '../i18n/app_strings.dart';
import '../controllers/champions_format_controller.dart';
import 'champions_mode.dart';
import 'stat_calculator.dart';

/// The spreads a Champions speed tier lists a Pokémon under.
enum SpeedVariantKind {
  /// 무보정 — neutral nature, no SP.
  neutral,

  /// 준속 — neutral nature, full SP.
  invested,

  /// 최속 — boosting nature, full SP.
  boosted,

  /// 준스카프 — [invested] under a Choice Scarf.
  scarfInvested,

  /// 극스카프 — [boosted] under a Choice Scarf.
  scarfBoosted,

  /// 준속 + 스피드 특성 — [invested] with a speed ability active
  /// (Swift Swim in rain, Unburden after the item is gone, …).
  abilityInvested,

  /// 최속 + 스피드 특성 — [boosted] with a speed ability active.
  abilityBoosted,

  /// 준속 + N가속 — [invested] after N Speed Boost stages.
  rankInvested,

  /// 최속 + N가속 — [boosted] after N Speed Boost stages.
  rankBoosted,
}

extension SpeedVariantKindX on SpeedVariantKind {
  bool get isScarf =>
      this == SpeedVariantKind.scarfInvested ||
      this == SpeedVariantKind.scarfBoosted;

  bool get isAbility =>
      this == SpeedVariantKind.abilityInvested ||
      this == SpeedVariantKind.abilityBoosted;

  bool get isRank =>
      this == SpeedVariantKind.rankInvested ||
      this == SpeedVariantKind.rankBoosted;
}

class SpeedVariant {
  final SpeedVariantKind kind;

  /// Realized Lv50 Speed.
  final int speed;

  /// The speed ability behind an [SpeedVariantKind.isAbility] line
  /// (English key); null for every other kind.
  final String? ability;

  /// Speed stages behind an [SpeedVariantKind.isRank] line; null
  /// otherwise.
  final int? rank;

  const SpeedVariant(this.kind, this.speed, {this.ability, this.rank});
}

/// Speed Boost stages the table lists. Two is where the boost
/// stops mattering for a tier chart — past +2 almost everything is
/// outsped anyway.
const _speedBoostStages = [1, 2];

/// Whether [pokemon] enters battle able to accrue Speed Boost. A Mega
/// whose base form has it counts too: the stages are gained before
/// Mega Evolving and stay — Mega Scolipede without Speed Boost is
/// still a Scolipede that boosted on turn one.
bool _canSpeedBoost(Pokemon pokemon) {
  if (pokemon.abilities.contains('Speed Boost')) return true;
  if (!pokemon.isMega) return false;
  for (final b in pokemon.allBaseSpecies) {
    if (pokedexByName(b)?.abilities.contains('Speed Boost') ?? false) {
      return true;
    }
  }
  return false;
}

/// Speed abilities the table lists extra lines for, each with the
/// context that switches it on. The multiplier itself comes from
/// [getAbilityEffect] — the same table the calculator uses — so the
/// two can't drift apart. Speed Boost is deliberately absent: it is a
/// per-turn rank change, not a fixed multiplier.
const _speedAbilityContexts = <String, ({Weather weather, Terrain terrain, StatusCondition status, String? item})>{
  'Swift Swim':   (weather: Weather.rain,      terrain: Terrain.none,     status: StatusCondition.none,      item: 'x'),
  'Chlorophyll':  (weather: Weather.sun,       terrain: Terrain.none,     status: StatusCondition.none,      item: 'x'),
  'Sand Rush':    (weather: Weather.sandstorm, terrain: Terrain.none,     status: StatusCondition.none,      item: 'x'),
  'Slush Rush':   (weather: Weather.snow,      terrain: Terrain.none,     status: StatusCondition.none,      item: 'x'),
  'Surge Surfer': (weather: Weather.none,      terrain: Terrain.electric, status: StatusCondition.none,      item: 'x'),
  'Quick Feet':   (weather: Weather.none,      terrain: Terrain.none,     status: StatusCondition.paralysis, item: 'x'),
  'Unburden':     (weather: Weather.none,      terrain: Terrain.none,     status: StatusCondition.none,      item: null),
};

/// Active-state speed multiplier of [ability], or null when it isn't a
/// speed ability this table lists.
double? speedAbilityMultiplier(String ability) {
  final ctx = _speedAbilityContexts[ability];
  if (ctx == null) return null;
  final m = getAbilityEffect(ability,
          weather: ctx.weather, terrain: ctx.terrain, status: ctx.status,
          heldItem: ctx.item)
      .statModifiers.speed;
  return m == 1.0 ? null : m;
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
  // Speed abilities: one 준/극 pair per ability the species can have,
  // gated on the dex (not on adoption) — the user asked for every
  // holder, and unlike a Scarf the ability is a fixed trait.
  for (final a in pokemon.abilities) {
    final m = speedAbilityMultiplier(a);
    if (m == null) continue;
    variants.add(SpeedVariant(SpeedVariantKind.abilityInvested,
        (invested * m).floor(), ability: a));
    variants.add(SpeedVariant(SpeedVariantKind.abilityBoosted,
        (boosted * m).floor(), ability: a));
  }
  if (_canSpeedBoost(pokemon)) {
    for (final n in _speedBoostStages) {
      final m = Rank(speed: n).speedMultiplier;
      variants.add(SpeedVariant(SpeedVariantKind.rankInvested,
          (invested * m).floor(), ability: 'Speed Boost', rank: n));
      variants.add(SpeedVariant(SpeedVariantKind.rankBoosted,
          (boosted * m).floor(), ability: 'Speed Boost', rank: n));
    }
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
String speedVariantLabel(SpeedVariantKind kind,
    {required bool withIcon, String? ability, int? rank}) {
  if (kind.isRank) {
    final spread = AppStrings.t(kind == SpeedVariantKind.rankInvested
        ? 'speedTier.spread.invested'
        : 'speedTier.spread.boosted');
    return '$spread ${AppStrings.t('speedTier.spread.speedBoost').replaceAll('{n}', '${rank ?? 1}')}';
  }
  if (kind.isAbility) {
    final spread = AppStrings.t(kind == SpeedVariantKind.abilityInvested
        ? 'speedTier.spread.invested'
        : 'speedTier.spread.boosted');
    final ab = ability == null ? null : abilityByNameSync(ability);
    final name = ab == null
        ? (ability ?? '')
        : AppStrings.name(nameKo: ab.nameKo, nameEn: ab.nameEn, nameJa: ab.nameJa, name: ab.name);
    return '$spread $name';
  }
  if (kind.isScarf && !withIcon) {
    return AppStrings.t(kind == SpeedVariantKind.scarfInvested
        ? 'speedTier.spread.scarfInvested'
        : 'speedTier.spread.scarfBoosted');
  }
  return switch (kind) {
    SpeedVariantKind.neutral => AppStrings.t('speedTier.spread.neutral'),
    SpeedVariantKind.invested ||
    SpeedVariantKind.scarfInvested ||
    SpeedVariantKind.abilityInvested ||
    SpeedVariantKind.rankInvested =>
      AppStrings.t('speedTier.spread.invested'),
    SpeedVariantKind.boosted ||
    SpeedVariantKind.scarfBoosted ||
    SpeedVariantKind.abilityBoosted ||
    SpeedVariantKind.rankBoosted =>
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
