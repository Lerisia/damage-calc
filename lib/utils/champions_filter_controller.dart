import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global "show Champions Pokémon only" toggle, shared across the
/// Pokémon Dex's species selector and the Move Dex's learners list.
/// Persisted between launches like the other display preferences.
class ChampionsFilterController {
  ChampionsFilterController._();
  static final ChampionsFilterController instance =
      ChampionsFilterController._();

  static const _prefsKey = 'dexChampionsOnly';
  // Bumped from 'dexScopePromptShown' to 'dexScopeModePromptShown'
  // when the prompt grew a second question (simple/extended mode).
  // The key rename effectively re-prompts every user who only
  // answered the scope-only version of the dialog.
  static const _promptKey = 'dexScopeModePromptShown';

  /// Defaults to on — the calc's primary audience plays Pokémon
  /// Champions, so first-launch users see the Champions-only roster
  /// by default. Anyone who wants the full Pokédex can flip the
  /// toggle off and the choice is persisted.
  final ValueNotifier<bool> championsOnly = ValueNotifier<bool>(true);

  /// True once the user has answered the first-launch
  /// "Champions only / all Pokémon" prompt. Existing users count as
  /// "not answered yet" so they see the prompt once on the next
  /// launch — the user explicitly asked to surface it to everyone.
  bool _promptShown = false;
  bool get promptShown => _promptShown;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    championsOnly.value = prefs.getBool(_prefsKey) ?? true;
    _promptShown = prefs.getBool(_promptKey) ?? false;
  }

  Future<void> set(bool v) async {
    if (championsOnly.value == v) return;
    championsOnly.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, v);
  }

  /// Persist the answer to the first-launch prompt. Sets both the
  /// scope value and the prompt-shown flag in one round-trip so
  /// the dialog doesn't pop again on the next launch.
  Future<void> answerPrompt({required bool championsOnlyChoice}) async {
    championsOnly.value = championsOnlyChoice;
    _promptShown = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, championsOnlyChoice);
    await prefs.setBool(_promptKey, true);
  }
}
