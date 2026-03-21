import 'random_factor.dart';
import 'type_effectiveness.dart';
import '../models/type.dart';

/// Result of a damage calculation
class DamageResult {
  /// Offensive power (결정력) of the move
  final int offensivePower;

  /// Defensive bulk (내구) of the defender (physical or special)
  final int defensiveBulk;

  /// Type effectiveness multiplier
  final double effectiveness;

  /// Base damage before random factor: 결정력 / 내구력 * 상성
  final int baseDamage;

  /// Minimum damage (worst random roll, 85%)
  final int minDamage;

  /// Maximum damage (best random roll, 100%)
  final int maxDamage;

  /// Defender's actual HP
  final int defenderHp;

  /// Whether the move is physical or special
  final bool isPhysical;

  const DamageResult({
    required this.offensivePower,
    required this.defensiveBulk,
    required this.effectiveness,
    required this.baseDamage,
    required this.minDamage,
    required this.maxDamage,
    required this.defenderHp,
    required this.isPhysical,
  });

  /// Min damage as % of defender HP
  double get minPercent => defenderHp > 0 ? minDamage / defenderHp * 100 : 0;

  /// Max damage as % of defender HP
  double get maxPercent => defenderHp > 0 ? maxDamage / defenderHp * 100 : 0;

  /// How many of the 16 random rolls result in a 1-hit KO
  int get oneshotRolls => RandomFactor.koRolls(baseDamage, defenderHp);

  /// Label for 1-hit KO chance (확정/고난수/난수/저난수/null)
  String? get oneshotLabel => RandomFactor.koLabel(oneshotRolls);

  /// Minimum hits to KO (using max damage)
  int get hitsToKo => maxDamage > 0 ? (defenderHp / maxDamage).ceil() : 0;

  /// Is this result empty (no move set)
  bool get isEmpty => offensivePower == 0;
}

/// Calculates damage using 결정력 (offensive power) and 내구 (defensive bulk).
///
/// damage = 결정력 / 내구 * 상성 * 난수
class DamageCalculator {
  static DamageResult calculate({
    required int offensivePower,
    required int defensiveBulk,
    required PokemonType moveType,
    required PokemonType defType1,
    PokemonType? defType2,
    required int defenderHp,
    required bool isPhysical,
    bool defenderGrounded = true,
  }) {
    if (offensivePower == 0 || defensiveBulk == 0) {
      return DamageResult(
        offensivePower: offensivePower,
        defensiveBulk: defensiveBulk,
        effectiveness: 1.0,
        baseDamage: 0,
        minDamage: 0,
        maxDamage: 0,
        defenderHp: defenderHp,
        isPhysical: isPhysical,
      );
    }

    // Ground moves have no effect on non-grounded Pokemon
    if (moveType == PokemonType.ground && !defenderGrounded) {
      return DamageResult(
        offensivePower: offensivePower,
        defensiveBulk: defensiveBulk,
        effectiveness: 0.0,
        baseDamage: 0,
        minDamage: 0,
        maxDamage: 0,
        defenderHp: defenderHp,
        isPhysical: isPhysical,
      );
    }

    final effectiveness = getCombinedEffectiveness(moveType, defType1, defType2);

    if (effectiveness == 0.0) {
      return DamageResult(
        offensivePower: offensivePower,
        defensiveBulk: defensiveBulk,
        effectiveness: 0.0,
        baseDamage: 0,
        minDamage: 0,
        maxDamage: 0,
        defenderHp: defenderHp,
        isPhysical: isPhysical,
      );
    }

    // Base damage = HP * (결정력 / 내구) * 상성
    // When 결정력 == 내구, damage ≈ 50% of HP (at random 1.0)
    final int baseDamage = (defenderHp * offensivePower / defensiveBulk * effectiveness).floor();

    // Apply random factor (0.85 ~ 1.00)
    final range = RandomFactor.range(baseDamage);

    return DamageResult(
      offensivePower: offensivePower,
      defensiveBulk: defensiveBulk,
      effectiveness: effectiveness,
      baseDamage: baseDamage,
      minDamage: range.min,
      maxDamage: range.max,
      defenderHp: defenderHp,
      isPhysical: isPhysical,
    );
  }
}
