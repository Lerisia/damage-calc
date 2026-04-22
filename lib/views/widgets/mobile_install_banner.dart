import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/app_strings.dart';

/// Dismissible banner shown only when the app is running on the web
/// build AND the viewport looks like a phone. Nudges the user toward
/// the native app (which is what this calc is really designed for)
/// with plain copy and direct store links.
///
/// Dismissal persists across page loads via SharedPreferences.
class MobileInstallBanner extends StatefulWidget {
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.elyss.damagecalc';
  static const _appStoreUrl =
      'https://apps.apple.com/kr/app/id6761017449';

  // Keep the banner off on viewports clearly wider than a phone.
  static const _mobileWidthThreshold = 700.0;

  const MobileInstallBanner({super.key});

  @override
  State<MobileInstallBanner> createState() => _MobileInstallBannerState();
}

class _MobileInstallBannerState extends State<MobileInstallBanner> {
  static const _prefKey = 'mobile_install_banner_dismissed';

  bool _loaded = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dismissed = prefs.getBool(_prefKey) ?? false;
      _loaded = true;
    });
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    if (!_loaded || _dismissed) return const SizedBox.shrink();
    final w = MediaQuery.sizeOf(context).width;
    if (w >= MobileInstallBanner._mobileWidthThreshold) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  AppStrings.t('banner.mobileWebMsg'),
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onPrimaryContainer,
                    height: 1.35,
                  ),
                ),
              ),
              IconButton(
                tooltip: AppStrings.t('banner.dismiss'),
                icon: const Icon(Icons.close, size: 18),
                onPressed: _dismiss,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _storeButton(
                label: AppStrings.t('banner.getAndroid'),
                icon: Icons.android,
                onPressed: () => _open(MobileInstallBanner._playStoreUrl),
              ),
              const SizedBox(width: 8),
              _storeButton(
                label: AppStrings.t('banner.getIos'),
                icon: Icons.apple,
                onPressed: () => _open(MobileInstallBanner._appStoreUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _storeButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
