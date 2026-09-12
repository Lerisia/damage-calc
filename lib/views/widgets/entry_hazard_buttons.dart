import 'package:flutter/material.dart';

import '../../utils/app_strings.dart';
import '../../utils/entry_hazards.dart';

/// The 스록 / 압정 mini-buttons next to the defender's HP % input, shared
/// by the extended stat table and Simple Mode so both behave the same.
///
/// One-shot: each tap knocks the HP % by that hazard's switch-in damage
/// (see `applyEntryHazard`). Stealth Rock disables itself after one tap;
/// Spikes counts up to three layers and shows the count. The owner
/// resets both when the species changes or the HP is edited by hand.
class EntryHazardButtons extends StatelessWidget {
  final bool stealthRockApplied;
  final int spikesLayers;
  final ValueChanged<EntryHazard> onTap;

  const EntryHazardButtons({
    super.key,
    required this.stealthRockApplied,
    required this.spikesLayers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _mini(
          context,
          label: AppStrings.t('hazard.stealthRock'),
          tooltip: AppStrings.t('hazard.stealthRockFull'),
          enabled: !stealthRockApplied,
          onPressed: () => onTap(EntryHazard.stealthRock),
        ),
        const SizedBox(width: 4),
        _mini(
          context,
          label: spikesLayers == 0
              ? AppStrings.t('hazard.spikes')
              : '${AppStrings.t('hazard.spikes')} $spikesLayers',
          tooltip: AppStrings.t('hazard.spikesFull'),
          enabled: spikesLayers < 3,
          onPressed: () => onTap(EntryHazard.spikes),
        ),
      ],
    );
  }

  Widget _mini(BuildContext context,
      {required String label,
      required String tooltip,
      required bool enabled,
      required VoidCallback onPressed}) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: 22,
        child: OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: Text(label, style: const TextStyle(fontSize: 11)),
        ),
      ),
    );
  }
}
