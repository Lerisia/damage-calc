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

  /// Box-icon pack install state — separate channel from the visual
  /// styles. Icons are gen7-style box-UI art (40×30 px) used in the
  /// dex list / simple-mode rows; they're not interchangeable with
  /// BW / ani / HOME sprites, they're an *additional* asset.
  bool _iconsInstalled = false;
  bool get iconsInstalled => _iconsInstalled;

  /// Absolute path to the on-disk directory holding extracted sprites
  /// for [style], or null if we haven't initialised yet / on web.
  String? cacheDirFor(SpriteStyle style) {
    final r = _rootDir;
    if (r == null) return null;
    return '${r.path}/${style.name}';
  }

  /// Absolute path to the box-icons cache directory, or null when
  /// pre-init / on web.
  String? get iconsCacheDir {
    final r = _rootDir;
    if (r == null) return null;
    return '${r.path}/icons';
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
    final iconsDir = Directory('${_rootDir!.path}/icons');
    _iconsInstalled =
        iconsDir.existsSync() && iconsDir.listSync().any((e) => e is File);
    notifyListeners();
  }

  /// Extract a downloaded sprite-pack ZIP into the per-style cache
  /// directory, replacing whatever's there. A nested `icons/`
  /// subdirectory inside the ZIP — bundled by every style pack the
  /// damage-calc-sprite-pack workflow publishes — is extracted into
  /// the shared icons cache in the same call, so the user only ever
  /// imports one ZIP per style and box icons come along for free.
  ///
  /// The ZIP is expected to contain flat-laid `<key>.png` / `.gif`
  /// files at top level for the style itself, optionally plus
  /// `icons/<key>.png` for the bundled gen1-7 box icons.
  ///
  /// Returns the count of style-sprite files written (icons are
  /// extracted alongside but not counted in the return value —
  /// callers can read [iconsInstalled] after this completes). Throws
  /// when the ZIP holds zero matching style sprites (wrong pack
  /// chosen for this style).
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
    // Only replace the icons cache when this ZIP actually contains
    // an icons block — otherwise an older ZIP without icons would
    // wipe out the user's already-installed icons.
    bool zipHasIcons = false;

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    var styleWritten = 0;
    var iconsWritten = 0;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      if (name.isEmpty) continue;
      if (name.startsWith('icons/')) {
        // Nested icons block: gen1-7 box icons, always .png.
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
      // Top-level style sprites only — ignore any other subdirectory.
      if (name.contains('/')) continue;
      if (!name.toLowerCase().endsWith('.${style.ext}')) continue;
      File('${target.path}/$name')
          .writeAsBytesSync(entry.content as List<int>);
      styleWritten++;
    }
    if (styleWritten == 0) {
      // Wrong-pack-for-style is the common failure case (user picked
      // dex.zip while installing bw, etc.). Wipe the empty dir so
      // isInstalled stays false; leave any icons block alone (it
      // was the right pack at least for icons).
      target.deleteSync(recursive: true);
      throw const FormatException(
          'No matching sprite files found in archive');
    }
    _installed[style] = true;
    if (iconsWritten > 0) _iconsInstalled = true;
    notifyListeners();
    return styleWritten;
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

  Future<void> clearIcons() async {
    if (kIsWeb || _rootDir == null) return;
    final dir = Directory('${_rootDir!.path}/icons');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    _iconsInstalled = false;
    notifyListeners();
  }
}
