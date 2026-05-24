import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Text field that selects all of its content when it gains focus.
///
/// Wraps [TextField] with a private controller and focus node so a tap
/// or click immediately readies the field for replacement — typing a
/// number wipes the previous value instead of inserting next to the
/// caret. Used for the calculator's number inputs (EV, IV, HP %).
///
/// The widget seeds its controller from [initialValue] at mount and
/// intentionally does not sync to later [initialValue] changes — call
/// sites that need an external reset pass a fresh [Key] (e.g. keyed on
/// a reset counter) so the widget remounts with the new seed.
class SelectAllOnFocusField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;
  final InputDecoration? decoration;
  final TextAlign textAlign;

  const SelectAllOnFocusField({
    super.key,
    required this.initialValue,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.style,
    this.decoration,
    this.textAlign = TextAlign.start,
  });

  @override
  State<SelectAllOnFocusField> createState() => _SelectAllOnFocusFieldState();
}

class _SelectAllOnFocusFieldState extends State<SelectAllOnFocusField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode.addListener(_handleFocus);
  }

  void _handleFocus() {
    if (!_focusNode.hasFocus) return;
    // Defer to after focus is fully established so the framework's own
    // caret placement doesn't immediately overwrite our selection.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focusNode.hasFocus) return;
      final text = _controller.text;
      if (text.isEmpty) return;
      _controller.selection =
          TextSelection(baseOffset: 0, extentOffset: text.length);
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      style: widget.style,
      decoration: widget.decoration ?? const InputDecoration(),
      textAlign: widget.textAlign,
      onChanged: widget.onChanged,
    );
  }
}
