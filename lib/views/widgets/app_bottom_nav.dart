import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_strings.dart';
import '../root_shell.dart';

/// Indices for the bottom-nav tabs — each top-level screen is one
/// AppNavTab slot in the [RootShell]'s LazyIndexedStack.
enum AppNavTab { calc, dex, moveDex, teamBuilder }

const _kCollapsedKey = 'bottom_nav_collapsed_v1';

/// Collapsible bottom navigation bar — lives at the [RootShell]
/// level (single mount point), not per-screen. Reads the active tab
/// from `RootShell.of(context).currentTab` and routes taps through
/// `RootShell.of(context).setTab(...)`, which swaps the IndexedStack
/// index instead of pushing routes — this is what preserves each
/// tab's full widget State across switches.
///
/// Collapse: persistent SharedPreferences flag — survives app
/// restart. Collapsed shows a 16-px chevron strip so the entry point
/// stays visible.
class AppBottomNav extends StatefulWidget {
  const AppBottomNav({super.key});

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

  /// Max content width for the bar's tabs. On wide screens (web,
  /// tablet landscape, desktop) the 4 tabs would otherwise stretch
  /// across the full window with ~500 px between each label, which
  /// reads as broken. Cap at 720 px and centre — the bar's Material
  /// chrome (surface colour, elevation) still spans the full width,
  /// only the tab Row stays bounded.
  static const double _maxBarContentWidth = 720;

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox(height: 16);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        // Centre + LayoutBuilder + SizedBox is the bulletproof way
        // to cap the interactive content width. The previous
        // Center+ConstrainedBox-inside-AnimatedSize approach left
        // the Row with Expanded children unbounded, so it stretched
        // full-screen on wide windows.
        child: Center(
          child: LayoutBuilder(
            builder: (ctx, c) {
              final w = c.maxWidth.clamp(0.0, _maxBarContentWidth);
              return SizedBox(
                width: w,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _collapsed ? _collapsedStrip() : _expandedBar(),
                ),
              );
            },
          ),
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
    // Width cap is handled by the outer LayoutBuilder + SizedBox in
    // [build]. This Row just fills whatever bounded width it gets.
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
    final shell = RootShell.of(context);
    final scheme = Theme.of(context).colorScheme;
    final selected = tab == shell.currentTab;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: () => shell.setTab(tab),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pill-shaped active indicator behind the icon —
            // Material 3 NavigationBar convention. Color/weight on
            // their own were too subtle for users to register
            // 'this is the current tab', so we add the tinted
            // background. Transparent for non-selected so the
            // surrounding Row keeps consistent dimensions.
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color:
                    selected ? scheme.primary.withValues(alpha: 0.14) : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
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
