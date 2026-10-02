import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Raises the on-screen keyboard from inside the tap that opens a modal.
///
/// A mobile browser shows its keyboard only for a focus that happens
/// while the tap is still being handled (iOS Safari is strict about
/// it). A modal's search box is built a frame after the tap, so its
/// autofocus got the cursor there but no keyboard. [prime], called
/// first thing in the tap handler, opens a throwaway text input
/// connection at once, which raises the keyboard; when the search box
/// takes focus it attaches its own connection, this one is superseded,
/// and the keyboard — already up — stays up.
///
/// Web only: the native apps raise the keyboard for any focus.
class KeyboardPrimer with TextInputClient {
  KeyboardPrimer._();

  /// Forces the primer on or off in tests; null → on the web only.
  @visibleForTesting
  static bool? debugEnabled;

  TextInputConnection? _connection;

  /// Opens the connection, or returns null where it isn't needed. Must
  /// run synchronously in the tap handler — after an `await` the tap is
  /// over and the browser ignores the focus. [inputAction] should be
  /// the search box's own, so the keyboard doesn't change its return
  /// key when the box takes over.
  static KeyboardPrimer? prime(
    BuildContext context, {
    TextInputAction inputAction = TextInputAction.done,
  }) {
    if (!(debugEnabled ?? kIsWeb)) return null;
    final primer = KeyboardPrimer._();
    primer._connection = TextInput.attach(
      primer,
      TextInputConfiguration(
        viewId: View.maybeOf(context)?.viewId,
        inputAction: inputAction,
      ),
    )
      ..setEditingState(TextEditingValue.empty)
      ..show();
    return primer;
  }

  /// Closes the connection if it is still this one — the search box
  /// never took over, so nothing else will take the keyboard down.
  /// A no-op once a text field has attached its own.
  void release() {
    final connection = _connection;
    _connection = null;
    if (connection != null && connection.attached) connection.close();
  }

  @override
  TextEditingValue? get currentTextEditingValue => TextEditingValue.empty;

  @override
  AutofillScope? get currentAutofillScope => null;

  // Anything typed in the frame before the search box takes over has
  // nowhere to go.
  @override
  void updateEditingValue(TextEditingValue value) {}

  @override
  void performAction(TextInputAction action) {}

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void connectionClosed() {
    _connection?.connectionClosedReceived();
    _connection = null;
  }
}
