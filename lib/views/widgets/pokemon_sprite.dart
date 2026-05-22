import 'package:flutter/material.dart';

import '../../utils/sprite_service.dart';

/// Shows a Pokémon's box-style sprite icon.
///
/// Falls back to a neutral placeholder whenever the sprite is
/// unavailable — before the sprite pack has been downloaded, offline, or
/// for Champions-original forms that have no Showdown sprite. The
/// calculator never depends on sprites being present.
class PokemonSprite extends StatelessWidget {
  /// English species name — the sprite key is derived from this.
  final String pokemonName;

  /// Edge length of the (square) sprite slot in logical pixels.
  final double size;

  const PokemonSprite({
    super.key,
    required this.pokemonName,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    final provider = SpriteService.instance.iconFor(pokemonName);
    if (provider == null) return _placeholder();
    return Image(
      image: provider,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() => SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.catching_pokemon,
          size: size * 0.8,
          color: Colors.grey.shade300,
        ),
      );
}
