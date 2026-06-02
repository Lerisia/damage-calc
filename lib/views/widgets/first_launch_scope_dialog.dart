import 'package:flutter/material.dart';

import '../../utils/app_strings.dart';
import '../../utils/champions_filter_controller.dart';

/// First-launch (including existing users) prompt that forces the
/// user to pick between Champions-only and full-Pokédex scope
/// before they can interact with the calculator. PopScope blocks
/// system back; barrierDismissible is off and there is no close
/// button — selecting one of the two options is the only exit.
///
/// The user's pick is persisted via
/// [ChampionsFilterController.answerPrompt] which sets both the
/// scope value and a 'prompt shown' flag so the dialog doesn't
/// pop again on subsequent launches.
class FirstLaunchScopeDialog extends StatelessWidget {
  const FirstLaunchScopeDialog({super.key});

  Future<void> _pick(BuildContext context, bool championsOnly) async {
    await ChampionsFilterController.instance
        .answerPrompt(championsOnlyChoice: championsOnly);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.t('firstLaunch.welcomeTitle'),
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.t('firstLaunch.welcomeSub'),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey.shade700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.t('firstLaunch.scopeLabel'),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _pick(context, true),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                AppStrings.t('firstLaunch.scopeChampions'),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _pick(context, false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                AppStrings.t('firstLaunch.scopeAll'),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.t('firstLaunch.scopeNote'),
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Show the first-launch prompt after the first frame if the user
/// hasn't answered it yet. Safe to call multiple times — only
/// fires when [ChampionsFilterController.promptShown] is false.
void maybeShowFirstLaunchScopePrompt(BuildContext context) {
  if (ChampionsFilterController.instance.promptShown) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    if (ChampionsFilterController.instance.promptShown) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FirstLaunchScopeDialog(),
    );
  });
}
