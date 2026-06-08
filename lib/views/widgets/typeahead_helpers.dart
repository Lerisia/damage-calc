import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

/// Stateful TextField that registers focusNode listener exactly once.
class _TypeAheadTextField<T> extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final InputDecoration decoration;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmittedPick;
  /// Shared suggestions controller — used to distinguish "focus
  /// moved into the suggestions box for keyboard nav" from
  /// "user truly left the typeahead", so the focus-loss restore
  /// doesn't trash the query mid-navigation.
  final SuggestionsController<T> suggestionsController;

  const _TypeAheadTextField({
    required this.controller,
    required this.focusNode,
    required this.decoration,
    required this.suggestionsController,
    this.onTap,
    this.onSubmittedPick,
  });

  @override
  State<_TypeAheadTextField<T>> createState() => _TypeAheadTextFieldState<T>();
}

class _TypeAheadTextFieldState<T> extends State<_TypeAheadTextField<T>> {
  String? _savedText;
  // Set when the user focuses the field; cleared on focus loss. Used
  // as the cutoff against `_lastTypeAheadPickAt` to decide whether
  // *this* focus session ended in a pick.
  DateTime? _focusGainAt;
  bool _listenerAdded = false;

  @override
  void initState() {
    super.initState();
    _addListener();
  }

  @override
  void didUpdateWidget(_TypeAheadTextField<T> old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocusChange);
      _listenerAdded = false;
      _addListener();
    }
  }

  void _addListener() {
    if (!_listenerAdded) {
      widget.focusNode.addListener(_onFocusChange);
      _listenerAdded = true;
    }
  }

  void _onFocusChange() {
    if (widget.focusNode.hasFocus) {
      _focusGainAt = DateTime.now();
      _savedText = widget.controller.text;
      widget.controller.clear();
      widget.onTap?.call();
    } else {
      // Focus moved INTO the suggestions box (user pressed ↓ to
      // start keyboard nav) — don't restore yet, the user is still
      // interacting with the typeahead. The restore will run on a
      // later focus-loss when focusState is back to blur / field.
      if (widget.suggestionsController.focusState ==
          SuggestionsFocusState.box) {
        return;
      }
      // A pick during *this* focus session means the parent has set
      // controller.text to the picked label; we keep it. Otherwise the
      // user typed (or cleared) and tapped away — restore the saved
      // value so the field doesn't deceptively show the search query
      // as if it were the current selection.
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
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
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
  // Stamp the global pick timestamp before delegating, so the focus-
  // loss handler can distinguish "user picked" from "user tapped
  // away". Both the typeahead's own onSelected (tap a suggestion) and
  // the Enter-to-pick path go through this wrapper.
  void onSelectedWrapped(T v) {
    _lastTypeAheadPickAt = DateTime.now();
    onSelected(v);
  }

  // Own the SuggestionsController so the custom text-field builder
  // can introspect its focusState — needed to distinguish "user
  // pressed ↓ to start keyboard navigation through the suggestions"
  // (focusState = box) from "user truly left the typeahead"
  // (focusState = blur). Without this, focus moving to a suggestion
  // item fired the field's focus-loss restore and trampled the query.
  // _TypeAheadFieldHost owns the controller's lifecycle.
  return _TypeAheadFieldHost<T>(
    controller: controller,
    focusNode: focusNode,
    suggestionsCallback: suggestionsCallback,
    itemBuilder: itemBuilder,
    onSelected: onSelectedWrapped,
    decoration: decoration,
    hideOnEmpty: hideOnEmpty,
    maxHeight: maxHeight,
    builder: builder,
    onTap: onTap,
    onSubmittedPick: onSubmittedPick,
  );
}

/// Owns the [SuggestionsController] for one typeahead instance so it
/// can be threaded through to the custom field builder. Pure wrapper —
/// no behaviour beyond controller lifecycle + glue.
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

  @override
  void dispose() {
    _suggestionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<T>(
      controller: widget.controller,
      focusNode: widget.focusNode,
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
            return _TypeAheadTextField<T>(
              controller: controller,
              focusNode: focusNode,
              decoration: widget.decoration,
              suggestionsController: _suggestionsController,
              onTap: widget.onTap,
              onSubmittedPick: widget.onSubmittedPick != null
                  ? (text) {
                      // Prefer the highlighted suggestion (keyboard
                      // ↑↓ navigation lands focus on an InkWell item,
                      // and a focused InkWell handles its own Enter →
                      // controller.select — onSubmitted only fires
                      // here when focus is still on the text field,
                      // so this branch is the "press Enter without
                      // navigating" fallback that picks the top
                      // result.
                      final result = widget.onSubmittedPick!(text);
                      if (result != null) widget.onSelected(result);
                    }
                  : null,
            );
          },
      itemBuilder: widget.itemBuilder,
      onSelected: widget.onSelected,
    );
  }
}
