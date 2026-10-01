import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How a search picker lays out its results.
enum PickerViewMode { list, grid }

/// How many recent picks each picker kind remembers.
const int kPickerRecentsCap = 12;

/// [id] moved (or added) to the front of [recents], capped at [cap].
/// Empty ids — the "no item" entry — are never recorded.
List<String> pushRecent(List<String> recents, String id,
    {int cap = kPickerRecentsCap}) {
  if (id.isEmpty) return recents;
  return [id, ...recents.where((r) => r != id)].take(cap).toList();
}

/// Per-kind preferences of the search picker modal: the list / grid
/// choice and the recent picks. "Kind" is the picker's namespace
/// (`pokemon`, `item`, …) — every field of the same kind shares one
/// history, whichever screen it sits on.
///
/// Persisted like the other display preferences; loaded once at
/// startup so the modal opens without an async gap.
class SearchPickerPrefs {
  SearchPickerPrefs._();
  static final SearchPickerPrefs instance = SearchPickerPrefs._();

  static const _viewPrefix = 'picker.view.';
  static const _recentsPrefix = 'picker.recents.';

  final Map<String, PickerViewMode> _views = {};
  final Map<String, List<String>> _recents = {};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _views.clear();
    _recents.clear();
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_viewPrefix)) {
        final saved = prefs.getString(key);
        for (final m in PickerViewMode.values) {
          if (m.name == saved) _views[key.substring(_viewPrefix.length)] = m;
        }
      } else if (key.startsWith(_recentsPrefix)) {
        _recents[key.substring(_recentsPrefix.length)] =
            prefs.getStringList(key) ?? const [];
      }
    }
  }

  PickerViewMode viewMode(String kind, {required PickerViewMode fallback}) =>
      _views[kind] ?? fallback;

  Future<void> setViewMode(String kind, PickerViewMode mode) async {
    if (_views[kind] == mode) return;
    _views[kind] = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_viewPrefix$kind', mode.name);
  }

  /// Most recent first.
  List<String> recents(String kind) =>
      List.unmodifiable(_recents[kind] ?? const <String>[]);

  Future<void> addRecent(String kind, String id) async {
    final before = _recents[kind] ?? const <String>[];
    final after = pushRecent(before, id);
    if (listEquals(before, after)) return;
    _recents[kind] = after;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_recentsPrefix$kind', after);
  }
}
