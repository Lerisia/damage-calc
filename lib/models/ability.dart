import '../utils/app_strings.dart';

/// A Pokemon ability
class Ability {
  final String name;
  final String nameKo;
  final String nameJa;
  final String? nameEn;

  const Ability({
    required this.name,
    required this.nameKo,
    required this.nameJa,
    this.nameEn,
  });

  String get localizedName => AppStrings.name(nameKo: nameKo, nameEn: nameEn, nameJa: nameJa, name: name);

  factory Ability.fromJson(Map<String, dynamic> json) {
    return Ability(
      name: json['name'] as String,
      nameKo: json['nameKo'] as String,
      nameJa: json['nameJa'] as String,
      nameEn: json['nameEn'] as String?,
    );
  }
}
