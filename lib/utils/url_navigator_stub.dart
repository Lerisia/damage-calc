/// Non-web fallback — the install-prompt / store-button flow only
/// runs on web in practice, so this stub simply no-ops. The matching
/// web implementation lives in [url_navigator_web.dart].
void navigateTo(String url) {
  // Intentionally empty on non-web targets.
}
