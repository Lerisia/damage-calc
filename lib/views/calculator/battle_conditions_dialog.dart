part of '../damage_calculator_screen.dart';

/// Everything the "배틀환경" button edits, as one value so the dialog can
/// hold a working copy and report each change back to the screen.
class _FieldConditions {
  final Weather weather;
  final Terrain terrain;
  final RoomConditions room;
  final AuraToggles auras;
  final RuinToggles ruins;

  const _FieldConditions({
    required this.weather,
    required this.terrain,
    required this.room,
    required this.auras,
    required this.ruins,
  });

  _FieldConditions copyWith({
    Weather? weather,
    Terrain? terrain,
    RoomConditions? room,
    AuraToggles? auras,
    RuinToggles? ruins,
  }) =>
      _FieldConditions(
        weather: weather ?? this.weather,
        terrain: terrain ?? this.terrain,
        room: room ?? this.room,
        auras: auras ?? this.auras,
        ruins: ruins ?? this.ruins,
      );
}

/// The battle-conditions dialog: weather / terrain single-select chips,
/// room + gravity, and the aura / ruin toggles (a chip is locked on
/// while either side's ability already sources that field). Every
/// change goes out through [onChanged] immediately so the calculator
/// behind the dialog re-runs live; the reset action clears weather,
/// terrain and rooms only, as it always did.
class _BattleConditionsDialog extends StatefulWidget {
  final _FieldConditions initial;
  final bool Function(String ability) abilityPresent;
  final ValueChanged<_FieldConditions> onChanged;

  const _BattleConditionsDialog({
    required this.initial,
    required this.abilityPresent,
    required this.onChanged,
  });

  @override
  State<_BattleConditionsDialog> createState() => _BattleConditionsDialogState();
}

class _BattleConditionsDialogState extends State<_BattleConditionsDialog> {
  late _FieldConditions _c = widget.initial;

  void _set(_FieldConditions v) {
    setState(() => _c = v);
    widget.onChanged(v);
  }

  static const _titleStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 14);
  static const _chipStyle = TextStyle(fontSize: 13);

  Widget _choice(String label, bool selected, VoidCallback onTap) => ChoiceChip(
        showCheckmark: false,
        label: Text(label, style: _chipStyle),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      );

  Widget _filter(String label, bool value, ValueChanged<bool> onChanged) => FilterChip(
        showCheckmark: false,
        label: Text(label, style: _chipStyle),
        selected: value,
        onSelected: onChanged,
        visualDensity: VisualDensity.compact,
      );

  /// Aura / ruin chip: locked on while [ability] is on either side.
  Widget _envChip(String label, String ability, bool value, ValueChanged<bool> onChanged) {
    final forced = widget.abilityPresent(ability);
    return FilterChip(
      showCheckmark: false,
      label: Text(label, style: _chipStyle),
      selected: forced || value,
      onSelected: forced ? null : onChanged,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return AlertDialog(
      // No header — the button the user tapped already said "배틀환경".
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SingleChildScrollView(
        // Scroll when the chip list is taller than the viewport leaves
        // room for (small phones / landscape).
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.t('toolbar.weather'), style: _titleStyle),
            Wrap(spacing: 4, children: [
              for (final w in Weather.values)
                if (w != Weather.none)
                  _choice(KoStrings.getWeatherName(w), c.weather == w,
                      () => _set(c.copyWith(weather: c.weather == w ? Weather.none : w))),
            ]),
            const SizedBox(height: 12),
            Text(AppStrings.t('toolbar.terrain'), style: _titleStyle),
            Wrap(spacing: 4, children: [
              for (final t in Terrain.values)
                if (t != Terrain.none)
                  _choice(KoStrings.getTerrainName(t), c.terrain == t,
                      () => _set(c.copyWith(terrain: c.terrain == t ? Terrain.none : t))),
            ]),
            const SizedBox(height: 12),
            Text(AppStrings.t('toolbar.room'), style: _titleStyle),
            Wrap(spacing: 4, children: [
              _filter(KoStrings.getRoomName(Room.trickRoom), c.room.trickRoom,
                  (v) => _set(c.copyWith(room: c.room.copyWith(trickRoom: v)))),
              _filter(KoStrings.getRoomName(Room.magicRoom), c.room.magicRoom,
                  (v) => _set(c.copyWith(room: c.room.copyWith(magicRoom: v)))),
              _filter(KoStrings.getRoomName(Room.wonderRoom), c.room.wonderRoom,
                  (v) => _set(c.copyWith(room: c.room.copyWith(wonderRoom: v)))),
              _filter(KoStrings.gravityName, c.room.gravity,
                  (v) => _set(c.copyWith(room: c.room.copyWith(gravity: v)))),
            ]),
            const SizedBox(height: 12),
            Text(AppStrings.t('section.aura'), style: _titleStyle),
            Wrap(spacing: 4, children: [
              _envChip(AppStrings.t('damage.allyFairyAura'), 'Fairy Aura', c.auras.fairyAura,
                  (v) => _set(c.copyWith(auras: c.auras.copyWith(fairyAura: v)))),
              _envChip(AppStrings.t('damage.allyDarkAura'), 'Dark Aura', c.auras.darkAura,
                  (v) => _set(c.copyWith(auras: c.auras.copyWith(darkAura: v)))),
              _envChip(AppStrings.t('damage.allyAuraBreak'), 'Aura Break', c.auras.auraBreak,
                  (v) => _set(c.copyWith(auras: c.auras.copyWith(auraBreak: v)))),
            ]),
            const SizedBox(height: 12),
            // Ruin — dex order: Tablets → Sword → Vessel → Beads
            Text(AppStrings.t('section.ruin'), style: _titleStyle),
            Wrap(spacing: 4, children: [
              _envChip(AppStrings.t('damage.allyTabletsOfRuin'), 'Tablets of Ruin', c.ruins.tabletsOfRuin,
                  (v) => _set(c.copyWith(ruins: c.ruins.copyWith(tabletsOfRuin: v)))),
              _envChip(AppStrings.t('damage.allySwordOfRuin'), 'Sword of Ruin', c.ruins.swordOfRuin,
                  (v) => _set(c.copyWith(ruins: c.ruins.copyWith(swordOfRuin: v)))),
              _envChip(AppStrings.t('damage.allyVesselOfRuin'), 'Vessel of Ruin', c.ruins.vesselOfRuin,
                  (v) => _set(c.copyWith(ruins: c.ruins.copyWith(vesselOfRuin: v)))),
              _envChip(AppStrings.t('damage.allyBeadsOfRuin'), 'Beads of Ruin', c.ruins.beadsOfRuin,
                  (v) => _set(c.copyWith(ruins: c.ruins.copyWith(beadsOfRuin: v)))),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _set(c.copyWith(
              weather: Weather.none, terrain: Terrain.none, room: const RoomConditions())),
          child: Text(AppStrings.t('toolbar.conditionsReset')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.t('action.close')),
        ),
      ],
    );
  }
}
