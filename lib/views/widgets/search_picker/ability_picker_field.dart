import 'package:flutter/material.dart';

import '../../../data/ability_variants.dart';
import '../../../data/abilitydex.dart';
import '../../../i18n/app_strings.dart';
import 'search_picker.dart';

/// The ability field, shared by every screen that picks an ability
/// (Extended Mode, Simple Mode, the speed tab, the team builder).
///
/// Closed, it shows the current ability; a tap opens the search modal
/// over the host's own suggestion function (the species' abilities
/// first, then the rest). Rows carry the ability's effect as a second
/// line, and abilities the species doesn't have are greyed — still
/// pickable. There is no recent strip: the default list already starts
/// with the two or three abilities the species actually has.
class AbilityPickerField extends StatelessWidget {
  /// Ability key, or null for none.
  final String? selected;
  final String labelText;

  /// The host's suggestion function; null while its data loads, which
  /// disables the field.
  final List<String> Function(String query)? suggestions;

  /// Ability key → localized label.
  final String Function(String key) labelOf;

  /// Keys the species owns, state variants expanded. Empty → nothing
  /// is greyed.
  final Set<String> own;

  final ValueChanged<String> onChanged;

  const AbilityPickerField({
    super.key,
    required this.selected,
    required this.labelText,
    required this.suggestions,
    required this.labelOf,
    required this.own,
    required this.onChanged,
  });

  /// A state variant ("Supreme Overlord 3", "Flash Fire Active") has no
  /// text of its own; its base entry does.
  static String? _descriptionOf(String key) {
    final base = abilityBaseFor(key);
    return (base == null ? null : abilityByNameSync(base)?.localizedDescription) ??
        abilityByNameSync(key)?.localizedDescription;
  }

  Future<void> _open(BuildContext context) async {
    final suggestions = this.suggestions;
    if (suggestions == null) return;
    final picked = await showSearchPicker<String>(
      context,
      SearchPickerConfig<String>(
        kind: 'ability',
        hintText: AppStrings.t('search.ability'),
        selected: selected,
        suggestions: suggestions,
        labelOf: labelOf,
        idOf: (key) => key,
        fromId: (_) => null,
        showRecents: false,
        dimmed: (key) => own.isNotEmpty && !own.contains(key),
        descriptionOf: _descriptionOf,
      ),
    );
    if (picked == null) return;
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final current = selected;
    return SearchPickerField(
      text: current == null || current.isEmpty ? '' : labelOf(current),
      labelText: labelText,
      onTap: suggestions == null ? null : () => _open(context),
    );
  }
}
