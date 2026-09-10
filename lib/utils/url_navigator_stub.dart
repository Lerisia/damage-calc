import 'package:url_launcher/url_launcher.dart';

/// Non-web implementation of [navigateTo]: hand the URL to the OS so it
/// opens in an external browser. The web implementation
/// ([url_navigator_web.dart]) assigns `window.location` instead.
///
/// This used to be an intentional no-op because the only caller was
/// the web-only install prompt — but the About dialog's store buttons
/// and the Buy Me a Coffee banner go through the same helper on the
/// Android/iOS apps, where tapping them then did nothing (user report,
/// 2026-09-10). Fire-and-forget: there's no UI state to update on
/// failure, and url_launcher already returns false rather than throwing
/// for an unhandleable URL.
void navigateTo(String url) {
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
