import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_strings.dart';
import '../../utils/page_routes.dart';
import '../dex_screen.dart' show DexScreen;
import '../move_dex_screen.dart' show MoveDexScreen;
import '../team_coverage_screen.dart' show TeamCoverageScreen;

/// Indices for the bottom-nav tabs — each top-level screen passes the
/// one that identifies it so the bar can highlight the active tab and
/// no-op on re-tap of the same destination.
enum AppNavTab { calc, dex, moveDex, teamBuilder }

const _kCollapsedKey = 'bottom_nav_collapsed_v1';

/// Collapsible bottom navigation bar shared by Calculator / Pokédex /
/// Move Dex / Team Builder. Pure-stateless from a navigation standpoint:
/// the host screen passes [currentTab] and the bar drives routing via
/// the standard Navigator stack.
///
/// Routing model (mirrors the user-confirmed design):
///   * Calculator is the always-alive root. Navigating to it from any
///     other screen pops back to the first route (so calc state is
///     preserved automatically by the widget tree).
///   * Non-calc destinations are pushed on top of calc. Navigating
///     between non-calc screens uses pushReplacement so the back stack
///     never grows beyond [calc, currentNonCalcScreen].
///   * Re-tapping the active tab is a no-op (avoids accidental
///     teardown of the user's in-flight state).
///
/// Collapse:
///   * Persistent SharedPreferences flag — survives app restart.
///   * Collapsed state shows a 16-px strip with just the chevron, so
///     the entry point is always visible (no "where did the menu go?"
///     dead-end).
class AppBottomNav extends StatefulWidget {
  final AppNavTab currentTab;

  const AppBottomNav({super.key, required this.currentTab});

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  bool _collapsed = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadCollapsed();
  }

  Future<void> _loadCollapsed() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _collapsed = prefs.getBool(_kCollapsedKey) ?? false;
      _loaded = true;
    });
  }

  Future<void> _toggleCollapsed() async {
    setState(() => _collapsed = !_collapsed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCollapsedKey, _collapsed);
  }

  void _onTabTapped(AppNavTab target) {
    if (target == widget.currentTab) return;
    final nav = Navigator.of(context);
    switch (target) {
      case AppNavTab.calc:
        // Calc is always at the bottom of the stack — popping until
        // first route restores it with all its state intact.
        nav.popUntil((r) => r.isFirst);
      case AppNavTab.dex:
        _pushDestination(const DexScreen());
      case AppNavTab.moveDex:
        _pushDestination(const MoveDexScreen());
      case AppNavTab.teamBuilder:
        _pushDestination(const TeamCoverageScreen());
    }
  }

  void _pushDestination(Widget screen) {
    final nav = Navigator.of(context);
    final route = fadeRoute((_) => screen);
    if (widget.currentTab == AppNavTab.calc) {
      // From calc: push on top so a back-button gesture takes the user
      // back to the calc (which is the conventional Android pattern).
      nav.push(route);
    } else {
      // Non-calc → non-calc: replace so we never stack a chain of
      // sibling screens. The back-button still leads back to calc.
      nav.pushReplacement(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox(height: 16);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _collapsed ? _collapsedStrip() : _expandedBar(),
        ),
      ),
    );
  }

  /// Thin always-visible strip when collapsed — chevron only, full
  /// width so it remains a 44-px tap target despite looking slim.
  Widget _collapsedStrip() {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: _toggleCollapsed,
      child: SizedBox(
        height: 16,
        width: double.infinity,
        child: Center(
          child: Icon(Icons.keyboard_arrow_up,
              size: 16,
              color: scheme.onSurface.withValues(alpha: 0.6)),
        ),
      ),
    );
  }

  Widget _expandedBar() {
    return Row(
      children: [
        Expanded(
          child: _tabButton(AppNavTab.calc, Icons.calculate,
              AppStrings.t('nav.calc')),
        ),
        Expanded(
          child: _tabButton(AppNavTab.dex, Icons.catching_pokemon,
              AppStrings.t('nav.dex')),
        ),
        Expanded(
          child: _tabButton(AppNavTab.moveDex, Icons.menu_book,
              AppStrings.t('nav.moveDex')),
        ),
        Expanded(
          child: _tabButton(AppNavTab.teamBuilder, Icons.groups,
              AppStrings.t('nav.teamBuilder')),
        ),
        // Collapse chevron — small dedicated tap area so it doesn't
        // compete with the tab buttons for accidental presses.
        SizedBox(
          width: 36,
          child: IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            onPressed: _toggleCollapsed,
            tooltip: '접기', // intentionally Korean per app convention
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _tabButton(AppNavTab tab, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    final selected = tab == widget.currentTab;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: () => _onTabTapped(tab),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }
}
