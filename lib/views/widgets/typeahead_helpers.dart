import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
export 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../utils/app_strings.dart';

/// Timestamp of the most recent `onSelected` callback fired by **any**
/// typeahead in the app. Combined with each instance's `_focusGainAt`,
/// the focus-loss handler can tell "user picked something" from "user
/// typed and tapped away without picking" — even when the user moves
/// focus directly from one typeahead to another (the per-instance
/// focus-gain timestamp acts as the cutoff so a pick from the previous
/// typeahead doesn't count toward the next one's accounting).
DateTime _lastTypeAheadPickAt = DateTime.fromMillisecondsSinceEpoch(0);

/// Custom text field for buildTypeAhead. Pure wrapper — no focus
/// management. The owning [_TypeAheadFieldHostState] handles save /
/// restore at the subtree level via a [Focus] widget, so the field
/// itself can stay simple.
class _TypeAheadTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final InputDecoration decoration;
  final ValueChanged<String>? onSubmittedPick;

  const _TypeAheadTextField({
    required this.controller,
    required this.focusNode,
    required this.decoration,
    this.onSubmittedPick,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.done,
      maxLength: 30,
      buildCounter: (_,
              {required currentLength, required isFocused, maxLength}) =>
          null,
      decoration: decoration,
      onSubmitted: onSubmittedPick,
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

Widget buildTypeAhead<T>({
  required TextEditingController controller,
  required List<T> Function(String) suggestionsCallback,
  required Widget Function(BuildContext, T) itemBuilder,
  required void Function(T) onSelected,
  required InputDecoration decoration,
  bool hideOnEmpty = false,
  double maxHeight = 200,
  Widget Function(BuildContext, TextEditingController, FocusNode)? builder,
  VoidCallback? onTap,
  FocusNode? focusNode,
  T? Function(String)? onSubmittedPick,
}) {
  return _TypeAheadFieldHost<T>(
    controller: controller,
    focusNode: focusNode,
    suggestionsCallback: suggestionsCallback,
    itemBuilder: itemBuilder,
    onSelected: onSelected,
    decoration: decoration,
    hideOnEmpty: hideOnEmpty,
    maxHeight: maxHeight,
    builder: builder,
    onTap: onTap,
    onSubmittedPick: onSubmittedPick,
  );
}

/// Wraps a [TypeAheadField] with a subtree-level [Focus] so the
/// "save query on field focus, restore on focus loss" UX runs only
/// when focus truly leaves the typeahead (field + suggestions box).
/// Previously this logic lived on the text field's own FocusNode,
/// which fired during every focus shuffle between field and box
/// (i.e. arrow-key keyboard nav) and clobbered the in-flight query.
class _TypeAheadFieldHost<T> extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final List<T> Function(String) suggestionsCallback;
  final Widget Function(BuildContext, T) itemBuilder;
  final void Function(T) onSelected;
  final InputDecoration decoration;
  final bool hideOnEmpty;
  final double maxHeight;
  final Widget Function(BuildContext, TextEditingController, FocusNode)? builder;
  final VoidCallback? onTap;
  final T? Function(String)? onSubmittedPick;

  const _TypeAheadFieldHost({
    required this.controller,
    required this.focusNode,
    required this.suggestionsCallback,
    required this.itemBuilder,
    required this.onSelected,
    required this.decoration,
    required this.hideOnEmpty,
    required this.maxHeight,
    required this.builder,
    required this.onTap,
    required this.onSubmittedPick,
  });

  @override
  State<_TypeAheadFieldHost<T>> createState() => _TypeAheadFieldHostState<T>();
}

class _TypeAheadFieldHostState<T> extends State<_TypeAheadFieldHost<T>> {
  late final SuggestionsController<T> _suggestionsController =
      SuggestionsController<T>();
  // We own the field's FocusNode when the caller doesn't pass one so
  // we can install our own onKeyEvent handler BEFORE the package's
  // SuggestionsFieldTraversalConnector wraps it. The connector wraps
  // by replacing focusNode.onKeyEvent with a function that calls
  // the previous handler on `ignored` — so our handler becomes the
  // fall-through path when the package's check (direction match,
  // isOpen, etc.) doesn't trigger focusBox. Practical effect: ↓ and
  // ↑ always enter the box on a typeahead with an open list,
  // regardless of the autoFlipDirection / effectiveDirection state.
  FocusNode? _ownedFocusNode;
  String? _savedText;
  DateTime? _focusGainAt;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    // Install fallback BEFORE TypeAheadField's first build, so the
    // package's connector wraps it instead of clobbering.
    _effectiveFocusNode.onKeyEvent = _fieldKeyEventFallback;
  }

  KeyEventResult _fieldKeyEventFallback(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isArrowDown = event.logicalKey == LogicalKeyboardKey.arrowDown;
    final isArrowUp = event.logicalKey == LogicalKeyboardKey.arrowUp;
    if (!(isArrowDown || isArrowUp)) return KeyEventResult.ignored;
    // TEMP DIAGNOSTIC — print to browser console so we can see if the
    // handler even runs and what controller state looks like at that
    // moment. Remove once the keyboard nav is verified working.
    // ignore: avoid_print
    print('[typeahead] fallback ${event.logicalKey.keyLabel} '
        'isOpen=${_suggestionsController.isOpen} '
        'dir=${_suggestionsController.effectiveDirection} '
        'state=${_suggestionsController.focusState}');
    if (!_suggestionsController.isOpen) return KeyEventResult.ignored;
    _suggestionsController.focusBox();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _suggestionsController.dispose();
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _onSelectedWrapped(T v) {
    _lastTypeAheadPickAt = DateTime.now();
    widget.onSelected(v);
  }

  /// Called when focus enters or leaves the whole typeahead subtree
  /// (text field + Floater-hosted suggestions box). Because the
  /// Floater uses OverlayPortal, the suggestions box and its items
  /// are descendants in the focus tree even though they render in
  /// the overlay layer — so this fires only on true entry / exit.
  void _onSubtreeFocusChange(bool hasFocus) {
    // TEMP DIAGNOSTIC — see _fieldKeyEventFallback note.
    // ignore: avoid_print
    print('[typeahead] subtreeFocus=$hasFocus '
        'isOpen=${_suggestionsController.isOpen} '
        'state=${_suggestionsController.focusState}');
    if (hasFocus) {
      _focusGainAt = DateTime.now();
      _savedText = widget.controller.text;
      widget.controller.clear();
      widget.onTap?.call();
    } else {
      // True focus loss — restore the previous selection's label
      // unless the user actually picked something this session.
      final pickedThisFocus = _focusGainAt != null &&
          _lastTypeAheadPickAt.isAfter(_focusGainAt!);
      if (!pickedThisFocus && _savedText != null) {
        widget.controller.text = _savedText!;
        widget.controller.selection =
            TextSelection.collapsed(offset: _savedText!.length);
      }
      _savedText = null;
      _focusGainAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      // We don't want this Focus widget to itself be a focusable
      // stop in traversal — its only job is to observe descendant
      // focus state.
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _onSubtreeFocusChange,
      child: TypeAheadField<T>(
        controller: widget.controller,
        focusNode: _effectiveFocusNode,
        suggestionsController: _suggestionsController,
        debounceDuration: Duration.zero,
        animationDuration: Duration.zero,
        autoFlipDirection: true,
        autoFlipMinHeight: 100,
        hideOnUnfocus: true,
        hideOnSelect: true,
        retainOnLoading: false,
        hideOnEmpty: widget.hideOnEmpty,
        emptyBuilder: widget.hideOnEmpty
            ? null
            : (context) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(AppStrings.t('search.noResults'),
                      style: const TextStyle(color: Colors.grey)),
                ),
        // Don't pass constraints — the package wraps it with a buggy
        // Align that sends the dropdown to the top of the screen on
        // autoFlip. Apply maxHeight via decorationBuilder instead.
        decorationBuilder: (context, child) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            child: Material(elevation: 4, child: child),
          );
        },
        suggestionsCallback: widget.suggestionsCallback,
        builder: widget.builder ??
            (context, controller, focusNode) {
              return _TypeAheadTextField(
                controller: controller,
                focusNode: focusNode,
                decoration: widget.decoration,
                onSubmittedPick: widget.onSubmittedPick != null
                    ? (text) {
                        // "Enter without keyboard nav" fallback —
                        // picks the top result. When the user has
                        // navigated into the box with ↑/↓, focus is
                        // on a suggestion InkWell; its own focused-
                        // Enter handling calls controller.select
                        // before onSubmitted ever runs here.
                        final result = widget.onSubmittedPick!(text);
                        if (result != null) _onSelectedWrapped(result);
                      }
                    : null,
              );
            },
        itemBuilder: widget.itemBuilder,
        onSelected: _onSelectedWrapped,
      ),
    );
  }
}
