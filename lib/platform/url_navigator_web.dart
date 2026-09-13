// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation of [navigateTo] — bypasses url_launcher and
/// Flutter's CanvasKit event synthesis by assigning
/// `window.location.href` directly. Popup blockers don't apply to
/// same-tab navigation, so this works reliably even on iOS Safari.
void navigateTo(String url) {
  html.window.location.assign(url);
}
