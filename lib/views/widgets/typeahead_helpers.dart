import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
export 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../utils/app_strings.dart';

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

TypeAheadField<T> buildTypeAhead<T>({
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
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(elevation: 4, child: child),
      );
    },
    suggestionsCallback: suggestionsCallback,
    builder: builder ?? (context, controller, focusNode) {
      String? savedText;
      focusNode.addListener(() {
        if (focusNode.hasFocus) {
          // Save current text and clear — avoids Korean IME composing issues
          savedText = controller.text;
          controller.clear();
          onTap?.call();
        } else {
          // Restore text if user didn't type anything / didn't select
          if (controller.text.isEmpty && savedText != null) {
            controller.text = savedText!;
          }
          savedText = null;
        }
      });
      return TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.done,
        maxLength: 20,
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
        decoration: decoration,
        onSubmitted: onSubmittedPick != null ? (text) {
          final result = onSubmittedPick(text);
          if (result != null) {
            onSelected(result);
          }
        } : null,
      );
    },
    itemBuilder: itemBuilder,
    onSelected: onSelected,
  );
}
