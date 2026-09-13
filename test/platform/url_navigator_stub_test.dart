import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:damage_calc/platform/url_navigator_stub.dart';

/// The About dialog's store buttons and the Buy Me a Coffee banner
/// call `navigateTo`. On web that assigns window.location; on the
/// mobile apps the conditional import picks this stub, which used to
/// be an intentional no-op (written for the web-only install prompt)
/// — so on Android/iOS the banner silently did nothing (user report,
/// 2026-09-10). The stub must hand the URL to url_launcher in an
/// external browser.
class _FakeLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  String? launched;
  LaunchOptions? options;

  @override
  Future<bool> launchUrl(String url, LaunchOptions opts) async {
    launched = url;
    options = opts;
    return true;
  }

  @override
  LinkDelegate? get linkDelegate => null;
}

void main() {
  test('non-web navigateTo opens the URL in an external browser', () async {
    final fake = _FakeLauncher();
    UrlLauncherPlatform.instance = fake;

    navigateTo('https://buymeacoffee.com/elyss');
    await Future<void>.delayed(Duration.zero);

    expect(fake.launched, 'https://buymeacoffee.com/elyss');
    expect(fake.options?.mode, PreferredLaunchMode.externalApplication);
  });
}
