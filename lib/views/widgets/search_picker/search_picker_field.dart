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

  /// Shown left of the pick (the picked item's icon). Sized by the
  /// caller to fit the text line, so the field's height is the same
  /// with or without it.
  final Widget? leading;

  /// Style of the pick's text; defaults to the text-field style.
  final TextStyle? textStyle;

  /// Replaces the default decoration (underline + [labelText] /
  /// [hintText]) — for fields that had an outlined box, a clear
  /// button, a prefix icon. [labelText] / [hintText] are ignored then.
  final InputDecoration? decoration;

  const SearchPickerField({
    super.key,
    required this.text,
    this.labelText,
    this.hintText,
    required this.onTap,
    this.leading,
    this.textStyle,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: textStyle ?? theme.textTheme.bodyLarge,
    );
    return Semantics(
      button: true,
      label: labelText ?? hintText ?? decoration?.labelText ?? decoration?.hintText,
      value: text,
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          isEmpty: text.isEmpty,
          decoration: decoration ??
              InputDecoration(
                labelText: labelText,
                hintText: hintText,
                isDense: true,
                enabled: onTap != null,
              ),
          child: leading == null
              ? label
              : Row(
                  children: [
                    leading!,
                    const SizedBox(width: 6),
                    Expanded(child: label),
                  ],
                ),
        ),
      ),
    );
  }
}
