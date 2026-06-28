import 'package:flutter/material.dart';

import '../../utils/app_strings.dart';
import '../../utils/champions_filter_controller.dart';
import '../../utils/champions_format_controller.dart';
import '../../utils/theme_controller.dart';
import '../damage_calculator_screen.dart' show AppAboutDialog;
import 'champions_speed_tier_sheet.dart';
import 'champions_usage_rank_sheet.dart';
import 'sprite_style_dialog.dart';
import 'type_chart_sheet.dart';

/// Shared settings (⚙️) PopupMenuButton used by every top-level
/// screen (Calculator / Pokédex / Move Dex / Team Builder). Pulls
/// app-wide preferences out of per-screen overflow menus into a
/// single self-evident gear icon — the previous 3-dot icon was
/// ambiguous and only existed on the calculator.
///
/// All actions here are app-global:
///   * Language  (AppStrings.setLanguage)
///   * Dark mode (ThemeController.instance.toggle)
///   * Sprite style + pack management
///   * Champions-only filter (ChampionsFilterController) — used to
///     live in the Pokédex app bar; promoted to a global setting so
///     the calculator's PokémonSelector applies it too.
///   * About dialog
///
/// [onLanguageChanged] is called after the user picks a new language
/// so the host screen can [setState] to refresh its AppStrings.t()
/// reads. Hosts that own localized data caches (the calculator
/// reloads ability / item localized names) can rebuild those here.
class AppSettingsMenu extends StatelessWidget {
  final VoidCallback? onLanguageChanged;

  const AppSettingsMenu({super.key, this.onLanguageChanged});

  String _languageLabel() {
    const labels = {
      AppLanguage.ko: '🇰🇷 한국어',
      AppLanguage.en: '🇺🇸 English',
      AppLanguage.ja: '🇯🇵 日本語',
    };
    return labels[AppStrings.current]!;
  }

  void _showLanguageDialog(BuildContext context) {
    const langLabels = {
      AppLanguage.ko: '🇰🇷 한국어',
      AppLanguage.en: '🇺🇸 English',
      AppLanguage.ja: '🇯🇵 日本語',
    };
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('🌐'),
        children: AppLanguage.values
            .map((lang) => SimpleDialogOption(
                  onPressed: () {
                    AppStrings.setLanguage(lang);
                    Navigator.pop(ctx);
                    onLanguageChanged?.call();
                  },
                  child: Text(
                    langLabels[lang]!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: AppStrings.current == lang
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: AppStrings.current == lang
                          ? Theme.of(ctx).colorScheme.primary
                          : null,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // Listen on ChampionsFilterController so the toggle item's
      // checkmark reflects current state without each invocation
      // hand-wiring a ValueListenableBuilder.
      listenable: Listenable.merge([
        ChampionsFilterController.instance.championsOnly,
        ChampionsFormatController.instance.format,
      ]),
      builder: (ctx, _) {
        final champOn =
            ChampionsFilterController.instance.championsOnly.value;
        final fmt = ChampionsFormatController.instance.format.value;
        final fmtLabel = AppStrings.t(fmt == ChampionsFormat.doubles
            ? 'championsFormat.doubles'
            : 'championsFormat.singles');
        return PopupMenuButton<String>(
          icon: const Icon(Icons.settings),
          tooltip: '',
          popUpAnimationStyle:
              AnimationStyle(duration: const Duration(milliseconds: 100)),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'language',
              child: Row(children: [
                const Icon(Icons.language, size: 20),
                const SizedBox(width: 8),
                Text(_languageLabel()),
              ]),
            ),
            PopupMenuItem(
              value: 'theme',
              child: Row(children: [
                Icon(
                  ThemeController.instance.isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(ThemeController.instance.isDark
                    ? AppStrings.t('app.themeLight')
                    : AppStrings.t('app.themeDark')),
              ]),
            ),
            PopupMenuItem(
              value: 'sprites',
              child: Row(children: [
                const Icon(Icons.catching_pokemon, size: 20),
                const SizedBox(width: 8),
                Text(AppStrings.t('app.spriteStyle')),
              ]),
            ),
            // Champions-only toggle. Stays inline (not a checkbox
            // item) so the popup width doesn't jump between languages.
            PopupMenuItem(
              value: 'championsOnly',
              child: Row(children: [
                Icon(
                  champOn ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(AppStrings.t('dex.championsOnly')),
              ]),
            ),
            // Singles / doubles format toggle. Tapping flips between
            // the two values — same source of truth as the rank
            // sheet's segmented control. Shows the current value
            // inline ("Champions format: Singles") so the user can
            // see which side they're on without opening another UI.
            PopupMenuItem(
              value: 'championsFormat',
              child: Row(children: [
                const Icon(Icons.swap_horiz, size: 20),
                const SizedBox(width: 8),
                Text('${AppStrings.t('championsFormat.settingLabel')}'
                    ': $fmtLabel'),
              ]),
            ),
            PopupMenuItem(
              value: 'usageRank',
              child: Row(children: [
                const Icon(Icons.leaderboard, size: 20),
                const SizedBox(width: 8),
                Text(AppStrings.t('usageRank.menuLabel')),
              ]),
            ),
            PopupMenuItem(
              value: 'speedTier',
              child: Row(children: [
                const Icon(Icons.speed, size: 20),
                const SizedBox(width: 8),
                Text(AppStrings.t('speedTier.menuLabel')),
              ]),
            ),
            PopupMenuItem(
              value: 'typeChart',
              child: Row(children: [
                const Icon(Icons.grid_on, size: 20),
                const SizedBox(width: 8),
                Text(AppStrings.t('typeChart.menuLabel')),
              ]),
            ),
            PopupMenuItem(
              value: 'about',
              child: Row(children: [
                const Icon(Icons.info_outline, size: 20),
                const SizedBox(width: 8),
                Text(AppStrings.t('app.about')),
              ]),
            ),
          ],
          onSelected: (v) {
            switch (v) {
              case 'language':
                _showLanguageDialog(context);
              case 'theme':
                ThemeController.instance.toggle();
              case 'sprites':
                showSpriteStyleDialog(context);
              case 'championsOnly':
                ChampionsFilterController.instance.set(!champOn);
              case 'championsFormat':
                ChampionsFormatController.instance.set(
                  fmt == ChampionsFormat.doubles
                      ? ChampionsFormat.singles
                      : ChampionsFormat.doubles,
                );
              case 'usageRank':
                ChampionsUsageRankSheet.show(context);
              case 'speedTier':
                ChampionsSpeedTierSheet.show(context);
              case 'typeChart':
                TypeChartSheet.show(context);
              case 'about':
                showDialog(
                  context: context,
                  builder: (_) => const AppAboutDialog(),
                );
            }
          },
        );
      },
    );
  }
}
