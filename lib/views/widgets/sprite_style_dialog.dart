import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../utils/app_strings.dart';
import '../../utils/sprite_service.dart';

/// Open the sprite style picker. Used both from the calculator's
/// overflow menu and from the [PokemonSprite] placeholder's tap
/// target.
Future<void> showSpriteStyleDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const SpriteStyleDialog(),
  );
}

/// Sprite-style picker: three radio rows for BW / animated / HOME 3D
/// plus a credit blurb. Mobile sees a notice that sprites are
/// web-only for now — the on-device pack import flow is deferred to
/// a follow-up release while we work out an App Store-compatible
/// distribution path.
class SpriteStyleDialog extends StatelessWidget {
  const SpriteStyleDialog({super.key});

  static const _styleLabelKeys = {
    SpriteStyle.bw: 'sprite.style.bw',
    SpriteStyle.ani: 'sprite.style.ani',
    SpriteStyle.dex: 'sprite.style.dex',
  };

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return AlertDialog(
      title: Text(AppStrings.t('app.spriteStyle')),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      content: ListenableBuilder(
        listenable: SpriteService.instance,
        builder: (ctx, _) {
          final selected = SpriteService.instance.style;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in SpriteStyle.values)
                if (kIsWeb)
                  RadioListTile<SpriteStyle>(
                    value: s,
                    groupValue: selected,
                    onChanged: (v) {
                      if (v != null) SpriteService.instance.setStyle(v);
                    },
                    title: Text(AppStrings.t(_styleLabelKeys[s]!)),
                    dense: true,
                  ),
              if (!kIsWeb)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    AppStrings.t('sprite.mobileNotice'),
                    style: TextStyle(fontSize: 12, color: hint, height: 1.4),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  AppStrings.t('sprite.creditBody'),
                  style: TextStyle(fontSize: 11, color: hint, height: 1.4),
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.t('action.close')),
        ),
      ],
    );
  }
}
