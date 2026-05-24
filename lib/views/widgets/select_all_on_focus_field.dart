import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Text field that selects all of its content when it gains focus.
///
/// Wraps [TextField] so a tap or click immediately readies the field
/// for replacement — typing a number wipes the previous value instead
/// of inserting next to the caret. Used for the calculator's number
/// inputs (EV, IV, HP %, SP, …).
///
/// Pass [controller] when the caller already owns a long-lived
/// controller (Simple Mode's SP fields, move power, …); pass
/// [initialValue] otherwise and the widget will manage its own
/// controller (seeded once — remount via a fresh [Key] to reseed).
class SelectAllOnFocusField extends StatefulWidget {
  /// External controller. When supplied [initialValue] is ignored and
  /// the controller is **not** disposed by this widget.
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;
  final InputDecoration? decoration;
  final TextAlign textAlign;

  const SelectAllOnFocusField({
    super.key,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.style,
    this.decoration,
    this.textAlign = TextAlign.start,
  }) : assert(controller != null || initialValue != null,
            'Provide either controller or initialValue');

  @override
  State<SelectAllOnFocusField> createState() => _SelectAllOnFocusFieldState();
}

class _SelectAllOnFocusFieldState extends State<SelectAllOnFocusField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = TextEditingController(text: widget.initialValue ?? '');
      _ownsController = true;
    }
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
    if (_ownsController) _controller.dispose();
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
