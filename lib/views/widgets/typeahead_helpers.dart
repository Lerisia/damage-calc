import 'package:flutter/material.dart';
export 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

const Duration typeaheadDebounceDuration = Duration.zero;
const Duration typeaheadAnimationDuration = Duration.zero;
const bool typeaheadAutoFlipDirection = false;
const bool typeaheadHideOnUnfocus = true;
const bool typeaheadHideOnSelect = true;
const bool typeaheadRetainOnLoading = false;

void selectAllOnTap(TextEditingController controller) {
  // Use short delay to run after TypeAheadField's internal focus handling
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
}

TypeAheadField<T> buildTypeAhead<T>({
  required TextEditingController controller,
  required List<T> Function(String) suggestionsCallback,
  required Widget Function(BuildContext, T) itemBuilder,
  required void Function(T) onSelected,
  required InputDecoration decoration,
  bool hideOnEmpty = false,
  BoxConstraints constraints = const BoxConstraints(maxHeight: 200),
}) {
  return TypeAheadField<T>(
    controller: controller,
    debounceDuration: typeaheadDebounceDuration,
    animationDuration: typeaheadAnimationDuration,
    autoFlipDirection: typeaheadAutoFlipDirection,
    hideOnUnfocus: typeaheadHideOnUnfocus,
    hideOnSelect: typeaheadHideOnSelect,
    retainOnLoading: typeaheadRetainOnLoading,
    hideOnEmpty: hideOnEmpty,
    constraints: constraints,
    suggestionsCallback: suggestionsCallback,
    builder: (context, controller, focusNode) {
      return TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.done,
        decoration: decoration,
        onTap: () => selectAllOnTap(controller),
      );
    },
    itemBuilder: itemBuilder,
    onSelected: onSelected,
  );
}
