part of '../damage_calculator_screen.dart';

/// About dialog.
class AppAboutDialog extends StatelessWidget {
  const AppAboutDialog({super.key});

  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.elyss.damagecalc';
  static const _appStoreUrl =
      'https://apps.apple.com/kr/app/id6761017449';
  static const _buyMeACoffeeUrl = 'https://buymeacoffee.com/elyss';

  /// See MobileInstallPrompt.open — bypass url_launcher entirely
  /// and assign window.location directly via the conditional-import
  /// helper. CanvasKit's synthesized clicks aren't seen as user
  /// gestures by browsers, so url_launcher's launch silently fails.
  void _open(String url) {
    nav.navigateTo(url);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppStrings.t('app.title'),
        style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('v1.16.13'),
          const SizedBox(height: 8),
          Text(AppStrings.t('about.description')),
          const SizedBox(height: 8),
          Text(AppStrings.t('about.subtitle'), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          const Text('By  Elyss'),
          const SelectableText('Web  damage-calc.com'),
          const SelectableText('GitHub  github.com/Lerisia/damage-calc'),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _open(_playStoreUrl),
                icon: const Icon(Icons.android, size: 16),
                label: Text(AppStrings.t('banner.getAndroid'),
                    style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _open(_appStoreUrl),
                icon: const Icon(Icons.apple, size: 16),
                label: Text(AppStrings.t('banner.getIos'),
                    style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(AppStrings.t('about.support'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          // Official Buy Me a Coffee button, bundled so it works offline.
          GestureDetector(
            onTap: () => _open(_buyMeACoffeeUrl),
            child: Image.asset(
              'assets/bmc_button.png',
              width: 220,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            AppStrings.t('about.beta'),
            style: const TextStyle(fontSize: 12, color: Colors.orange),
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.t('about.disclaimer'),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          // Sprite-credit block — required by the Smogon Sprite
          // Project's non-profit-use clause and by general fairness
          // (the BW pixel set is community-made fan art). Pinned in
          // the About dialog so it stays visible regardless of which
          // screen the user is on.
          Text(
            AppStrings.t('sprite.creditTitle'),
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.t('sprite.creditBody'),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.t('action.close')),
        ),
      ],
    );
  }
}
