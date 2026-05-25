import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'sprite_service.dart';

/// Per-style sprite-pack install state for mobile.
///
/// The damage-calc app ships no Pokémon sprites in its binary
/// (deliberate IP hygiene — see SpriteService doc). On mobile, the
/// user can optionally download a pack from
/// github.com/Lerisia/damage-calc-sprite-pack/releases/latest and
/// import the ZIP file; we extract it to a per-style cache directory
/// under the OS's application-documents path. Once installed, the
/// directory persists across launches and the sprite slots that
/// used to show a pokéball start rendering imported sprites.
///
/// Lives as a singleton so the import-status UI and SpriteService's
/// per-frame `spriteFor()` reads share one source of truth. Extends
/// ChangeNotifier so the import dialog rebuilds the moment an install
/// finishes.
class SpritePackManager extends ChangeNotifier {
  SpritePackManager._();
  static final SpritePackManager instance = SpritePackManager._();

  /// Cached `<docs>/sprite_packs` directory — populated lazily on
  /// first use. Web never touches the filesystem (the web build
  /// reads sprites straight from the Showdown CDN), so it stays null.
  Directory? _rootDir;

  /// Per-style install state, cached so the UI doesn't hit the FS
  /// every paint. Refreshed inside `init()` and after install/clear.
  final Map<SpriteStyle, bool> _installed = {
    for (final s in SpriteStyle.values) s: false,
  };

  bool isInstalled(SpriteStyle style) => _installed[style] ?? false;

  /// Absolute path to the on-disk directory holding extracted sprites
  /// for [style], or null if we haven't initialised yet / on web.
  String? cacheDirFor(SpriteStyle style) {
    final r = _rootDir;
    if (r == null) return null;
    return '${r.path}/${style.name}';
  }

  /// Probe the FS to refresh [_installed]. Called from app preload so
  /// SpriteService.spriteFor returns AssetImages immediately on the
  /// first frame, not after an async dance.
  Future<void> init() async {
    if (kIsWeb) return;
    final docs = await getApplicationDocumentsDirectory();
    _rootDir = Directory('${docs.path}/sprite_packs')
      ..createSync(recursive: true);
    for (final s in SpriteStyle.values) {
      final dir = Directory('${_rootDir!.path}/${s.name}');
      // 'installed' = directory exists and holds at least one file.
      // Empty dirs can be left by a half-failed extract; treat them
      // as not-installed so the user can retry without 'clear' first.
      _installed[s] = dir.existsSync() &&
          dir.listSync().any((e) => e is File);
    }
    notifyListeners();
  }

  /// Extract a downloaded sprite-pack ZIP into the per-style cache
  /// directory, replacing whatever's there.
  ///
  /// The ZIP is expected to contain flat-laid `<key>.png` / `.gif`
  /// files at top level — that's the format produced by
  /// damage-calc-sprite-pack's nightly workflow. Any nested
  /// directories or files matching neither extension are ignored.
  ///
  /// Returns the count of sprite files written. Throws if the ZIP is
  /// unreadable or empty so the caller can surface a clear error.
  Future<int> installFromZip(File zipFile, SpriteStyle style) async {
    if (kIsWeb) {
      throw StateError('Sprite-pack import is not used on web — the '
          'web build reads from Showdown CDN directly.');
    }
    if (_rootDir == null) await init();
    final target = Directory('${_rootDir!.path}/${style.name}');
    if (target.existsSync()) target.deleteSync(recursive: true);
    target.createSync(recursive: true);

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    var written = 0;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      // Take only top-level image files in the expected style ext.
      // Different ZIP toolchains produce '/'-separated paths.
      final flat = name.split('/').last;
      if (flat.isEmpty) continue;
      final ext = style.ext;
      if (!flat.toLowerCase().endsWith('.$ext')) continue;
      final out = File('${target.path}/$flat');
      out.writeAsBytesSync(entry.content as List<int>);
      written++;
    }
    if (written == 0) {
      // Wrong-pack-for-style is the common failure case (user picked
      // ani.zip while installing bw, etc.). Wipe the empty dir so
      // isInstalled stays false.
      target.deleteSync(recursive: true);
      throw const FormatException(
          'No matching sprite files found in archive');
    }
    _installed[style] = true;
    notifyListeners();
    return written;
  }

  /// Remove the on-disk cache for one style — used by the 'reset
  /// pack' affordance in the style picker dialog.
  Future<void> clear(SpriteStyle style) async {
    if (kIsWeb || _rootDir == null) return;
    final dir = Directory('${_rootDir!.path}/${style.name}');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    _installed[style] = false;
    notifyListeners();
  }
}
