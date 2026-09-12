import 'package:flutter/material.dart';

import '../../models/nature_profile.dart';
import '../../utils/app_strings.dart';

/// One half of a nature picker — the ↑ or ↓ stat — as a popup menu.
/// Shared by StatInput, the speed tab and the team builder, which each
/// used to carry their own copy of this menu and its enum plumbing.
///
/// Emits the whole updated [NatureProfile] so callers don't repeat the
/// copyWith / clear dance.
class NaturePickMenu extends StatelessWidget {
  final NatureProfile nature;
  final bool isUp;
  final ValueChanged<NatureProfile> onNatureChanged;

  /// Label size inside the field. 16 matches TextField's bodyLarge so
  /// the picker lines up with a typeahead on the same row; the team
  /// builder's denser popup uses 14.
  final double labelFontSize;

  const NaturePickMenu({
    super.key,
    required this.nature,
    required this.isUp,
    required this.onNatureChanged,
    this.labelFontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final value = isUp ? nature.up : nature.down;
    final tint = isUp ? Colors.red : Colors.blue;
    final label = value == null ? AppStrings.t('nature.none') : natureStatLabel(value);
    final textColor = value == null ? Colors.grey : tint;
    // PopupMenuButton.onSelected is NOT called when the selected value
    // is null — Flutter routes that to onCanceled — so the menu works
    // on a non-nullable wrapper and maps `none` back to null here.
    // Without this, users couldn't pick "None" after choosing a stat.
    final pickValue = value == null ? _NaturePick.none : _NaturePick.of(value);
    return PopupMenuButton<_NaturePick>(
      initialValue: pickValue,
      tooltip: AppStrings.t(isUp ? 'nature.buffLabel' : 'nature.nerfLabel'),
      popUpAnimationStyle:
          AnimationStyle(duration: const Duration(milliseconds: 100)),
      itemBuilder: (_) => [
        PopupMenuItem<_NaturePick>(
          value: _NaturePick.none,
          child: Text(AppStrings.t('nature.none'),
              style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ),
        for (final s in NatureStat.values)
          PopupMenuItem<_NaturePick>(
            value: _NaturePick.of(s),
            child: Text(natureStatLabel(s),
                style: TextStyle(fontSize: 14, color: tint)),
          ),
      ],
      onSelected: (v) {
        final stat = v.stat;
        onNatureChanged(isUp
            ? nature.copyWith(up: stat, clearUp: stat == null)
            : nature.copyWith(down: stat, clearDown: stat == null));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: AppStrings.t(isUp ? 'nature.buffLabel' : 'nature.nerfLabel'),
          isDense: true,
        ),
        child: Text(label, style: TextStyle(fontSize: labelFontSize, color: textColor)),
      ),
    );
  }
}

/// Localized stat name for a nature slot.
String natureStatLabel(NatureStat s) => switch (s) {
      NatureStat.atk => AppStrings.t('stat.attack'),
      NatureStat.def => AppStrings.t('stat.defense'),
      NatureStat.spa => AppStrings.t('stat.spAttack'),
      NatureStat.spd => AppStrings.t('stat.spDefense'),
      NatureStat.spe => AppStrings.t('stat.speed'),
    };

/// Non-nullable menu value: see the onSelected note in [NaturePickMenu].
enum _NaturePick {
  none, atk, def, spa, spd, spe;

  static _NaturePick of(NatureStat s) => switch (s) {
        NatureStat.atk => atk,
        NatureStat.def => def,
        NatureStat.spa => spa,
        NatureStat.spd => spd,
        NatureStat.spe => spe,
      };

  NatureStat? get stat => switch (this) {
        none => null,
        atk => NatureStat.atk,
        def => NatureStat.def,
        spa => NatureStat.spa,
        spd => NatureStat.spd,
        spe => NatureStat.spe,
      };
}
