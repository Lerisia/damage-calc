/// Six-stat structure used for base stats, IVs, and EVs
class Stats {
  final int hp;
  final int attack;
  final int defense;
  final int spAttack;
  final int spDefense;
  final int speed;

  const Stats({
    required this.hp,
    required this.attack,
    required this.defense,
    required this.spAttack,
    required this.spDefense,
    required this.speed,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      hp: json['hp'] as int,
      attack: json['attack'] as int,
      defense: json['defense'] as int,
      spAttack: json['spAttack'] as int,
      spDefense: json['spDefense'] as int,
      speed: json['speed'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'hp': hp,
    'attack': attack,
    'defense': defense,
    'spAttack': spAttack,
    'spDefense': spDefense,
    'speed': speed,
  };
}
