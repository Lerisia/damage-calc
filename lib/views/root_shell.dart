import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;

import '../utils/champions_format_controller.dart';
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

  /// Reactive lookup — registers an InheritedWidget dependency so
  /// the caller rebuilds whenever the active tab changes. Use this
  /// in widgets that visually depend on currentTab (e.g. the bottom
  /// nav's active-pill indicator). Call sites that only invoke
  /// methods (setTab, requestX) also work; they incur a minor
  /// subscription overhead but stay correct.
  static RootShellState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_RootShellScope>();
    assert(scope != null,
        'RootShell.of() called outside a RootShell — widget must be mounted under RootShell.');
    return scope!.state;
  }

  /// Soft variant for code that may run outside a RootShell context
  /// (e.g. when DexScreen is opened as a modal picker via the root
  /// navigator above the IndexedStack). Returns null when no
  /// RootShell is in scope. Non-reactive (no dependency).
  static RootShellState? maybeOf(BuildContext context) {
    final scope = context
        .getElementForInheritedWidgetOfExactType<_RootShellScope>()
        ?.widget as _RootShellScope?;
    return scope?.state;
  }

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

  @override
  void initState() {
    super.initState();
    // Flipping singles ↔ doubles changes every `championsUsageFor`
    // result downstream. Rebuilding the whole shell is the cheap fix:
    // build methods re-run, but the LazyIndexedStack's child State
    // objects (DexScreen, TeamCoverage, …) persist so search queries,
    // scroll positions, etc. survive the flip.
    ChampionsFormatController.instance.format.addListener(_onFormatChanged);
  }

  @override
  void dispose() {
    ChampionsFormatController.instance.format.removeListener(_onFormatChanged);
    super.dispose();
  }

  void _onFormatChanged() {
    if (mounted) setState(() {});
  }

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

  /// Returns true when there's nothing to consume in-app and the
  /// system back gesture should exit the app.
  bool _handleSystemBack() {
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
    return _RootShellScope(
      currentTab: _current,
      state: this,
      child: PopScope(
      // canPop: false so PopScope always forwards the back gesture to
      // us via onPopInvokedWithResult; we then decide whether to
      // consume it (pop nested nav / switch tab) or allow the app to
      // exit by re-invoking the system pop ourselves.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final shouldExit = _handleSystemBack();
        if (shouldExit && !kIsWeb) {
          // No more in-app navigation to consume → request system
          // pop (exits app on mobile). On web/desktop this is a
          // no-op which is fine.
          SystemNavigator.pop();
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
    ),
    );
  }
}

/// InheritedWidget that makes the active tab reactive. Without this
/// the bottom nav (whose widget config is const-stable) would never
/// rebuild on tab changes — its active-pill indicator would freeze
/// on whichever tab was active at first mount.
class _RootShellScope extends InheritedWidget {
  final AppNavTab currentTab;
  final RootShellState state;

  const _RootShellScope({
    required this.currentTab,
    required this.state,
    required super.child,
  });

  @override
  bool updateShouldNotify(_RootShellScope old) => old.currentTab != currentTab;
}
