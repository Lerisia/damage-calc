import '../utils/app_strings.dart';

/// A Pokemon ability
class Ability {
  final String name;
  final String nameKo;
  final String nameJa;
  final String? nameEn;

  /// True for abilities that exist only in spin-off titles (Colosseum,
  /// the mobile games, etc.) and aren't found in mainline damage
  /// calcs. They still need to exist in the dex so that looking them
  /// up by key never returns null, but the ability picker must hide
  /// them — otherwise users stumble into them mid-battle.
  final bool nonMainline;

  const Ability({
    required this.name,
    required this.nameKo,
    required this.nameJa,
    this.nameEn,
    this.nonMainline = false,
  });

  String get localizedName => AppStrings.name(nameKo: nameKo, nameEn: nameEn, nameJa: nameJa, name: name);

  factory Ability.fromJson(Map<String, dynamic> json) {
    return Ability(
      name: json['name'] as String,
      nameKo: json['nameKo'] as String,
      nameJa: json['nameJa'] as String,
      nameEn: json['nameEn'] as String?,
      nonMainline: json['nonMainline'] as bool? ?? false,
    );
  }
}
