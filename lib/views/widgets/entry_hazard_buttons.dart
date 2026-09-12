import 'package:flutter/material.dart';

import '../../utils/app_strings.dart';

/// The 스록 mini-button next to the defender's HP % input, shared by the
/// extended stat table and Simple Mode so both behave the same.
///
/// One-shot and repeatable: every tap knocks the HP % by one Stealth
/// Rock switch-in (see `applyStealthRock`). No state.
class StealthRockButton extends StatelessWidget {
  final VoidCallback onTap;

  const StealthRockButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppStrings.t('hazard.stealthRockFull'),
      child: SizedBox(
        height: 22,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: Text(AppStrings.t('hazard.stealthRock'),
              style: const TextStyle(fontSize: 11)),
        ),
      ),
    );
  }
}
