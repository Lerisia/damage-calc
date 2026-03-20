/// A Pokemon ability
class Ability {
  final String name;
  final String nameKo;
  final String nameJa;

  const Ability({
    required this.name,
    required this.nameKo,
    required this.nameJa,
  });

  factory Ability.fromJson(Map<String, dynamic> json) {
    return Ability(
      name: json['name'] as String,
      nameKo: json['nameKo'] as String,
      nameJa: json['nameJa'] as String,
    );
  }
}
