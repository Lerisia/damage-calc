import 'dart:async';

import 'package:flutter/material.dart';

import '../../../controllers/search_picker_prefs.dart';
import 'keyboard_primer.dart';
import 'search_picker_modal.dart';

export '../../../controllers/search_picker_prefs.dart' show PickerViewMode;
export 'search_picker_field.dart';

/// Everything one kind of search picker needs. The modal itself knows
/// nothing about Pokémon, items or abilities — a field describes its
/// corpus here and calls [showSearchPicker].
///
/// The ranking is not the modal's business either: [suggestions] is the
/// same function the field's old typeahead dropdown called (shared
/// search engine, pins, Champions filter, …), so a field moved onto the
/// modal lists exactly what it listed before.
class SearchPickerConfig<T> {
  /// Namespace for the saved view mode and the recent picks —
  /// `pokemon`, `item`, … Fields of the same kind share them.
  final String kind;

  final String hintText;

  /// Results for a query; empty query → the default list.
  final List<T> Function(String query) suggestions;

  final String Function(T item) labelOf;

  /// Stable id for the recent-picks store. An empty id is never
  /// recorded (the "no item" entry).
  final String Function(T item) idOf;

  /// A recorded id back to an item, or null when it no longer exists
  /// or is not pickable right now (filtered out) — such recents are
  /// simply not shown.
  final T? Function(String id) fromId;

  /// The field's current value: highlighted in the results.
  final T? selected;

  /// Image for an item at [size] logical pixels. Null → a text-only
  /// picker (abilities): no images, no grid.
  final Widget Function(BuildContext context, T item, double size)? imageOf;

  /// Whether images can actually be shown right now (on mobile they
  /// come from the user-installed sprite pack). False → text-only.
  final bool imagesAvailable;

  /// View mode until the user picks one for this [kind].
  final PickerViewMode defaultView;

  /// Secondary text at the end of a list row (type, power, …).
  final String? Function(T item)? subtitleOf;

  /// A richer end-of-row widget than [subtitleOf] can express (a move's
  /// type in its colour, …). List rows only.
  final Widget Function(BuildContext context, T item)? trailingOf;

  /// A second, smaller line under the label (an ability's effect).
  /// When set, list rows are a little taller. List rows only.
  final String? Function(T item)? descriptionOf;

  /// Whether the recent-picks strip is shown (and picks recorded).
  /// Off for kinds where the default list already leads with what the
  /// user wants — a species' own abilities.
  final bool showRecents;

  /// Greyed-out entries (an ability the species doesn't own, a move it
  /// can't learn) — still pickable.
  final bool Function(T item)? dimmed;

  const SearchPickerConfig({
    required this.kind,
    required this.hintText,
    required this.suggestions,
    required this.labelOf,
    required this.idOf,
    required this.fromId,
    this.selected,
    this.imageOf,
    this.imagesAvailable = true,
    this.defaultView = PickerViewMode.list,
    this.subtitleOf,
    this.trailingOf,
    this.descriptionOf,
    this.showRecents = true,
    this.dimmed,
  });

  bool get showsImages => imageOf != null && imagesAvailable;
}

/// Opens the search modal for [config] and resolves to the picked item,
/// or null when it was dismissed. A pick is recorded in the kind's
/// recent list.
///
/// The search box has the cursor the moment the modal is up, so the tap
/// that opened it is the only tap before typing. No transition — this
/// calculator runs inside a one-minute battle timer.
///
/// Call it straight from the tap handler, before any `await`: on the
/// web the keyboard only comes up for a focus made during the tap (see
/// [KeyboardPrimer]).
Future<T?> showSearchPicker<T>(
    BuildContext context, SearchPickerConfig<T> config) async {
  final keyboard = KeyboardPrimer.prime(context);
  final T? picked;
  try {
    picked = await showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, _, __) => SearchPickerModal<T>(config: config),
    );
  } finally {
    keyboard?.release();
  }
  if (picked != null && config.showRecents) {
    // Recorded in memory at once; the write to storage is not awaited
    // (and may fail) — a pick must never wait on, or be lost to, the
    // preferences store.
    unawaited(SearchPickerPrefs.instance
        .addRecent(config.kind, config.idOf(picked))
        .catchError((Object _) {}));
  }
  return picked;
}
