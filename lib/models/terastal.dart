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
}
