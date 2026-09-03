import 'package:flutter/material.dart';

import '../../utils/app_strings.dart';

/// Search box that moves the list to a match instead of filtering it.
///
/// The rank and speed tables are read by looking at what sits *around*
/// an entry — which Pokémon share your speed tier, who ranks just
/// above you. Filtering to the query would throw that context away, so
/// this scrolls to the match and leaves everything on screen.
///
/// A query can land on several rows (the realized speed table lists a
/// Pokémon once per spread it runs), so submitting repeatedly walks
/// the matches in order and the counter shows the position.
class JumpToSearchField extends StatefulWidget {
  /// Row indices matching [query], in list order. Empty when nothing
  /// matches; the field shows a miss without moving the list.
  final List<int> Function(String query) findMatches;

  /// Move the list to [index] — typically an ItemScrollController.
  final void Function(int index) onJump;

  /// Optional hint; defaults to the shared search placeholder.
  final String? hintText;

  const JumpToSearchField({
    super.key,
    required this.findMatches,
    required this.onJump,
    this.hintText,
  });

  @override
  State<JumpToSearchField> createState() => _JumpToSearchFieldState();
}

class _JumpToSearchFieldState extends State<JumpToSearchField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  List<int> _matches = const [];
  int _cursor = 0;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    setState(() {
      _matches = q.trim().isEmpty ? const [] : widget.findMatches(q);
      _cursor = 0;
    });
    // Typing lands on the first match right away; the user shouldn't
    // have to press anything to see where they are.
    if (_matches.isNotEmpty) widget.onJump(_matches.first);
  }

  void _step(int delta) {
    if (_matches.isEmpty) return;
    setState(() {
      _cursor = (_cursor + delta) % _matches.length;
      if (_cursor < 0) _cursor += _matches.length;
    });
    widget.onJump(_matches[_cursor]);
    // Keep focus so repeated submits keep walking the matches.
    _focus.requestFocus();
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _matches = const [];
      _cursor = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasQuery = _controller.text.trim().isNotEmpty;
    final noHit = hasQuery && _matches.isEmpty;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: (_) => _step(1),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
              hintText: widget.hintText ?? AppStrings.t('search.jumpHint'),
              hintStyle: TextStyle(
                fontSize: 13,
                color: noHit ? scheme.error : null,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: const OutlineInputBorder(),
              suffixIcon: hasQuery
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: _clear,
                      visualDensity: VisualDensity.compact,
                    )
                  : null,
            ),
          ),
        ),
        // Fixed-width slot so the row doesn't resize as matches come
        // and go — the field would otherwise jump under the finger.
        SizedBox(
          width: 112,
          child: hasQuery
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        _matches.isEmpty
                            ? '0'
                            : '${_cursor + 1}/${_matches.length}',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          color: _matches.isEmpty
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                      onPressed: _matches.isEmpty ? null : () => _step(-1),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                      onPressed: _matches.isEmpty ? null : () => _step(1),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
