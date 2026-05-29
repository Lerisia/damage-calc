import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'sprite_service.dart';

/// Latest sprite-pack revision this app build expects on disk.
///
/// Bumped in lockstep with PACK_VERSION in the damage-calc-sprite-pack
/// repo when shipping content the app needs (new shinies, new Pokémon,
/// etc.). The app has no network permission on mobile, so it can't
/// fetch this from anywhere — the value travels with the binary.
///
/// The install-time VERSION marker extracted from the ZIP is compared
/// against this constant by [SpritePackManager.isAnyOutOfDate]; any
/// mismatch (including the legacy `null` case for pre-marker
/// installs) triggers the update-nag dialog on app launch.
const String kLatestSpritePackVersion = '1';

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

  /// Version stamp of each style's currently-installed pack. `null`
  /// means either the style isn't installed or the installed ZIP
  /// pre-dates the VERSION-marker rollout (legacy installs from
  /// before the sprite-pack repo started embedding PACK_VERSION).
  /// Both cases count as "out of date" against any current
  /// [kLatestSpritePackVersion].
  final Map<SpriteStyle, String?> _versions = {
    for (final s in SpriteStyle.values) s: null,
  };

  bool isInstalled(SpriteStyle style) => _installed[style] ?? false;

  String? installedVersion(SpriteStyle style) => _versions[style];

  /// Any style installed at all. Used by the update-nag trigger to
  /// skip users who haven't onboarded onto a pack yet — they're
  /// already in pokéball mode and a "your pack is out of date" nag
  /// would be confusing.
  bool get hasAnyInstalled =>
      SpriteStyle.values.any((s) => isInstalled(s));

  /// True if any installed style's stored VERSION differs from
  /// [latest] — including the legacy null case where no marker was
  /// ever written. Returns false when nothing is installed (the nag
  /// shouldn't fire for first-time users; that's the job of the
  /// install banner inside the style dialog).
  bool isAnyOutOfDate(String latest) {
    for (final s in SpriteStyle.values) {
      if (!isInstalled(s)) continue;
      if (_versions[s] != latest) return true;
    }
    return false;
  }

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

  /// Where extracted trainer sprites live. Mirrors [iconsCacheDir]
  /// — flat folder of `<key>.png` files written by the combined
  /// pack importer. Returns null on web (the trainer-card dialog
  /// hits Showdown's CDN directly there).
  String? get trainerCacheDir {
    final r = _rootDir;
    if (r == null) return null;
    return '${r.path}/trainers';
  }

  bool _trainersInstalled = false;
  bool get trainersInstalled => _trainersInstalled;

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
      final hasFiles = dir.existsSync() &&
          dir.listSync().any((e) => e is File);
      _installed[s] = hasFiles;
      if (hasFiles) {
        // VERSION is written by [installFromZip] alongside the
        // sprites; a missing file means a legacy pack from before
        // the marker rollout, kept as null so [isAnyOutOfDate]
        // treats it as stale.
        final versionFile = File('${dir.path}/VERSION');
        if (versionFile.existsSync()) {
          _versions[s] = versionFile.readAsStringSync().trim();
        }
      } else {
        _versions[s] = null;
      }
    }
    final iconsDir = Directory('${_rootDir!.path}/icons');
    _iconsInstalled =
        iconsDir.existsSync() && iconsDir.listSync().any((e) => e is File);
    final trainersDir = Directory('${_rootDir!.path}/trainers');
    _trainersInstalled = trainersDir.existsSync() &&
        trainersDir.listSync().any((e) => e is File);
    notifyListeners();
  }

  /// Extract a combined-pack ZIP that may carry sprites for multiple
  /// categories at once — `gen5/`, `gen5/shiny/`, `dex/`, `dex/shiny/`,
  /// `pokemonicons/`, `trainers/` — into the matching per-category
  /// cache directory. Produced by the JS download page at
  /// damage-calc.com/dl.html which fetches each sprite from
  /// Showdown's CDN in the user's browser and zips them up locally;
  /// we never host the bytes ourselves.
  ///
  /// Returns a per-category written count so the UI can confirm what
  /// landed. Throws on a non-ZIP input.
  Future<Map<String, int>> installCombinedPack(File zipFile) async {
    if (kIsWeb) {
      throw StateError('Combined-pack import is not used on web — the '
          'web build reads from Showdown CDN directly.');
    }
    if (_rootDir == null) await init();
    final root = _rootDir!.path;
    final bytes = await zipFile.readAsBytes();
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('Not a ZIP archive');
    }
    // Map of zip-path-prefix → on-disk target dir.
    final categoryTargets = <String, String>{
      'gen5/shiny/': '$root/bw/shiny',
      'gen5/': '$root/bw',
      'dex/shiny/': '$root/dex/shiny',
      'dex/': '$root/dex',
      'pokemonicons/': '$root/icons',
      'trainers/': '$root/trainers',
    };
    // Pre-create + clear target dirs so a re-import doesn't leave
    // stale files from a previous pack.
    for (final target in categoryTargets.values.toSet()) {
      final d = Directory(target);
      if (d.existsSync()) d.deleteSync(recursive: true);
      d.createSync(recursive: true);
    }
    final counts = <String, int>{};
    String? packVersion;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      if (name == 'VERSION') {
        packVersion =
            String.fromCharCodes(entry.content as List<int>).trim();
        continue;
      }
      String? targetDir;
      String? rel;
      // Match against the longest prefix first (gen5/shiny/ before
      // gen5/) so the shiny subfolder isn't swallowed by the
      // top-level category.
      for (final prefix in categoryTargets.keys) {
        if (name.startsWith(prefix)) {
          targetDir = categoryTargets[prefix];
          rel = name.substring(prefix.length);
          break;
        }
      }
      if (targetDir == null || rel == null || rel.isEmpty) continue;
      if (rel.contains('/')) continue; // skip any deeper nesting
      if (!rel.toLowerCase().endsWith('.png') &&
          !rel.toLowerCase().endsWith('.gif')) continue;
      File('$targetDir/$rel').writeAsBytesSync(entry.content as List<int>);
      counts[targetDir] = (counts[targetDir] ?? 0) + 1;
    }
    // Reflect new install state. BW + dex map onto SpriteStyle enum
    // entries; icons + trainers flip their own booleans.
    for (final s in SpriteStyle.values) {
      final dir = Directory('$root/${s.name}');
      if (dir.existsSync() && dir.listSync().any((e) => e is File)) {
        _installed[s] = true;
        if (packVersion != null) {
          _versions[s] = packVersion;
          File('${dir.path}/VERSION').writeAsStringSync(packVersion);
        }
      }
    }
    final iconsDir = Directory('$root/icons');
    _iconsInstalled =
        iconsDir.existsSync() && iconsDir.listSync().any((e) => e is File);
    final trainersDir = Directory('$root/trainers');
    _trainersInstalled = trainersDir.existsSync() &&
        trainersDir.listSync().any((e) => e is File);
    notifyListeners();
    return counts;
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
    String? packVersion;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      if (name.isEmpty) continue;
      // Top-level VERSION marker — captured here, written to the
      // style cache dir below once we know the install hasn't been
      // rolled back for a 0-sprite ZIP.
      if (name == 'VERSION') {
        packVersion =
            String.fromCharCodes(entry.content as List<int>).trim();
        continue;
      }
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
      // Shiny variants ship inside the same per-style ZIP under
      // shiny/<key>.png — extract to <styleCacheDir>/shiny/<key>.png
      // so SpriteService.spriteFor(..., shiny: true) finds them at
      // the matching path. Without this branch the generic
      // `name.contains('/')` skip below silently drops every shiny
      // file during install, which is why pre-fix pack imports
      // succeeded but shiny mode still rendered as pokéballs.
      if (name.startsWith('shiny/')) {
        final flat = name.substring('shiny/'.length);
        if (flat.isEmpty || flat.contains('/')) continue;
        if (!flat.toLowerCase().endsWith('.${style.ext}')) continue;
        final shinyDir = Directory('${target.path}/shiny');
        if (!shinyDir.existsSync()) {
          shinyDir.createSync(recursive: true);
        }
        File('${shinyDir.path}/$flat')
            .writeAsBytesSync(entry.content as List<int>);
        styleWritten++;
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
    if (packVersion != null) {
      File('${target.path}/VERSION').writeAsStringSync('$packVersion\n');
      _versions[style] = packVersion;
    } else {
      // Pre-marker ZIP — clear any stale stamp from a previous
      // install so [isAnyOutOfDate] sees this style as stale.
      final stale = File('${target.path}/VERSION');
      if (stale.existsSync()) stale.deleteSync();
      _versions[style] = null;
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
    _versions[style] = null;
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
