import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/pokedex.dart';
import '../../models/pokemon.dart';
import '../../utils/app_strings.dart';
import '../../utils/sprite_override_manager.dart';
import '../../utils/sprite_service.dart';
import 'pokemon_selector.dart';

/// Open the per-Pokémon sprite override manager.
Future<void> showSpriteOverrideDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const SpriteOverrideDialog(),
  );
}

/// Per-Pokémon sprite override manager. Mobile-only — on web the
/// menu entry isn't even shown. Users tap '포켓몬 추가' to add a
/// row for a Pokémon, then upload a custom large and / or small
/// image. Overrides win regardless of which sprite style is
/// currently active.
class SpriteOverrideDialog extends StatefulWidget {
  const SpriteOverrideDialog({super.key});

  @override
  State<SpriteOverrideDialog> createState() => _SpriteOverrideDialogState();
}

class _SpriteOverrideDialogState extends State<SpriteOverrideDialog> {
  /// Pokémon the user has explicitly added in THIS session, even if
  /// they haven't uploaded an image yet. Combined with whatever's
  /// already on disk so the row stays put after picking but before
  /// any slot's been filled.
  final List<String> _sessionPicks = [];
  List<Pokemon> _allPokemon = const [];

  @override
  void initState() {
    super.initState();
    loadPokedex().then((list) {
      if (!mounted) return;
      setState(() => _allPokemon = list);
    });
  }

  /// Resolve a sprite key back to the Pokémon entry — for label
  /// rendering when the row was hydrated from disk on startup.
  Pokemon? _findByKey(String key) {
    for (final p in _allPokemon) {
      if (spriteKeyFor(p.name) == key) return p;
    }
    return null;
  }

  Future<void> _addPokemon() async {
    final picked = await showDialog<Pokemon>(
      context: context,
      builder: (ctx) {
        Pokemon? localPick;
        return AlertDialog(
          title: Text(AppStrings.t('sprite.override.add')),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          content: SizedBox(
            width: 320,
            child: PokemonSelector(
              initialPokemonName: null,
              onSelected: (p) => localPick = p,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(AppStrings.t('action.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, localPick),
              child: Text(AppStrings.t('action.confirm')),
            ),
          ],
        );
      },
    );
    if (picked == null || !mounted) return;
    if (!_sessionPicks.contains(picked.name)) {
      setState(() => _sessionPicks.add(picked.name));
    }
  }

  Future<void> _pickAndSet(String pokemonName, OverrideChannel channel) async {
    try {
      // image_picker uses PHPicker on iOS 14+ (no NSPhotoLibrary
      // permission required), the system gallery on Android, and
      // an HTML <input type="file"> on web. In every case we read
      // the bytes via XFile.readAsBytes() and hand them to the
      // override manager, which picks the right backend (disk file
      // on mobile, base64-in-prefs on web).
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final name = picked.name;
      final dot = name.lastIndexOf('.');
      final ext = dot > 0 ? name.substring(dot + 1).toLowerCase() : 'png';
      await SpriteOverrideManager.instance
          .setOverride(pokemonName, channel, bytes: bytes, ext: ext);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t('sprite.importFailed')
            .replaceAll('{err}', e.toString())),
        duration: const Duration(seconds: 4),
      ));
    }
  }

  Widget _slot({
    required String pokemonName,
    required OverrideChannel channel,
    required double size,
  }) {
    final Uint8List? bytes = SpriteOverrideManager.instance
        .overrideBytes(pokemonName, channel);
    final hasOverride = bytes != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _pickAndSet(pokemonName, channel),
          onLongPress: !hasOverride
              ? null
              : () => SpriteOverrideManager.instance
                  .clearOverride(pokemonName, channel),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border.all(
                color: !hasOverride
                    ? Theme.of(context).hintColor.withValues(alpha: 0.4)
                    : Colors.green.withValues(alpha: 0.6),
                width: hasOverride ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(6),
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
            ),
            child: !hasOverride
                ? Icon(Icons.add_photo_alternate_outlined,
                    size: size * 0.5,
                    color: Theme.of(context).hintColor)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    // Key on a length+hash proxy so a replaced
                    // upload swaps the displayed thumbnail instead
                    // of sticking on the cached version.
                    child: Image.memory(
                      bytes,
                      key: ValueKey(
                          'override-${pokemonName}-${channel.name}-${bytes.length}'),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          channel == OverrideChannel.large
              ? AppStrings.t('sprite.override.large')
              : AppStrings.t('sprite.override.small'),
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).hintColor,
          ),
        ),
      ],
    );
  }

  Widget _row(String pokemonName) {
    // Resolve a display name from the loaded pokedex; fall back to
    // the English name when the pokedex hasn't streamed in yet
    // (only the first frame after dialog open).
    final p = _findByKey(spriteKeyFor(pokemonName));
    final displayName = p?.localizedName ?? pokemonName;
    final hasAny = SpriteOverrideManager.instance
                .overrideBytes(pokemonName, OverrideChannel.large) !=
            null ||
        SpriteOverrideManager.instance
                .overrideBytes(pokemonName, OverrideChannel.small) !=
            null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (!hasAny)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      AppStrings.t('sprite.override.tapToUpload'),
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).hintColor),
                    ),
                  ),
              ],
            ),
          ),
          _slot(
              pokemonName: pokemonName,
              channel: OverrideChannel.large,
              size: 48),
          const SizedBox(width: 8),
          _slot(
              pokemonName: pokemonName,
              channel: OverrideChannel.small,
              size: 48),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            tooltip: AppStrings.t('sprite.override.removeRow'),
            icon: const Icon(Icons.close),
            onPressed: () async {
              // Wipe both channels' files, then drop from session list.
              await SpriteOverrideManager.instance
                  .clearOverride(pokemonName, OverrideChannel.large);
              await SpriteOverrideManager.instance
                  .clearOverride(pokemonName, OverrideChannel.small);
              if (mounted) {
                setState(() => _sessionPicks.remove(pokemonName));
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fixed content size — the dialog stays the same shape whether
    // the user has zero overrides or fifty. The list itself scrolls
    // internally, so adding rows never pushes the dialog out of the
    // viewport or rearranges the surrounding UI.
    final mq = MediaQuery.of(context).size;
    final width = (mq.width - 80).clamp(280.0, 400.0);
    final height = (mq.height * 0.6).clamp(360.0, 520.0);
    final hint = Theme.of(context).hintColor;
    return AlertDialog(
      title: Text(AppStrings.t('sprite.override.title')),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      content: SizedBox(
        width: width,
        height: height,
        child: ListenableBuilder(
          listenable: SpriteOverrideManager.instance,
          builder: (ctx, _) {
            final fromDisk = SpriteOverrideManager.instance
                .overriddenSpriteKeys()
                .map((k) => _findByKey(k)?.name ?? k)
                .toList();
            final all = <String>{...fromDisk, ..._sessionPicks}.toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    AppStrings.t('sprite.override.howTo'),
                    style: TextStyle(
                        fontSize: 12, color: hint, height: 1.4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: OutlinedButton.icon(
                    onPressed: _addPokemon,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(AppStrings.t('sprite.override.add')),
                  ),
                ),
                const SizedBox(height: 8),
                // The list region always fills the remaining dialog
                // height — Expanded over Flexible so the empty-state
                // message is centred in a constant frame instead of
                // a tiny floating block.
                Expanded(
                  child: all.isEmpty
                      ? Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              AppStrings.t('sprite.override.empty'),
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(fontSize: 12, color: hint),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: all.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) => _row(all[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.t('action.close')),
        ),
      ],
    );
  }
}

