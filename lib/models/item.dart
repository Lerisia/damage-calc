/// A held item
class Item {
  final String name;
  final String nameKo;
  final String nameJa;
  final bool battle;

  const Item({
    required this.name,
    required this.nameKo,
    required this.nameJa,
    this.battle = false,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      name: json['name'] as String,
      nameKo: json['nameKo'] as String,
      nameJa: json['nameJa'] as String,
      battle: json['battle'] as bool? ?? false,
    );
  }
}
