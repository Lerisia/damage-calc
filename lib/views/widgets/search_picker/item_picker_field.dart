import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../controllers/champions_filter_controller.dart';
import '../../../data/champions_items.dart';
import '../../../i18n/app_strings.dart';
import '../../../platform/sprite_pack_manager.dart';
import '../../../platform/sprite_service.dart';
import '../../../search/item_picker.dart';
import '../../../search/korean_search.dart';
import 'search_picker.dart';

/// The held-item field, shared by every screen that picks an item
/// (Extended Mode, Simple Mode, the speed tab, the team builder).
///
/// Closed, it shows the current item like the text field it replaced;
/// a tap opens the search modal over the same suggestions the old
/// dropdown listed ([itemSuggestions]: current pick, "no item", then
/// A→Z or relevance; Champions scope applied).
class ItemPickerField extends StatelessWidget {
  /// Item key, or null for "no item".
  final String? selected;

  /// Search corpus ([buildItemIndex]); null while the item data loads,
  /// which disables the field.
  final SearchIndex<String>? index;

  /// Item key → localized label.
  final Map<String, String> names;

  /// Label of the "no item" entry.
  final String noneLabel;

  /// The holder's most-used items, best first ([usageItemsFor]); they
  /// lead the default list. Unknown keys are ignored.
  final List<String> preferred;

  final String labelText;
  final ValueChanged<String?> onChanged;

  const ItemPickerField({
    super.key,
    required this.selected,
    required this.index,
    required this.names,
    required this.noneLabel,
    this.preferred = const [],
    required this.labelText,
    required this.onChanged,
  });

  String _label(String key) => key.isEmpty ? noneLabel : (names[key] ?? key);

  List<String> _knownPreferred() =>
      [for (final k in preferred) if (names.containsKey(k)) k];

  Future<void> _open(BuildContext context) async {
    final index = this.index;
    if (index == null) return;
    final championsOnly = ChampionsFilterController.instance.championsOnly.value;
    final preferred = _knownPreferred();
    final picked = await showSearchPicker<String>(
      context,
      SearchPickerConfig<String>(
        kind: 'item',
        hintText: AppStrings.t('search.item'),
        selected: selected ?? kNoItemKey,
        suggestions: (query) => itemSuggestions(
          index,
          query,
          selected: selected,
          preferred: preferred,
          championsOnly: championsOnly,
          labelOf: _label,
        ),
        labelOf: _label,
        idOf: (key) => key,
        fromId: (id) => names.containsKey(id) &&
                (!championsOnly || id == selected || isChampionsItem(id))
            ? id
            : null,
        imageOf: (context, key, size) => ItemIcon(itemId: key, size: size),
        imagesAvailable:
            kIsWeb || SpritePackManager.instance.itemIconsInstalled,
        defaultView: PickerViewMode.list,
      ),
    );
    if (picked == null) return;
    onChanged(picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    return SearchPickerField(
      text: _label(selected ?? kNoItemKey),
      labelText: labelText,
      onTap: index == null ? null : () => _open(context),
    );
  }
}

/// A held item's icon in a fixed [size] slot. Sprite pack 8 covers
/// every held item the app offers but a stray one or two; whatever is
/// missing or fails to load (an older pack on mobile) shows a neutral
/// placeholder instead of an empty hole. "No item" gets its own mark.
class ItemIcon extends StatelessWidget {
  final String itemId;
  final double size;

  const ItemIcon({super.key, required this.itemId, required this.size});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget mark(IconData icon) => SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.7, color: scheme.outlineVariant),
        );
    if (itemId.isEmpty) return mark(Icons.block);
    final placeholder = mark(Icons.category_outlined);
    final provider = SpriteService.instance.itemIconFor(itemId);
    if (provider == null) return placeholder;
    return Image(
      image: provider,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}
