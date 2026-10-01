import 'package:flutter/material.dart';

/// The closed state of a search picker: looks like the text field it
/// replaces (same underline, label and height) but shows the current
/// pick as plain text, and a tap opens the modal instead of putting a
/// cursor here. Keyboard-focusable; Enter / Space activate it.
///
/// Stable size: the pick is one line, ellipsized.
class SearchPickerField extends StatelessWidget {
  /// The current pick's label; empty shows [hintText].
  final String text;
  final String? labelText;
  final String? hintText;

  /// Null disables the field (data still loading).
  final VoidCallback? onTap;

  const SearchPickerField({
    super.key,
    required this.text,
    this.labelText,
    this.hintText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: labelText ?? hintText,
      value: text,
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          isEmpty: text.isEmpty,
          decoration: InputDecoration(
            labelText: labelText,
            hintText: hintText,
            isDense: true,
            enabled: onTap != null,
          ),
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
