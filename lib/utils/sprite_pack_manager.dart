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
/// Each style ZIP also nests gen1-7 box icons under an `icons/`
/// subdir; the installer extracts those into a shared icons cache
/// in the same pass so the user never manages "icons" as a separate
/// download.
///
/// Lives as a singleton so the import-status UI and SpriteService's
/// per-frame `spriteFor()` reads share one source of truth. Extends
/// ChangeNotifier so the import dialog rebuilds the moment an install
/// finishes.
class SpritePackManager extends ChangeNotifier {
  SpritePackManager._();
  static final SpritePackManager instance = SpritePackManager._();

  Directory? _rootDir;

  final Map<SpriteStyle, bool> _installed = {
    for (final s in SpriteStyle.values) s: false,
  };

  bool isInstalled(SpriteStyle style) => _installed[style] ?? false;

  bool _iconsInstalled = false;
  bool get iconsInstalled => _iconsInstalled;

  String? cacheDirFor(SpriteStyle style) {
    final r = _rootDir;
    if (r == null) return null;
    return '${r.path}/${style.name}';
  }

  String? get iconsCacheDir {
    final r = _rootDir;
    if (r == null) return null;
    return '${r.path}/icons';
  }

  /// Probe the FS to refresh install state. Called from app preload
  /// so SpriteService.spriteFor returns FileImages immediately on
  /// the first frame, not after an async dance.
  Future<void> init() async {
    if (kIsWeb) return;
    final docs = await getApplicationDocumentsDirectory();
    _rootDir = Directory('${docs.path}/sprite_packs')
      ..createSync(recursive: true);
    for (final s in SpriteStyle.values) {
      final dir = Directory('${_rootDir!.path}/${s.name}');
      _installed[s] = dir.existsSync() &&
          dir.listSync().any((e) => e is File);
    }
    final iconsDir = Directory('${_rootDir!.path}/icons');
    _iconsInstalled =
        iconsDir.existsSync() && iconsDir.listSync().any((e) => e is File);
    notifyListeners();
  }

  /// Extract a downloaded sprite-pack ZIP into the per-style cache,
  /// plus any nested icons/ block into the shared icons cache.
  /// Returns the count of style-sprite files written. Throws when
  /// the ZIP holds zero matching style sprites (wrong pack chosen).
  Future<int> installFromZip(File zipFile, SpriteStyle style) async {
    if (kIsWeb) {
      throw StateError('Sprite-pack import is not used on web — the '
          'web build reads from Showdown CDN directly.');
    }
    if (_rootDir == null) await init();
    final target = Directory('${_rootDir!.path}/${style.name}');
    if (target.existsSync()) target.deleteSync(recursive: true);
    target.createSync(recursive: true);
    final iconsTarget = Directory('${_rootDir!.path}/icons');
    bool zipHasIcons = false;

    final bytes = await zipFile.readAsBytes();
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('Not a ZIP archive');
    }
    var styleWritten = 0;
    var iconsWritten = 0;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      if (name.isEmpty) continue;
      if (name.startsWith('icons/')) {
        if (!zipHasIcons) {
          if (iconsTarget.existsSync()) iconsTarget.deleteSync(recursive: true);
          iconsTarget.createSync(recursive: true);
          zipHasIcons = true;
        }
        final flat = name.substring('icons/'.length);
        if (flat.isEmpty || flat.contains('/')) continue;
        if (!flat.toLowerCase().endsWith('.png')) continue;
        File('${iconsTarget.path}/$flat')
            .writeAsBytesSync(entry.content as List<int>);
        iconsWritten++;
        continue;
      }
      if (name.contains('/')) continue;
      if (!name.toLowerCase().endsWith('.${style.ext}')) continue;
      File('${target.path}/$name')
          .writeAsBytesSync(entry.content as List<int>);
      styleWritten++;
    }
    if (styleWritten == 0) {
      target.deleteSync(recursive: true);
      throw const FormatException(
          'No matching sprite files found in archive');
    }
    _installed[style] = true;
    if (iconsWritten > 0) _iconsInstalled = true;
    notifyListeners();
    return styleWritten;
  }

  Future<void> clear(SpriteStyle style) async {
    if (kIsWeb || _rootDir == null) return;
    final dir = Directory('${_rootDir!.path}/${style.name}');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    _installed[style] = false;
    notifyListeners();
  }

  Future<void> clearIcons() async {
    if (kIsWeb || _rootDir == null) return;
    final dir = Directory('${_rootDir!.path}/icons');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    _iconsInstalled = false;
    notifyListeners();
  }
}
