import 'dart:io';
import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:path_provider/path_provider.dart';

import 'sprite_service.dart';

/// Channel for a per-Pokémon override: [large] is what
/// PokemonSprite renders in the calc panels and dex header, [small]
/// is what useBoxIcon placements (dex list / simple-mode row) show.
enum OverrideChannel { large, small }

/// Per-Pokémon user-supplied sprite overrides, mobile-only.
///
/// The user can upload one custom image per Pokémon per channel
/// (large / small) — they sit on top of the imported sprite-pack
/// cache so the override wins regardless of which style the user
/// has selected. Files live under
/// `<docs>/sprite_packs/overrides/<channel>/<spriteKey>.<ext>`,
/// each <ext> is whatever the user imported (PNG / JPG / GIF —
/// Flutter's Image widget handles all three).
///
/// Singleton ChangeNotifier so the dialog UI and SpriteService's
/// per-frame reads stay in sync. Web is a no-op (the web build
/// streams sprites from Showdown's CDN; there's no on-device
/// override surface to give the user there).
class SpriteOverrideManager extends ChangeNotifier {
  SpriteOverrideManager._();
  static final SpriteOverrideManager instance = SpriteOverrideManager._();

  Directory? _rootDir;

  /// Cached map: (channel, spriteKey) → File on disk. Refreshed on
  /// init() and after each set / clear, so SpriteService's lookup
  /// stays a cheap map read instead of an FS stat per frame.
  final Map<OverrideChannel, Map<String, File>> _overrides = {
    OverrideChannel.large: {},
    OverrideChannel.small: {},
  };

  Future<void> init() async {
    if (kIsWeb) return;
    final docs = await getApplicationDocumentsDirectory();
    _rootDir = Directory('${docs.path}/sprite_packs/overrides')
      ..createSync(recursive: true);
    for (final channel in OverrideChannel.values) {
      final dir = Directory('${_rootDir!.path}/${channel.name}');
      _overrides[channel]!.clear();
      if (!dir.existsSync()) continue;
      for (final entry in dir.listSync()) {
        if (entry is! File) continue;
        // Filename is '<spriteKey>.<ext>' — strip any extension to
        // recover the key. Multiple extensions for the same key are
        // resolved by keeping whichever came last in listSync (the
        // user can only set one at a time so duplicates shouldn't
        // happen in practice, but guard anyway).
        final base = entry.uri.pathSegments.last;
        final dot = base.lastIndexOf('.');
        if (dot <= 0) continue;
        _overrides[channel]![base.substring(0, dot)] = entry;
      }
    }
    notifyListeners();
  }

  /// Override file for [pokemonName] on [channel], or null when the
  /// user hasn't set one.
  File? overrideFor(String pokemonName, OverrideChannel channel) {
    final key = spriteKeyFor(pokemonName);
    return _overrides[channel]![key];
  }

  /// Copy a user-picked image into the overrides cache under the
  /// derived sprite key. Replaces any prior override on the same
  /// (channel, name). Returns the persisted File so the dialog
  /// can preview it.
  Future<File> setOverride(
      String pokemonName, OverrideChannel channel, File source) async {
    if (kIsWeb) {
      throw StateError('Sprite overrides are mobile-only.');
    }
    if (_rootDir == null) await init();
    final key = spriteKeyFor(pokemonName);
    final dir = Directory('${_rootDir!.path}/${channel.name}')
      ..createSync(recursive: true);
    // Drop any prior file for this key on this channel first — the
    // extension may differ between the old and new override.
    for (final entry in dir.listSync()) {
      if (entry is! File) continue;
      final base = entry.uri.pathSegments.last;
      final dot = base.lastIndexOf('.');
      if (dot > 0 && base.substring(0, dot) == key) entry.deleteSync();
    }
    final srcName = source.uri.pathSegments.last;
    final dot = srcName.lastIndexOf('.');
    final ext = dot > 0 ? srcName.substring(dot + 1).toLowerCase() : 'png';
    final dst = File('${dir.path}/$key.$ext');
    await source.copy(dst.path);
    _overrides[channel]![key] = dst;
    notifyListeners();
    return dst;
  }

  Future<void> clearOverride(
      String pokemonName, OverrideChannel channel) async {
    if (kIsWeb || _rootDir == null) return;
    final key = spriteKeyFor(pokemonName);
    final file = _overrides[channel]!.remove(key);
    if (file != null && file.existsSync()) file.deleteSync();
    notifyListeners();
  }

  /// Distinct Pokémon names (by sprite key) that have at least one
  /// override on either channel. The UI lists these so the user can
  /// see and manage their existing customisations.
  Set<String> overriddenSpriteKeys() {
    return {
      ..._overrides[OverrideChannel.large]!.keys,
      ..._overrides[OverrideChannel.small]!.keys,
    };
  }

  /// Wipe every override on every channel — used by the dialog's
  /// 'reset all overrides' affordance if we ever add one.
  Future<void> clearAll() async {
    if (kIsWeb || _rootDir == null) return;
    for (final channel in OverrideChannel.values) {
      final dir = Directory('${_rootDir!.path}/${channel.name}');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      _overrides[channel]!.clear();
    }
    notifyListeners();
  }
}
