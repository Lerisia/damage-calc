import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_strings.dart';
import '../../utils/url_navigator_stub.dart'
    if (dart.library.html) '../../utils/url_navigator_web.dart' as nav;

/// Popup shown to mobile-web visitors nudging them toward the native
/// app. Pops on every launch until the user opts out via "다시 보지
/// 않기" (mirrors the sprite-announcement dismissal semantics). Never
/// fires on desktop/wider viewports or on the native app itself.
class MobileInstallPrompt {
  MobileInstallPrompt._();

  static const _dismissedKey = 'mobile_install_prompt_dismissed_v1';
  static const _mobileWidthThreshold = 700.0;
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.elyss.damagecalc';
  static const _appStoreUrl =
      'https://apps.apple.com/kr/app/id6761017449';

  /// Call from a screen's first-frame callback. Checks the platform +
  /// viewport + dismissed flag and decides whether to open the dialog.
  static Future<void> maybeShow(BuildContext context) async {
    if (!kIsWeb) return;
    if (MediaQuery.sizeOf(context).width >= _mobileWidthThreshold) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_dismissedKey) ?? false) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => const _InstallDialog(),
    );
  }

  /// Mark the prompt as permanently dismissed for this browser. Called
  /// when the user clicks "다시 보지 않기" inside the dialog.
  static Future<void> markDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }

  /// Open the store URL in the current tab. Bypasses url_launcher —
  /// CanvasKit-synthesized clicks aren't recognized as user gestures
  /// by browsers, so url_launcher's window.open silently fails. We
  /// just assign window.location instead, which has no such
  /// restriction.
  static void open(String url) {
    nav.navigateTo(url);
  }
}

class _InstallDialog extends StatelessWidget {
  const _InstallDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Single-column content: message then a row of two compact store
      // buttons side by side (AlertDialog.actions was stacking them
      // vertically on narrow phones).
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.t('banner.mobileWebMsg'),
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    MobileInstallPrompt
                        .open(MobileInstallPrompt._playStoreUrl);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.android, size: 16),
                  label: Text(AppStrings.t('banner.getAndroid'),
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    MobileInstallPrompt
                        .open(MobileInstallPrompt._appStoreUrl);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.apple, size: 16),
                  label: Text(AppStrings.t('banner.getIos'),
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
      actionsPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.t('action.close')),
        ),
        TextButton(
          onPressed: () async {
            await MobileInstallPrompt.markDismissed();
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(AppStrings.t('action.dontShowAgain')),
        ),
      ],
    );
  }
}
