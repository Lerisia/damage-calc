import '../models/ability.dart';
import '../models/item.dart';

/// Display-name maps derived from the dexes — one definition of which
/// entries a picker may offer. Four screens used to build these by hand
/// with slightly different rules (one of them let the description-only
/// group keys like "Flash Fire" through as pickable).

/// Held items only: what the item pickers offer (Champions legality is
/// a separate filter, see `item_picker.dart`).
Map<String, String> heldItemNames(Map<String, Item> dex) => {
      for (final e in dex.entries)
        if (e.value.held) e.key: e.value.localizedName,
    };

/// Whether an ability key may be picked: not a spin-off-only ability and
/// not a description-only group key (those exist so the dex can show
/// "Flash Fire" text; the calc only understands the state keys).
bool isPickableAbility(Ability a) => !a.nonMainline && !a.descriptionOnly;

/// Ability keys a picker may offer.
Set<String> pickableAbilityKeys(Map<String, Ability> dex) => {
      for (final e in dex.entries)
        if (isPickableAbility(e.value)) e.key,
    };

/// Ability display names. [pickableOnly] (the default) is the picker
/// corpus; pass false for a display-only map that can also label the
/// group keys carried by usage tables and pastes.
Map<String, String> abilityNames(Map<String, Ability> dex,
        {bool pickableOnly = true}) =>
    {
      for (final e in dex.entries)
        if (!pickableOnly || isPickableAbility(e.value))
          e.key: e.value.localizedName,
    };
