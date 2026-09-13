import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
export 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../i18n/app_strings.dart';

/// Timestamp of the most recent `onSelected` callback fired by **any**
/// typeahead in the app. Combined with each instance's `_focusGainAt`,
/// the focus-loss handler can tell "user picked something" from "user
/// typed and tapped away without picking" — even when the user moves
/// focus directly from one typeahead to another (the per-instance
/// focus-gain timestamp acts as the cutoff so a pick from the previous
/// typeahead doesn't count toward the next one's accounting).
DateTime _lastTypeAheadPickAt = DateTime.fromMillisecondsSinceEpoch(0);

/// The text field inside every [buildTypeAhead] typeahead.
///
/// Owns one "search session": on entry the current label is saved and
/// the field cleared for typing; on exit the saved label is restored
/// unless a pick happened in between (so a stray query never masquerades
/// as the selection). The session is scoped to the suggestions
/// controller's focus state — `blur → (field | box)` opens it,
/// `(field | box) → blur` closes it — NOT to the raw FocusNode. That
/// matters because flutter_typeahead moves focus into the suggestions
/// box on ↓ (its items are focusable) and back on ↑; keyed on the
/// FocusNode alone, entering the list looked like "tapped away", the
/// query got restored, the search re-ran and the list changed under the
/// cursor — keyboard navigation never worked (fixed 2026-09-13).
class _TypeAheadTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final SuggestionsController suggestions;
  final InputDecoration decoration;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmittedPick;
  /// The label the field shows while no search session is open (the
  /// current pick). Written into the controller on mount and whenever
  /// it changes while idle — never during a session, so a parent
  /// rebuild while focus is in the suggestions list can't replace the
  /// query. Hosts used to do this write themselves in build() guarded
  /// by `!focusNode.hasFocus`, which is exactly true while the list has
  /// focus; that killed ↓ navigation in every field that did it.
  final String? idleText;

  const _TypeAheadTextField({
    required this.controller,
    required this.focusNode,
    required this.suggestions,
    required this.decoration,
    this.onTap,
    this.onSubmittedPick,
    this.idleText,
  });

  @override
  State<_TypeAheadTextField> createState() => _TypeAheadTextFieldState();
}

class _TypeAheadTextFieldState extends State<_TypeAheadTextField> {
  String? _savedText;
  // Set when a session opens; the cutoff against `_lastTypeAheadPickAt`
  // to decide whether *this* session ended in a pick.
  DateTime? _sessionStart;
  SuggestionsFocusState _last = SuggestionsFocusState.blur;

  bool get _inSession => _sessionStart != null;

  @override
  void initState() {
    super.initState();
    _last = widget.suggestions.focusState;
    widget.suggestions.addListener(_onSuggestionsChanged);
    _syncIdleText();
  }

  @override
  void didUpdateWidget(_TypeAheadTextField old) {
    super.didUpdateWidget(old);
    if (!identical(old.suggestions, widget.suggestions)) {
      old.suggestions.removeListener(_onSuggestionsChanged);
      _last = widget.suggestions.focusState;
      widget.suggestions.addListener(_onSuggestionsChanged);
    }
    if (old.idleText != widget.idleText) _syncIdleText();
  }

  /// Show [idleText] — only while idle; a session owns the text.
  void _syncIdleText() {
    final text = widget.idleText;
    if (text == null || _inSession) return;
    if (widget.controller.text == text) return;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onSuggestionsChanged() {
    final now = widget.suggestions.focusState;
    if (now == _last) return;
    final wasBlur = _last == SuggestionsFocusState.blur;
    final isBlur = now == SuggestionsFocusState.blur;
    _last = now;
    if (wasBlur && !isBlur) {
      // Session opens: remember the label, clear for typing.
      _sessionStart = DateTime.now();
      _savedText = widget.controller.text;
      widget.controller.clear();
      widget.onTap?.call();
    } else if (!wasBlur && isBlur) {
      // Session closes. A pick during it means the parent already set
      // the picked label; otherwise the user typed (or cleared) and
      // left — put the saved label back so the query doesn't pose as
      // the selection. Field ↔ box moves in between are the same
      // session and change nothing.
      final picked = _sessionStart != null &&
          _lastTypeAheadPickAt.isAfter(_sessionStart!);
      final restore = widget.idleText ?? _savedText;
      if (!picked && restore != null) {
        widget.controller.value = TextEditingValue(
          text: restore,
          selection: TextSelection.collapsed(offset: restore.length),
        );
      }
      _savedText = null;
      _sessionStart = null;
    }
  }

  @override
  void dispose() {
    widget.suggestions.removeListener(_onSuggestionsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      textInputAction: TextInputAction.done,
      maxLength: 30,
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
      decoration: widget.decoration,
      onSubmitted: widget.onSubmittedPick,
    );
  }
}

/// Keyboard entry into the suggestions list, the same for every field
/// (default or custom text field) — wraps whatever [buildTypeAhead]'s
/// builder returns.
///
/// 1. ↓ and ↑ both enter the list whichever side it opened on. The
///    package only enters on the key matching `effectiveDirection` (↓
///    for a list below, ↑ for one auto-flipped above) and ignores the
///    other, which then fell through to the app's text-editing
///    shortcuts. This Focus sits above the text field's node, so it
///    sees exactly the arrows the package declined.
/// 2. Entering a list flipped above lands on the item nearest the field
///    (the top hit — the flipped list is reversed), not the farthest,
///    which is where the package's "first child" focus put it. So
///    "type, ↓, Enter" picks the top hit in both directions, and the
///    next arrow away from the field walks down the ranking.
class _TypeAheadEntryGuard extends StatefulWidget {
  final SuggestionsController suggestions;
  final Widget child;
  const _TypeAheadEntryGuard({required this.suggestions, required this.child});

  @override
  State<_TypeAheadEntryGuard> createState() => _TypeAheadEntryGuardState();
}

class _TypeAheadEntryGuardState extends State<_TypeAheadEntryGuard> {
  SuggestionsFocusState _last = SuggestionsFocusState.blur;

  @override
  void initState() {
    super.initState();
    _last = widget.suggestions.focusState;
    widget.suggestions.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(_TypeAheadEntryGuard old) {
    super.didUpdateWidget(old);
    if (!identical(old.suggestions, widget.suggestions)) {
      old.suggestions.removeListener(_onChanged);
      _last = widget.suggestions.focusState;
      widget.suggestions.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.suggestions.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final now = widget.suggestions.focusState;
    if (now == _last) return;
    _last = now;
    if (now == SuggestionsFocusState.box &&
        widget.suggestions.effectiveDirection == VerticalDirection.up) {
      // The box's own connector focuses its first child in the same
      // notification (it registered after us); retarget once that has
      // been applied.
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusNearestItem());
    }
  }

  void _focusNearestItem() {
    if (!mounted) return;
    if (widget.suggestions.focusState != SuggestionsFocusState.box) return;
    final focused = FocusManager.instance.primaryFocus;
    final scope = focused?.enclosingScope;
    if (focused == null || scope == null) return;
    FocusNode? nearest;
    var nearestTop = double.negativeInfinity;
    for (final n in scope.traversalDescendants) {
      if (!n.canRequestFocus) continue;
      final top = n.rect.top;
      if (top > nearestTop) {
        nearestTop = top;
        nearest = n;
      }
    }
    if (nearest != null && nearest != focused) nearest.requestFocus();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k != LogicalKeyboardKey.arrowDown && k != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    final s = widget.suggestions;
    if (!s.isOpen || (s.suggestions?.isEmpty ?? true)) {
      return KeyEventResult.ignored;
    }
    s.focusBox();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKeyEvent,
      child: widget.child,
    );
  }
}

void selectAllOnTap(TextEditingController controller) {
  // Delay is required: TypeAheadField's focus handler re-engages IME
  // composing after postFrameCallback, so without the delay the Korean
  // IME last character merges with new input (e.g. "씨파이리" instead of "파이리").
  SchedulerBinding.instance.addPostFrameCallback((_) {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (controller.text.isNotEmpty) {
        controller.value = TextEditingValue(
          text: controller.text,
          selection: TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          ),
          composing: TextRange.empty,
        );
      }
    });
  });
}

/// The app-wide Enter rule for search→pick fields: the first suggestion
/// currently shown for [text], or nothing for an empty query. This is
/// what [buildTypeAhead] wires to Enter unless a caller overrides it.
T? typeAheadPickTop<T>(String text, List<T> Function(String) suggestions) {
  if (text.trim().isEmpty) return null;
  final hits = suggestions(text);
  return hits.isEmpty ? null : hits.first;
}

TypeAheadField<T> buildTypeAhead<T>({
  required TextEditingController controller,
  required List<T> Function(String) suggestionsCallback,
  required Widget Function(BuildContext, T) itemBuilder,
  required void Function(T) onSelected,
  required InputDecoration decoration,
  bool hideOnEmpty = false,
  double maxHeight = 200,
  /// Custom text field. Receives the Enter handler already bound to the
  /// app-wide rule (or [onSubmittedPick]) — wire it to the field's
  /// `onSubmitted` rather than implementing a pick locally — and the
  /// typeahead's [SuggestionsController], whose `focusState` is what a
  /// custom field must key its clear/restore behaviour on (see
  /// [_TypeAheadTextField]).
  Widget Function(BuildContext, TextEditingController, FocusNode,
      ValueChanged<String> onSubmitted, SuggestionsController<T> suggestions)? builder,
  VoidCallback? onTap,
  FocusNode? focusNode,
  /// The label to show while the field is idle (its current pick).
  /// Pass this instead of writing the label into [controller] from the
  /// host's build(): the helper writes it on mount and on change, but
  /// never while a search session (field or list focused) is open.
  String? idleText,
  /// What Enter picks. Defaults to the one rule every search→pick
  /// field in the app follows: the first suggestion currently shown
  /// for the typed text, and nothing for an empty query. Override
  /// only when a field's Enter target genuinely differs from its
  /// dropdown — not to re-implement the same rule locally.
  T? Function(String)? onSubmittedPick,
}) {
  // Stamp the global pick timestamp before delegating, so the focus-
  // loss handler can distinguish "user picked" from "user tapped
  // away". Both the typeahead's own onSelected (tap a suggestion) and
  // the Enter-to-pick path go through this wrapper.
  void onSelectedWrapped(T v) {
    _lastTypeAheadPickAt = DateTime.now();
    onSelected(v);
  }

  final submittedPick =
      onSubmittedPick ?? (text) => typeAheadPickTop(text, suggestionsCallback);
  void submit(String text) {
    final result = submittedPick(text);
    if (result != null) onSelectedWrapped(result);
  }

  return TypeAheadField<T>(
    controller: controller,
    focusNode: focusNode,
    debounceDuration: Duration.zero,
    animationDuration: Duration.zero,
    autoFlipDirection: true,
    autoFlipMinHeight: 100,
    hideOnUnfocus: true,
    hideOnSelect: true,
    retainOnLoading: false,
    hideOnEmpty: hideOnEmpty,
    emptyBuilder: hideOnEmpty ? null : (context) => Padding(
      padding: const EdgeInsets.all(12),
      child: Text(AppStrings.t('search.noResults'), style: const TextStyle(color: Colors.grey)),
    ),
    // Don't pass constraints — the package wraps it with a buggy Align
    // that sends the dropdown to the top of the screen on autoFlip.
    // Instead, apply maxHeight via decorationBuilder.
    decorationBuilder: (context, child) {
      return Focus(
        canRequestFocus: false,
        skipTraversal: true,
        // ↑/↓ between suggestions. The package leaves in-list movement
        // to Flutter's default arrow-key focus traversal, which the
        // WEB app shortcuts don't map (arrows scroll there), so on
        // damage-calc.com ↓ entered the list and then went dead. Move
        // focus ourselves; when there is no neighbour in that direction
        // return `ignored` so the package's scope handler still hands
        // focus back to the text field at the list's edge.
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final TraversalDirection dir;
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            dir = TraversalDirection.down;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            dir = TraversalDirection.up;
          } else {
            return KeyEventResult.ignored;
          }
          final focused = FocusManager.instance.primaryFocus;
          if (focused == null) return KeyEventResult.ignored;
          return focused.focusInDirection(dir)
              ? KeyEventResult.handled
              : KeyEventResult.ignored;
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Material(elevation: 4, child: child),
        ),
      );
    },
    suggestionsCallback: suggestionsCallback,
    // The package calls this builder with the TypeAheadField's own
    // context, which sits ABOVE its SuggestionsControllerProvider; the
    // widget we return is placed below it. So resolve the controller
    // from a Builder inside the returned subtree.
    builder: (_, controller, focusNode) => Builder(
      builder: (context) {
        final suggestions = SuggestionsController.of<T>(context);
        final Widget field;
        if (builder != null) {
          field = builder(context, controller, focusNode, submit, suggestions);
        } else {
          field = _TypeAheadTextField(
            controller: controller,
            focusNode: focusNode,
            suggestions: suggestions,
            decoration: decoration,
            onTap: onTap,
            onSubmittedPick: submit,
            idleText: idleText,
          );
        }
        return _TypeAheadEntryGuard(suggestions: suggestions, child: field);
      },
    ),
    itemBuilder: itemBuilder,
    onSelected: onSelectedWrapped,
  );
}
