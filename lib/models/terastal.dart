import 'type.dart';

/// Terastal state of a Pokemon
class TerastalState {
  final bool active;
  final PokemonType? teraType; // null = not selected

  const TerastalState({this.active = false, this.teraType});

  TerastalState copyWith({bool? active, PokemonType? teraType}) {
    return TerastalState(
      active: active ?? this.active,
      teraType: teraType ?? this.teraType,
    );
  }

  /// Whether this is a "Stellar" type terastal
  bool get isStellar => active && teraType == PokemonType.stellar;

  Map<String, dynamic> toJson() => {
    'active': active,
    'teraType': teraType?.name,
  };

  factory TerastalState.fromJson(Map<String, dynamic> json) {
    return TerastalState(
      active: json['active'] as bool? ?? false,
      teraType: json['teraType'] != null
          ? PokemonType.values.byName(json['teraType'] as String)
          : null,
    );
  }
}
