import '../utils/app_strings.dart';

/// A held item
class Item {
  final String name;
  final String nameKo;
  final String nameJa;
  final String? nameEn;
  final bool battle;

  const Item({
    required this.name,
    required this.nameKo,
    required this.nameJa,
    this.nameEn,
    this.battle = false,
  });

  String get localizedName => AppStrings.name(nameKo: nameKo, nameEn: nameEn, nameJa: nameJa, name: name);

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      name: json['name'] as String,
      nameKo: json['nameKo'] as String,
      nameJa: json['nameJa'] as String,
      nameEn: json['nameEn'] as String?,
      battle: json['battle'] as bool? ?? false,
    );
  }
}
