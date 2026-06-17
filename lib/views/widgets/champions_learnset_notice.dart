import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_strings.dart';

/// One-shot notice shown after the 2026-06-17 in-game roster
/// expansion. Learnsets for the new Champions Pokémon haven't
/// been datamined upstream (ChampionsLab) yet, so the move pool
/// we surface for them is inherited from Showdown's broader SV
/// pool — which can include moves that the Champions release
/// no longer teaches, or miss moves it does. Dismisses
/// permanently via "다시 보지 않기" (same dismiss semantics as
/// the other prompts in the boot sequence).
class ChampionsLearnsetNotice {
  ChampionsLearnsetNotice._();

  static const _dismissedKey = 'champions_learnset_notice_v1';

  /// Call from a screen's first-frame callback after any
  /// higher-priority prompts (sprite-pack update, install
  /// banner) have settled.
  static Future<void> maybeShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_dismissedKey) ?? false) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => const _NoticeDialog(),
    );
  }

  static Future<void> markDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }
}

class _NoticeDialog extends StatelessWidget {
  const _NoticeDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppStrings.t('notice.championsLearnsetTitle')),
      content: Text(
        AppStrings.t('notice.championsLearnsetBody'),
        style: const TextStyle(height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await ChampionsLearnsetNotice.markDismissed();
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(AppStrings.t('action.dontShowAgain')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.t('action.ok')),
        ),
      ],
    );
  }
}
