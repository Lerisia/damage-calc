import 'type.dart';

/// Physical, special, or status
enum MoveCategory {
  physical,
  special,
  status,
}

/// A Pokemon move
class Move {
  final String name;
  final String nameKo;
  final String nameJa;
  final PokemonType type;
  final MoveCategory category;
  final int power;
  final int accuracy;
  final int pp;
  final List<String> tags;

  const Move({
    required this.name,
    required this.nameKo,
    required this.nameJa,
    required this.type,
    required this.category,
    required this.power,
    required this.accuracy,
    required this.pp,
    this.tags = const [],
  });

  bool hasTag(String tag) => tags.contains(tag);

  Move copyWith({
    PokemonType? type,
    int? power,
  }) {
    return Move(
      name: name,
      nameKo: nameKo,
      nameJa: nameJa,
      type: type ?? this.type,
      category: category,
      power: power ?? this.power,
      accuracy: accuracy,
      pp: pp,
      tags: tags,
    );
  }

  factory Move.fromJson(Map<String, dynamic> json) {
    return Move(
      name: json['name'] as String,
      nameKo: json['nameKo'] as String,
      nameJa: json['nameJa'] as String,
      type: PokemonType.values.byName(json['type'] as String),
      category: MoveCategory.values.byName(json['category'] as String),
      power: json['power'] as int,
      accuracy: json['accuracy'] as int,
      pp: json['pp'] as int,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : const [],
    );
  }
}
