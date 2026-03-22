import 'type.dart';

/// Physical, special, or status
enum MoveCategory {
  physical,
  special,
  status,
}

/// Regular, Z-move, or Max move
enum MoveClass {
  normal,
  zMove,
  maxMove,
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
  final MoveClass moveClass;
  final List<String> tags;
  final int priority;

  const Move({
    required this.name,
    required this.nameKo,
    required this.nameJa,
    required this.type,
    required this.category,
    required this.power,
    required this.accuracy,
    required this.pp,
    this.moveClass = MoveClass.normal,
    this.tags = const [],
    this.priority = 0,
  });

  bool hasTag(String tag) => tags.contains(tag);

  /// Whether this move has positive priority (선공기).
  bool get isPriority => priority > 0;

  Move copyWith({
    String? name,
    String? nameKo,
    String? nameJa,
    PokemonType? type,
    MoveCategory? category,
    int? power,
    MoveClass? moveClass,
    List<String>? tags,
    int? priority,
  }) {
    return Move(
      name: name ?? this.name,
      nameKo: nameKo ?? this.nameKo,
      nameJa: nameJa ?? this.nameJa,
      type: type ?? this.type,
      category: category ?? this.category,
      power: power ?? this.power,
      accuracy: accuracy,
      pp: pp,
      moveClass: moveClass ?? this.moveClass,
      tags: tags ?? this.tags,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'nameKo': nameKo,
    'nameJa': nameJa,
    'type': type.name,
    'category': category.name,
    'power': power,
    'accuracy': accuracy,
    'pp': pp,
    'moveClass': moveClass.name,
    'tags': tags,
    'priority': priority,
  };

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
      moveClass: json['moveClass'] != null
          ? MoveClass.values.byName(json['moveClass'] as String)
          : MoveClass.normal,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : const [],
      priority: json['priority'] as int? ?? 0,
    );
  }
}
