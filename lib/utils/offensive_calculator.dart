import 'dart:math' as math;

import '../models/stats.dart';
import '../models/status.dart';
import '../models/nature_profile.dart';
import '../models/move.dart';
import '../models/move_tags.dart';
import '../models/rank.dart';
import '../models/type.dart';
import '../models/terrain.dart';
import '../models/weather.dart';
import 'aura_effects.dart';
import 'damage_calculator.dart' show kStandardStab, kCriticalMultiplier,
    kStellarStabMatching, kStellarStabNonMatching, kTeraMinPower, kBurnDamageReduction;
import 'move_transform.dart';
import 'ruin_effects.dart';
import 'stat_calculator.dart';
import 'terrain_effects.dart';
import 'weather_effects.dart';

/// Terastal STAB: same original type + tera type
const double kTeraStabSameType = 2.0;

/// Terastal STAB: same original type + tera type + Adaptability
const double kTeraStabSameTypeWithOverride = 2.25;

/// Calculates offensive power from a [TransformedMove].
///
/// Move transformations (power, type, stat selection) should be done via
/// [transformMove] in move_transform.dart before calling this.
///
/// [powerModifier] is applied to the final result. All stat-style
/// modifiers from abilities/items (Huge Power, Choice Band, …) are
/// expected to be folded into this single multiplier upstream so the
/// formula has one chained product (matching Showdown's atMods chain
/// + final pokeRound rather than two separate floors).
/// Returns 0 for status moves.
class OffensiveCalculator {

  static int calculate({
    required Stats baseStats,
    required Stats iv,
    required Stats ev,
    required NatureProfile nature,
    required int level,
    required TransformedMove transformed,
    required PokemonType type1,
    PokemonType? type2,
    PokemonType? type3,
    Rank rank = const Rank(),
    Weather weather = Weather.none,
    Terrain terrain = Terrain.none,
    double powerModifier = 1.0,
    bool isCritical = false,
    bool grounded = true,
    bool defenderGrounded = true,
    StatusCondition status = StatusCondition.none,
    bool hasGuts = false,
    double? stabOverride,
    double? criticalOverride,
    bool forceStab = false,
    int? opponentAttack,
    bool terastallized = false,
    PokemonType? teraType,
    double doublesPowerMod = 1.0,
    double doublesAttackMod = 1.0,
    AuraState auraState = AuraState.inactive,
    RuinState ruinState = RuinState.inactive,
    String? attackerAbility,
    String? defenderAbility,
    bool targetPhysDef = false,
    // When non-null, the calculator appends a modifier note for each
    // non-1.0 multiplier it applies (STAB, crit, weather, terrain,
    // burn, ruin, aura, Parental Bond, Tera variants). The damage-
    // calculator-style note keys (e.g. `stab:×1.5`, `crit:×1.5`,
    // `aura:×4/3`) are consumed by the 결정력 breakdown popup via
    // the same renderer used in the damage tab. Pre-formula
    // modifiers (item/ability power, atk-stat boosts, the
    // conditional bpMods) must be appended by the caller — they
    // arrive here pre-collapsed into `powerModifier`.
    List<String>? notesOut,
  }) {
    final move = transformed.move;

    if (move.category == MoveCategory.status) {
      return 0;
    }

    final stat = transformed.offensiveStat;

    // Critical hit: clamp negative rank to 0 for the stat being used
    final effectiveRank = isCritical
        ? Rank(
            attack: stat == OffensiveStat.attack || stat == OffensiveStat.higherAttack
                ? math.max(0, rank.attack) : rank.attack,
            defense: stat == OffensiveStat.defense
                ? math.max(0, rank.defense) : rank.defense,
            spAttack: stat == OffensiveStat.spAttack || stat == OffensiveStat.higherAttack
                ? math.max(0, rank.spAttack) : rank.spAttack,
            spDefense: rank.spDefense,
            speed: rank.speed,
          )
        : rank;

    final actualStats = StatCalculator.calculate(
      baseStats: baseStats,
      iv: iv,
      ev: ev,
      nature: nature,
      level: level,
      rank: effectiveRank,
    );

    final int rawStat = transformed.resolveStat(actualStats, opponentAttack: opponentAttack);

    // Ruin field effect on the attacker stat (self-exempt handled inside).
    // Folded into the final multiplier chain — no intermediate floor on
    // the stat (matches Showdown's chainMods + single pokeRound model).
    final ruin = getRuinEffect(
      attackerAbility: attackerAbility,
      defenderAbility: defenderAbility,
      category: move.category,
      targetPhysDef: targetPhysDef,
      state: ruinState,
    );
    final int modifiedStat = rawStat;

    // Protean/Libero: force STAB on all moves, but NOT during Terastal
    final bool isOriginalStab = (forceStab && !terastallized) ||
        move.type == type1 ||
        move.type == type2 ||
        move.type == type3;
    final bool isTeraStab = terastallized && teraType != null && move.type == teraType;

    // Determine STAB multiplier
    double stabMult = 1.0;
    if (terastallized && teraType != null) {
      if (teraType == PokemonType.stellar) {
        // Stellar: original STAB -> 2.0, non-STAB -> 1.2
        stabMult = isOriginalStab ? kStellarStabMatching : kStellarStabNonMatching;
      } else if (isTeraStab && isOriginalStab) {
        stabMult = stabOverride != null ? kTeraStabSameTypeWithOverride : kTeraStabSameType;
      } else if (isTeraStab) {
        stabMult = stabOverride ?? kStandardStab;
      } else if (isOriginalStab) {
        // Adaptability does NOT apply to original-type STAB after Tera
        stabMult = kStandardStab;
      }
    } else {
      stabMult = isOriginalStab ? (stabOverride ?? kStandardStab) : 1.0;
    }

    // Terastal minimum power: moves below 60 power become 60
    // Exceptions: multi-hit moves and priority moves are not boosted
    final int effectivePower = (terastallized && isTeraStab
        && !move.isMultiHit && move.priority <= 0
        && move.power < kTeraMinPower && move.power > 0)
        ? kTeraMinPower : move.power;

    final double weatherMod = getWeatherOffensiveModifier(weather, move: move);
    final double terrainMod = getTerrainModifier(terrain,
        move: move, attackerGrounded: grounded, defenderGrounded: defenderGrounded);

    // Burn halves physical damage unless Guts negates it OR the move
    // is Facade — Facade by spec ignores burn's Atk halving in
    // addition to its own ×2 power doubling (Gen V+).
    final double burnMod =
        (status == StatusCondition.burn &&
         move.category == MoveCategory.physical &&
         !hasGuts &&
         !move.hasTag(MoveTags.facade))
            ? kBurnDamageReduction
            : 1.0;

    // Parental Bond for 결정력: single-value approximation of 2-hit (1x + 0.25x).
    // Damage calculator handles the actual per-hit split separately.
    final double parentalBondMod = move.hasTag(MoveTags.parentalBond) ? 1.25 : 1.0;

    // Aura field effect (delta on top of attacker's own aura, already in stat).
    final aura = getAuraEffect(
      moveType: move.type,
      attackerAbility: attackerAbility,
      state: auraState,
    );

    final double critMult = isCritical
        ? (criticalOverride ?? kCriticalMultiplier) : 1.0;
    final double raw = modifiedStat *
        ruin.atkMod *
        doublesAttackMod *
        effectivePower *
        stabMult *
        critMult *
        weatherMod *
        terrainMod *
        burnMod *
        powerModifier *
        parentalBondMod *
        doublesPowerMod *
        aura.multiplier;

    // Emit one note per non-trivial multiplier. Caller (BattleFacade)
    // adds notes for the pre-collapsed `powerModifier` term (item /
    // ability / conditional-bpMods) and the doubles ally notes;
    // here we cover the stage that's computed inside this function.
    //
    // Notes include the *specific* weather / terrain / aura / ruin
    // (not generic "날씨" / "필드") so the 결정력 popup names the
    // exact effect — e.g. "쾌청 ×1.5" rather than "날씨 ×1.5".
    if (notesOut != null) {
      if (ruin.atkMod != 1.0) {
        // Tablets of Ruin = physical Atk reduction;
        // Vessel of Ruin = special SpA reduction.
        // ruin.atkMod is shared across both — pick the right one by
        // move category so the popup names the actual ability.
        final ruinKind = move.category == MoveCategory.physical
            ? 'tablets' : 'vessel';
        notesOut.add('ruin:$ruinKind:${_fmtMul(ruin.atkMod)}');
      }
      if (stabMult != 1.0) {
        final stabKey = isTeraStab
            ? (isOriginalStab ? 'stab:tera:matching' : 'stab:tera:nonmatching')
            : (terastallized && teraType == PokemonType.stellar
                ? (isOriginalStab ? 'stab:stellar:matching' : 'stab:stellar:nonmatching')
                : 'stab');
        notesOut.add('$stabKey:${_fmtMul(stabMult)}');
      }
      // Tera 60 위력 보정 is *already* baked into the slot's
      // displayed BP (getMoveSlotInfo bumps effectivePower to 60),
      // so listing it as a separate breakdown line would just
      // repeat what the user already sees in the move row.
      if (critMult != 1.0) notesOut.add('crit:${_fmtMul(critMult)}');
      if (weatherMod != 1.0) {
        // Use the Weather enum's `.name` so the renderer maps it to
        // the existing weatherKo / weatherEn / weatherJa tables.
        notesOut.add('weather:offensive:${weather.name}:${_fmtMul(weatherMod)}');
      }
      if (terrainMod != 1.0) {
        notesOut.add('terrain:offensive:${terrain.name}:${_fmtMul(terrainMod)}');
      }
      if (burnMod != 1.0) notesOut.add('burn:${_fmtMul(burnMod)}');
      if (parentalBondMod != 1.0) {
        notesOut.add('move:parental_bond:${_fmtMul(parentalBondMod)}');
      }
      if (aura.multiplier != 1.0) {
        // Fairy Aura / Dark Aura → ×1.33 on matching type;
        // Aura Break → ×0.75. Move type tells us which aura fired
        // (multiplier sign disambiguates Aura Break from Aura).
        final auraKind = aura.multiplier < 1.0
            ? 'break'
            : (move.type == PokemonType.fairy ? 'fairy' : 'dark');
        notesOut.add('aura:$auraKind:${_fmtMul(aura.multiplier)}');
      }
      // doublesAttackMod / doublesPowerMod aren't broken out here —
      // the individual `move:helpingHand`, `move:battery`, …
      // entries are added by `_calcOffensivePower` from
      // `doublesMods.notes` so we get specific ability names.
    }

    return raw.floor();
  }
}

/// Format a multiplier as `×<value>` for the 결정력 breakdown notes.
/// Trims trailing zeros so 1.5 reads as `×1.5` and 4/3 reads as `×1.33`.
/// Shared between offensive_calculator and battle_facade — exposed
/// so callers that emit notes get the same readable format.
String formatNoteMul(double v) {
  if (v == v.truncateToDouble()) return '×${v.toInt()}';
  var s = v.toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return '×$s';
}

/// Private alias kept for the in-file uses above so the existing
/// emit sites read concisely.
String _fmtMul(double v) => formatNoteMul(v);
