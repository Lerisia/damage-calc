import 'dart:convert' show base64Decode, base64Encode;
import 'dart:io' show Directory, File;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:flutter/widgets.dart' show FileImage, ImageProvider, MemoryImage;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sprite_service.dart';

enum OverrideChannel { large, small }

/// Per-Pokémon sprite override storage. Mobile keeps a File on
/// disk under `<docs>/sprite_packs/overrides/<channel>/<key>.<ext>`;
/// web base64-encodes the picked image bytes into shared_preferences
/// (backed by localStorage) so the same dialog code paths work on
/// both platforms.
///
/// Mobile storage is unbounded by app design. Web storage is
/// bounded by localStorage's per-origin quota (~5 MB on most
/// browsers); a handful of compressed PNGs / JPEGs fits, but a
/// huge upload will throw. The setter surfaces that error so the
/// dialog can snack-bar it.
class SpriteOverrideManager extends ChangeNotifier {
  SpriteOverrideManager._();
  static final SpriteOverrideManager instance = SpriteOverrideManager._();

  /// Mobile only — disk root.
  Directory? _rootDir;

  /// Mobile: key → File on disk for each channel.
  /// Web: key → in-memory Uint8List (rehydrated from prefs on init,
  /// re-saved on set / clear).
  final Map<OverrideChannel, Map<String, File>> _fileOverrides = {
    OverrideChannel.large: {},
    OverrideChannel.small: {},
  };
  final Map<OverrideChannel, Map<String, Uint8List>> _bytesOverrides = {
    OverrideChannel.large: {},
    OverrideChannel.small: {},
  };

  String _prefsKey(OverrideChannel channel, String spriteKey) =>
      'sprite_override_${channel.name}_$spriteKey';

  Future<void> init() async {
    if (kIsWeb) {
      await _initWeb();
    } else {
      await _initMobile();
    }
    notifyListeners();
  }

  Future<void> _initMobile() async {
    final docs = await getApplicationDocumentsDirectory();
    _rootDir = Directory('${docs.path}/sprite_packs/overrides')
      ..createSync(recursive: true);
    for (final channel in OverrideChannel.values) {
      final dir = Directory('${_rootDir!.path}/${channel.name}');
      _fileOverrides[channel]!.clear();
      if (!dir.existsSync()) continue;
      for (final entry in dir.listSync()) {
        if (entry is! File) continue;
        final base = entry.uri.pathSegments.last;
        final dot = base.lastIndexOf('.');
        if (dot <= 0) continue;
        _fileOverrides[channel]![base.substring(0, dot)] = entry;
      }
    }
  }

  Future<void> _initWeb() async {
    final prefs = await SharedPreferences.getInstance();
    for (final channel in OverrideChannel.values) {
      _bytesOverrides[channel]!.clear();
    }
    for (final k in prefs.getKeys()) {
      if (!k.startsWith('sprite_override_')) continue;
      // Format: sprite_override_<channel>_<spriteKey>
      final tail = k.substring('sprite_override_'.length);
      OverrideChannel? matchedChannel;
      String? matchedKey;
      for (final c in OverrideChannel.values) {
        final prefix = '${c.name}_';
        if (tail.startsWith(prefix)) {
          matchedChannel = c;
          matchedKey = tail.substring(prefix.length);
          break;
        }
      }
      if (matchedChannel == null || matchedKey == null) continue;
      final encoded = prefs.getString(k);
      if (encoded == null) continue;
      try {
        _bytesOverrides[matchedChannel]![matchedKey] = base64Decode(encoded);
      } catch (_) {
        // Corrupted entry — silently skip; user can re-upload.
      }
    }
  }

  /// ImageProvider for a Pokémon's override on a channel, or null
  /// when the user hasn't set one. Same interface regardless of
  /// storage backend.
  ImageProvider? overrideFor(String pokemonName, OverrideChannel channel) {
    final key = spriteKeyFor(pokemonName);
    if (kIsWeb) {
      final bytes = _bytesOverrides[channel]![key];
      return bytes == null ? null : MemoryImage(bytes);
    }
    final file = _fileOverrides[channel]![key];
    return file == null ? null : FileImage(file);
  }

  /// Set an override. [bytes] is the raw image content the dialog
  /// reads from the picked XFile; [ext] is the original file
  /// extension (so mobile can name the on-disk file accurately).
  Future<void> setOverride(
    String pokemonName,
    OverrideChannel channel, {
    required Uint8List bytes,
    required String ext,
  }) async {
    final key = spriteKeyFor(pokemonName);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      try {
        await prefs.setString(_prefsKey(channel, key), base64Encode(bytes));
        _bytesOverrides[channel]![key] = bytes;
      } catch (e) {
        // QuotaExceededError when localStorage is full. Surface to
        // caller so it can snackbar the user.
        rethrow;
      }
    } else {
      if (_rootDir == null) await init();
      final dir = Directory('${_rootDir!.path}/${channel.name}')
        ..createSync(recursive: true);
      for (final entry in dir.listSync()) {
        if (entry is! File) continue;
        final base = entry.uri.pathSegments.last;
        final dot = base.lastIndexOf('.');
        if (dot > 0 && base.substring(0, dot) == key) entry.deleteSync();
      }
      final dst = File('${dir.path}/$key.$ext');
      await dst.writeAsBytes(bytes);
      _fileOverrides[channel]![key] = dst;
    }
    notifyListeners();
  }

  Future<void> clearOverride(
      String pokemonName, OverrideChannel channel) async {
    final key = spriteKeyFor(pokemonName);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey(channel, key));
      _bytesOverrides[channel]!.remove(key);
    } else {
      if (_rootDir == null) return;
      final file = _fileOverrides[channel]!.remove(key);
      if (file != null && file.existsSync()) file.deleteSync();
    }
    notifyListeners();
  }

  /// Sprite keys that have an override on either channel.
  Set<String> overriddenSpriteKeys() {
    if (kIsWeb) {
      return {
        ..._bytesOverrides[OverrideChannel.large]!.keys,
        ..._bytesOverrides[OverrideChannel.small]!.keys,
      };
    }
    return {
      ..._fileOverrides[OverrideChannel.large]!.keys,
      ..._fileOverrides[OverrideChannel.small]!.keys,
    };
  }

  /// Bytes for the override on this channel, or null. Used by the
  /// dialog's slot preview so it can show the just-uploaded image
  /// inline without re-reading a disk file the user can't see.
  Uint8List? overrideBytes(String pokemonName, OverrideChannel channel) {
    final key = spriteKeyFor(pokemonName);
    if (kIsWeb) return _bytesOverrides[channel]![key];
    final file = _fileOverrides[channel]![key];
    if (file == null) return null;
    try {
      return file.readAsBytesSync();
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().toList()) {
        if (k.startsWith('sprite_override_')) await prefs.remove(k);
      }
      for (final c in OverrideChannel.values) {
        _bytesOverrides[c]!.clear();
      }
    } else {
      if (_rootDir == null) return;
      for (final channel in OverrideChannel.values) {
        final dir = Directory('${_rootDir!.path}/${channel.name}');
        if (dir.existsSync()) dir.deleteSync(recursive: true);
        _fileOverrides[channel]!.clear();
      }
    }
    notifyListeners();
  }
}
