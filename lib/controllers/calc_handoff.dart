import 'package:flutter/foundation.dart';
import '../models/battle_pokemon.dart';

/// One-shot inbox used by surfaces outside the calculator (team
/// builder slot popup → "공격측으로 / 방어측으로", future dex hand-off
/// etc.) to push a fully-built [BattlePokemonState] into the
/// calc's attacker or defender slot. The calculator listens on
/// [CalcHandoff.instance], copies the payload into its own
/// per-side state, and clears the inbox via [consume].
///
/// Why not a route argument: the calc isn't pushed onto the stack
/// — it lives at the root. Sibling screens (team builder, dex) sit
/// above it and have to pop back via `popUntil((r) => r.isFirst)`.
/// A static notifier is the simplest cross-route channel, mirrors
/// what [_TeamCoverageStore] already does for party state, and
/// avoids reaching into the calc widget tree.
class CalcHandoff extends ChangeNotifier {
  CalcHandoff._();
  static final CalcHandoff instance = CalcHandoff._();

  ({
    int side,
    BattlePokemonState state,
    String? loadedSampleName,
  })? _pending;

  /// Drop a payload into the inbox and notify the calc's listener.
  /// The state is consumed verbatim — callers are responsible for
  /// building it (e.g. team builder copies slot.ability / item /
  /// ev / nature / moves / shiny in already).
  void stage({
    required int side,
    required BattlePokemonState state,
    String? loadedSampleName,
  }) {
    _pending = (
      side: side,
      state: state,
      loadedSampleName: loadedSampleName,
    );
    notifyListeners();
  }

  /// Atomically read + clear the pending payload. Returns null when
  /// the inbox is empty (typical first build, or a duplicate listener
  /// invocation that already consumed).
  ({
    int side,
    BattlePokemonState state,
    String? loadedSampleName,
  })? consume() {
    final p = _pending;
    _pending = null;
    return p;
  }
}
