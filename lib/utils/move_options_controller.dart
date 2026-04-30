import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the move-search dropdown should surface status-category
/// moves (Protect, Roost, Toxic, …). Off by default — players who only
/// damage-calc rarely care about them, and a 4-slot move panel feels
/// cluttered when status moves crowd the suggestions. Persisted across
/// launches like the other display preferences.
class MoveOptionsController {
  MoveOptionsController._();
  static final MoveOptionsController instance = MoveOptionsController._();

  static const _showStatusKey = 'moveSelectorShowStatus';

  final ValueNotifier<bool> showStatusMoves = ValueNotifier<bool>(false);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    showStatusMoves.value = prefs.getBool(_showStatusKey) ?? false;
  }

  Future<void> setShowStatusMoves(bool v) async {
    if (showStatusMoves.value == v) return;
    showStatusMoves.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showStatusKey, v);
  }
}
