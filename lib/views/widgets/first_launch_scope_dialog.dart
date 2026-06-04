import 'package:flutter/material.dart';

import '../../utils/app_strings.dart';
import '../../utils/champions_filter_controller.dart';
import '../../utils/simple_mode_controller.dart';

/// First-launch (including existing users) onboarding prompt. Two
/// blocking questions, no defaults — the user must explicitly pick
/// both Pokémon scope (Champions-only / all) and calculator mode
/// (simple / extended) before the calculator becomes interactive.
///
/// User direction: every user sees this exactly once after the
/// update, and there is no preselection — explicit pick required.
/// PopScope blocks system back; barrierDismissible:false on the
/// showDialog wrapper handles outside taps.
class FirstLaunchScopeDialog extends StatefulWidget {
  const FirstLaunchScopeDialog({super.key});

  @override
  State<FirstLaunchScopeDialog> createState() =>
      _FirstLaunchScopeDialogState();
}

class _FirstLaunchScopeDialogState extends State<FirstLaunchScopeDialog> {
  bool? _championsOnly;
  bool? _simpleMode;

  bool get _canSubmit => _championsOnly != null && _simpleMode != null;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    await ChampionsFilterController.instance
        .answerPrompt(championsOnlyChoice: _championsOnly!);
    await SimpleModeController.instance.setSimple(_simpleMode!);
    if (mounted) Navigator.of(context).pop();
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _questionHeader(AppStrings.t('firstLaunch.scopeLabel')),
              _radioTile<bool>(
                value: true,
                groupValue: _championsOnly,
                label: AppStrings.t('firstLaunch.scopeChampions'),
                onChanged: (v) => setState(() => _championsOnly = v),
              ),
              _radioTile<bool>(
                value: false,
                groupValue: _championsOnly,
                label: AppStrings.t('firstLaunch.scopeAll'),
                onChanged: (v) => setState(() => _championsOnly = v),
              ),
              const SizedBox(height: 12),
              _questionHeader(AppStrings.t('firstLaunch.modeLabel')),
              _radioTile<bool>(
                value: true,
                groupValue: _simpleMode,
                label: AppStrings.t('firstLaunch.modeSimple'),
                onChanged: (v) => setState(() => _simpleMode = v),
              ),
              _radioTile<bool>(
                value: false,
                groupValue: _simpleMode,
                label: AppStrings.t('firstLaunch.modeExtended'),
                onChanged: (v) => setState(() => _simpleMode = v),
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
        actions: [
          ElevatedButton(
            onPressed: _canSubmit ? _submit : null,
            child: Text(AppStrings.t('firstLaunch.start')),
          ),
        ],
      ),
    );
  }

  Widget _questionHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600)),
      );

  Widget _radioTile<T>({
    required T value,
    required T? groupValue,
    required String label,
    required ValueChanged<T?> onChanged,
  }) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade500,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13)),
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
