import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../controllers/search_picker_prefs.dart';
import '../../../i18n/app_strings.dart';
import '../dismiss_keyboard.dart';
import 'search_picker.dart';

/// The search modal behind every [showSearchPicker] call.
///
/// Layout, top to bottom: the search box (focused on open) with the
/// list / grid toggle, the results, and — when there is any history —
/// a strip of recent picks pinned to the bottom, right above the
/// on-screen keyboard.
///
/// Keys: Enter picks the highlighted result (the top hit once a query
/// is typed; nothing on an empty query — the app-wide Enter rule), ↑/↓
/// move the highlight (one row; a grid moves by its column count), Esc
/// or a tap outside closes without a pick.
///
/// The dialog keeps a fixed size while the result count changes, so
/// nothing jumps under the user's finger as they type.
class SearchPickerModal<T> extends StatefulWidget {
  final SearchPickerConfig<T> config;

  const SearchPickerModal({super.key, required this.config});

  @override
  State<SearchPickerModal<T>> createState() => _SearchPickerModalState<T>();
}

class _SearchPickerModalState<T> extends State<SearchPickerModal<T>> {
  static const double _rowExtent = 44;
  static const double _tileExtent = 86;
  static const double _tileMinWidth = 80;
  static const double _gridPadding = 8;

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  late List<T> _results;
  late PickerViewMode _view;

  /// Result the keyboard would pick; -1 = none.
  int _highlight = -1;

  /// Columns of the grid as last laid out (the ↑/↓ step).
  int _columns = 1;

  SearchPickerConfig<T> get _c => widget.config;
  bool get _grid => _view == PickerViewMode.grid;

  @override
  void initState() {
    super.initState();
    _results = _c.suggestions('');
    _view = _c.showsImages
        ? SearchPickerPrefs.instance
            .viewMode(_c.kind, fallback: _c.defaultView)
        : PickerViewMode.list;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onQueryChanged(String text) {
    setState(() {
      _results = _c.suggestions(text);
      _highlight = text.trim().isEmpty || _results.isEmpty ? -1 : 0;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _pick(T item) => Navigator.of(context).pop(item);

  void _submit() {
    if (_highlight >= 0 && _highlight < _results.length) {
      _pick(_results[_highlight]);
    }
  }

  void _setView(PickerViewMode mode) {
    if (_view == mode) return;
    setState(() => _view = mode);
    SearchPickerPrefs.instance.setViewMode(_c.kind, mode);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  // ── Keyboard ───────────────────────────────────────────────────

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final step = _grid ? _columns : 1;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(_highlight < 0 ? 0 : _highlight + step);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_highlight >= 0) _moveHighlight(_highlight - step);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveHighlight(int to) {
    if (_results.isEmpty || to < 0) return;
    final next = math.min(to, _results.length - 1);
    if (next == _highlight) return;
    setState(() => _highlight = next);
    _ensureVisible(next);
  }

  void _ensureVisible(int index) {
    if (!_scroll.hasClients) return;
    final extent = _grid ? _tileExtent : _rowExtent;
    final row = _grid ? index ~/ _columns : index;
    final top = row * extent;
    final bottom = top + extent;
    final pos = _scroll.position;
    if (top < pos.pixels) {
      _scroll.jumpTo(top);
    } else if (bottom > pos.pixels + pos.viewportDimension) {
      _scroll.jumpTo(math.min(
          bottom - pos.viewportDimension, pos.maxScrollExtent));
    }
  }

  // ── Build ──────────────────────────────────────────────────────

  List<T> _recentItems() => [
        for (final id in SearchPickerPrefs.instance.recents(_c.kind))
          if (_c.fromId(id) case final T item) item,
      ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recents = _recentItems();
    return SafeArea(
      child: Dialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
          child: DismissKeyboard(
            child: Column(
              children: [
                _header(scheme),
                const Divider(height: 1),
                Expanded(
                  child: _results.isEmpty
                      ? _empty()
                      : (_grid ? _gridView(scheme) : _listView(scheme)),
                ),
                if (recents.isNotEmpty) ...[
                  const Divider(height: 1),
                  _recentStrip(recents, scheme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 8),
            child: Icon(Icons.search, size: 20, color: scheme.onSurfaceVariant),
          ),
          Expanded(
            // Sits above the text field's own focus node, so it sees
            // the arrow keys before the app-level text-editing
            // shortcuts turn them into caret moves / page scrolls.
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: _onKey,
              child: TextField(
                key: const Key('search_picker_input'),
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 16),
                // Collapsed so the text centres on the row's icons; a
                // prefixIcon decoration top-aligns it instead.
                decoration: InputDecoration(
                  hintText: _c.hintText,
                  isCollapsed: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: _onQueryChanged,
                // Keep the focus (and the keyboard) on Enter; the pick,
                // if any, closes the modal anyway.
                onEditingComplete: () {},
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
          if (_c.showsImages) ...[
            _viewButton(PickerViewMode.list, Icons.view_list,
                'picker.viewList', scheme),
            _viewButton(PickerViewMode.grid, Icons.grid_view,
                'picker.viewGrid', scheme),
          ],
          IconButton(
            key: const Key('search_picker_close'),
            tooltip: AppStrings.t('action.close'),
            icon: const Icon(Icons.close, size: 20),
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _viewButton(
      PickerViewMode mode, IconData icon, String tipKey, ColorScheme scheme) {
    final active = _view == mode;
    return IconButton(
      key: Key('search_picker_view_${mode.name}'),
      tooltip: AppStrings.t(tipKey),
      icon: Icon(icon, size: 20),
      color: active ? scheme.primary : scheme.outline,
      visualDensity: VisualDensity.compact,
      onPressed: () => _setView(mode),
    );
  }

  Widget _empty() => Center(
        child: Text(AppStrings.t('search.noResults'),
            style: const TextStyle(color: Colors.grey)),
      );

  Color _tileColor(int index, T item, ColorScheme scheme) {
    if (index == _highlight) return scheme.surfaceContainerHighest;
    if (_isSelected(item)) return scheme.primaryContainer.withValues(alpha: 0.45);
    return Colors.transparent;
  }

  bool _isSelected(T item) => _c.selected != null && item == _c.selected;

  Widget _listView(ColorScheme scheme) {
    return ListView.builder(
      controller: _scroll,
      itemExtent: _rowExtent,
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final item = _results[i];
        final dim = _c.dimmed?.call(item) ?? false;
        final sub = _c.subtitleOf?.call(item);
        return Material(
          color: _tileColor(i, item, scheme),
          child: InkWell(
            key: ValueKey('search_picker_item_${_c.idOf(item)}'),
            onTap: () => _pick(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (_c.showsImages) ...[
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: Center(child: _c.imageOf!(context, item, 32)),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      _c.labelOf(item),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: dim ? Colors.grey : null,
                        fontWeight:
                            _isSelected(item) ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                  if (sub != null && sub.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(sub,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _gridView(ColorScheme scheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _columns = math.max(
            1, (constraints.maxWidth - _gridPadding * 2) ~/ _tileMinWidth);
        return GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(horizontal: _gridPadding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _columns,
            mainAxisExtent: _tileExtent,
          ),
          itemCount: _results.length,
          itemBuilder: (context, i) {
            final item = _results[i];
            final dim = _c.dimmed?.call(item) ?? false;
            return Material(
              color: _tileColor(i, item, scheme),
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('search_picker_item_${_c.idOf(item)}'),
                onTap: () => _pick(item),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 6, 2, 2),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(child: _c.imageOf!(context, item, 48)),
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: Text(
                          _c.labelOf(item),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.15,
                            color: dim ? Colors.grey : null,
                            fontWeight:
                                _isSelected(item) ? FontWeight.w700 : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _recentStrip(List<T> recents, ColorScheme scheme) {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Text(AppStrings.t('picker.recent'),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
              itemCount: recents.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final item = recents[i];
                return Material(
                  color: scheme.surfaceContainerHighest,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('search_picker_recent_${_c.idOf(item)}'),
                    onTap: () => _pick(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_c.showsImages) ...[
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Center(
                                  child: _c.imageOf!(context, item, 22)),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(_c.labelOf(item),
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
