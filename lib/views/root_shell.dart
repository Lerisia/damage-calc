import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/page_routes.dart';
import 'damage_calculator_screen.dart';
import 'dex_screen.dart';
import 'move_dex_screen.dart';
import 'team_coverage_screen.dart';
import 'widgets/app_bottom_nav.dart';
import 'widgets/lazy_indexed_stack.dart';

/// Single host for the four bottom-nav tabs. Each tab owns its own
/// nested [Navigator]; tab switches are index swaps on an
/// [LazyIndexedStack], so every tab's full widget State — selection,
/// search, scroll, filters, pushed detail routes — survives
/// arbitrary back-and-forth between tabs. Only Calc is built on
/// startup; the other three lazy-build on first activation.
///
/// Replaces the previous per-screen `Scaffold.bottomNavigationBar:
/// AppBottomNav(...)` pattern, where switching tabs went through
/// `Navigator.push`/`pushReplacement` on the root navigator and
/// destroyed the outgoing screen's State.
class RootShell extends StatefulWidget {
  final Map<String, String> abilityNameMap;
  final Map<String, String> itemNameMap;

  const RootShell({
    super.key,
    required this.abilityNameMap,
    required this.itemNameMap,
  });

  static RootShellState of(BuildContext context) {
    final state = context.findAncestorStateOfType<RootShellState>();
    assert(state != null,
        'RootShell.of() called outside a RootShell — screen must be mounted under RootShell.');
    return state!;
  }

  /// Soft variant for code that may run outside a RootShell context
  /// (e.g. when DexScreen is opened as a modal picker via the root
  /// navigator). Returns null when no RootShell is in scope.
  static RootShellState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<RootShellState>();

  @override
  State<RootShell> createState() => RootShellState();
}

class RootShellState extends State<RootShell> {
  AppNavTab _current = AppNavTab.calc;
  // Tabs that have ever been activated. Calc is in from the start;
  // others enter on first setTab so LazyIndexedStack swaps the
  // placeholder for the real Navigator subtree.
  final Set<AppNavTab> _built = {AppNavTab.calc};
  final Map<AppNavTab, GlobalKey<NavigatorState>> _navKeys = {
    for (final t in AppNavTab.values) t: GlobalKey<NavigatorState>(),
  };

  AppNavTab get currentTab => _current;

  /// Set the active tab. Re-tapping the active tab pops that tab's
  /// nested stack to its root (iOS tab-bar convention) — replaces
  /// the old `Navigator.popUntil((r) => r.isFirst)` pattern from
  /// AppBottomNav at the root level.
  void setTab(AppNavTab t) {
    if (_current == t) {
      _navKeys[t]!.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() {
      _built.add(t);
      _current = t;
    });
  }

  /// Cross-tab nav to the Pokédex detail of [pokemonName]. Switches
  /// to the dex tab and pushes the detail on its nested navigator
  /// after the frame commits (so the navigator exists if the tab
  /// was just lazy-built). `fromList: true` so the detail's wide-
  /// only back arrow pops back to the dex list route underneath.
  void requestDexDetail(String pokemonName) => _crossTab(
        AppNavTab.dex,
        (_) => DexScreen(initialPokemonName: pokemonName, fromList: true),
      );

  /// Cross-tab nav to the Move Dex detail of [moveName]. Same
  /// pattern as [requestDexDetail].
  void requestMoveDexDetail(String moveName) => _crossTab(
        AppNavTab.moveDex,
        (_) => MoveDexScreen(initialMoveName: moveName),
      );

  void _crossTab(AppNavTab t, WidgetBuilder builder) {
    setState(() {
      _built.add(t);
      _current = t;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navKeys[t]!.currentState?.push(fadeRoute(builder));
    });
  }

  /// Calc's "open dex to pick a pokémon" flow. The picker is a modal
  /// dex push on the ROOT navigator (above the IndexedStack), not a
  /// tab switch — the user expects to return to calc with the picked
  /// [DexPickResult], not land on the dex tab. The dex tab's own
  /// state stays untouched by this overlay.
  Future<DexPickResult?> openDexAsPicker({String? initialName}) {
    return Navigator.of(context, rootNavigator: true).push<DexPickResult>(
      fadeRoute<DexPickResult>(
        (_) => DexScreen(initialPokemonName: initialName),
      ),
    );
  }

  Widget _buildTabNavigator(AppNavTab t) {
    return Navigator(
      key: _navKeys[t],
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) => _rootScreenFor(t),
      ),
    );
  }

  Widget _rootScreenFor(AppNavTab t) {
    switch (t) {
      case AppNavTab.calc:
        return DamageCalculatorScreen(
          abilityNameMap: widget.abilityNameMap,
          itemNameMap: widget.itemNameMap,
        );
      case AppNavTab.dex:
        return const DexScreen();
      case AppNavTab.moveDex:
        return const MoveDexScreen();
      case AppNavTab.teamBuilder:
        return const TeamCoverageScreen();
    }
  }

  Future<bool> _handleSystemBack() async {
    // 1. If the active tab's nested navigator can pop, pop it.
    final nav = _navKeys[_current]!.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return false; // consumed
    }
    // 2. If not on calc, fall back to calc (Android convention:
    // back from any non-root tab returns to the root tab before
    // exiting the app).
    if (_current != AppNavTab.calc) {
      setTab(AppNavTab.calc);
      return false; // consumed
    }
    // 3. On calc with nothing to pop → allow app exit.
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // canPop: false so PopScope always forwards the back gesture to
      // us via onPopInvokedWithResult; we then decide whether to
      // consume it (pop nested nav / switch tab) or allow the app to
      // exit by re-invoking the system pop ourselves.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _handleSystemBack();
        if (shouldExit && mounted) {
          // No more in-app navigation to consume → exit the app on
          // mobile. On web/desktop this is a no-op which is fine.
          if (!kIsWeb) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        body: LazyIndexedStack(
          index: _current.index,
          built: [for (final t in AppNavTab.values) _built.contains(t)],
          builders: [for (final t in AppNavTab.values) (_) => _buildTabNavigator(t)],
        ),
        bottomNavigationBar: const AppBottomNav(),
      ),
    );
  }
}
