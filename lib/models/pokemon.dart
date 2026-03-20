import 'type.dart';
import 'stats.dart';

/// A Pokemon species definition
class Pokemon {
  final int dexNumber;
  final String name;
  final String nameKo;
  final String nameJa;
  final PokemonType type1;
  final PokemonType? type2;
  final Stats baseStats;
  final List<String> abilities;
  final double weight; // in kg
  final double height; // in m
  final bool finalEvo;
  final String? requiredItem;

  const Pokemon({
    required this.dexNumber,
    required this.name,
    required this.nameKo,
    required this.nameJa,
    required this.type1,
    this.type2,
    required this.baseStats,
    required this.abilities,
    required this.weight,
    required this.height,
    this.finalEvo = true,
    this.requiredItem,
  });

  /// Create a Pokemon from a JSON map
  factory Pokemon.fromJson(Map<String, dynamic> json) {
    return Pokemon(
      dexNumber: json['dexNumber'] as int,
      name: json['name'] as String,
      nameKo: json['nameKo'] as String,
      nameJa: json['nameJa'] as String,
      type1: PokemonType.values.byName(json['type1'] as String),
      type2: json['type2'] != null
          ? PokemonType.values.byName(json['type2'] as String)
          : null,
      baseStats: Stats.fromJson(json['baseStats'] as Map<String, dynamic>),
      abilities: List<String>.from(json['abilities'] as List),
      weight: (json['weight'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      finalEvo: json['finalEvo'] as bool? ?? true,
      requiredItem: json['requiredItem'] as String?,
    );
  }
}
