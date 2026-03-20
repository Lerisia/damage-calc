/// Stat stage modifiers (-6 to +6) for each battle stat (excludes HP).
///
/// Positive stages: multiplier = (2 + stage) / 2
/// Negative stages: multiplier = 2 / (2 + |stage|)
class Rank {
  final int attack;
  final int defense;
  final int spAttack;
  final int spDefense;
  final int speed;

  const Rank({
    int attack = 0,
    int defense = 0,
    int spAttack = 0,
    int spDefense = 0,
    int speed = 0,
  })  : attack = attack > 6 ? 6 : (attack < -6 ? -6 : attack),
        defense = defense > 6 ? 6 : (defense < -6 ? -6 : defense),
        spAttack = spAttack > 6 ? 6 : (spAttack < -6 ? -6 : spAttack),
        spDefense = spDefense > 6 ? 6 : (spDefense < -6 ? -6 : spDefense),
        speed = speed > 6 ? 6 : (speed < -6 ? -6 : speed);

  double get attackMultiplier => multiplier(attack);
  double get defenseMultiplier => multiplier(defense);
  double get spAttackMultiplier => multiplier(spAttack);
  double get spDefenseMultiplier => multiplier(spDefense);
  double get speedMultiplier => multiplier(speed);

  static double multiplier(int stage) {
    if (stage >= 0) {
      return (2 + stage) / 2;
    } else {
      return 2 / (2 + stage.abs());
    }
  }
}
