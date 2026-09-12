import '../utils/app_strings.dart';

/// A held item
class Item {
  final String name;
  final String nameKo;
  final String nameJa;
  final String? nameEn;

  /// True for items a Pokémon can hold to some effect in battle — the
  /// ones the item pickers offer. Candies, Poké Balls, medicine and
  /// the like are false. This says nothing about Champions legality;
  /// see `isChampionsItem` for that.
  final bool held;

  const Item({
    required this.name,
    required this.nameKo,
    required this.nameJa,
    this.nameEn,
    this.held = false,
  });

  String get localizedName => AppStrings.name(nameKo: nameKo, nameEn: nameEn, nameJa: nameJa, name: name);

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      name: json['name'] as String,
      nameKo: json['nameKo'] as String,
      nameJa: json['nameJa'] as String,
      nameEn: json['nameEn'] as String?,
      held: json['held'] as bool? ?? false,
    );
  }
}
