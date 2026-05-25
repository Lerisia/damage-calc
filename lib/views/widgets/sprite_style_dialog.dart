import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

import '../../utils/app_strings.dart';
import '../../utils/sprite_pack_manager.dart';
import '../../utils/sprite_service.dart';

/// Open the sprite style + pack-management dialog. Used both from
/// the calculator's overflow menu and from the [PokemonSprite]
/// placeholder's tap target, so the same UI surface handles "I
/// want to change style" and "what is this pokéball, can I fix it?".
Future<void> showSpriteStyleDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const SpriteStyleDialog(),
  );
}

/// Sprite style + pack-management dialog.
///
/// Listens on [SpriteService] and [SpritePackManager] so the row for
/// each style refreshes the moment its install state or active
/// status changes. On web the per-style management controls are
/// hidden — the web build streams from Showdown directly and has
/// nothing to install.
class SpriteStyleDialog extends StatefulWidget {
  const SpriteStyleDialog({super.key});

  @override
  State<SpriteStyleDialog> createState() => _SpriteStyleDialogState();
}

class _SpriteStyleDialogState extends State<SpriteStyleDialog> {
  /// Per-style "currently importing/removing" flag. Disables the row's
  /// buttons + shows a progress spinner so users don't double-tap.
  final Map<SpriteStyle, bool> _busy = {
    for (final s in SpriteStyle.values) s: false,
  };

  static const _styleLabelKeys = {
    SpriteStyle.bw: 'sprite.style.bw',
    SpriteStyle.ani: 'sprite.style.ani',
    SpriteStyle.dex: 'sprite.style.dex',
  };

  /// Stable URL — GitHub redirects `/releases/latest/download/<name>`
  /// to whatever the latest release tags as that asset. The
  /// damage-calc-sprite-pack workflow re-publishes nightly under the
  /// same `latest` tag, so this URL always points at the freshest
  /// pack without us having to ship a new app build.
  String _downloadUrl(SpriteStyle style) =>
      'https://github.com/Lerisia/damage-calc-sprite-pack/'
      'releases/latest/download/${style.name}.zip';

  Future<void> _pickAndImport(SpriteStyle style) async {
    setState(() => _busy[style] = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        withData: false,
      );
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      final n = await SpritePackManager.instance.installFromZip(file, style);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t('sprite.importedCount')
            .replaceAll('{n}', '$n')),
        duration: const Duration(seconds: 3),
      ));
    } on FormatException {
      // Style-mismatch case is common enough to deserve a tailored
      // message instead of the generic 'import failed: ...'.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t('sprite.importWrongStyle')),
        duration: const Duration(seconds: 4),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t('sprite.importFailed')
            .replaceAll('{err}', e.toString())),
        duration: const Duration(seconds: 5),
      ));
    } finally {
      if (mounted) setState(() => _busy[style] = false);
    }
  }

  Future<void> _confirmAndRemove(SpriteStyle style) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(AppStrings.t('sprite.confirmRemove')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.t('action.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.t('sprite.removePack')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy[style] = true);
    await SpritePackManager.instance.clear(style);
    if (mounted) setState(() => _busy[style] = false);
  }

  Widget _styleRow(SpriteStyle s) {
    final hint = Theme.of(context).hintColor;
    final selected = SpriteService.instance.style == s;
    final installed = SpritePackManager.instance.isInstalled(s);
    final busy = _busy[s] ?? false;

    final stateBadge = kIsWeb
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              installed
                  ? AppStrings.t('sprite.installed')
                  : AppStrings.t('sprite.notInstalled'),
              style: TextStyle(
                fontSize: 11,
                color: installed ? Colors.green : hint,
                fontWeight: FontWeight.w600,
              ),
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => SpriteService.instance.setStyle(s),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Radio<SpriteStyle>(
                    value: s,
                    groupValue: SpriteService.instance.style,
                    onChanged: (v) {
                      if (v != null) SpriteService.instance.setStyle(v);
                    },
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 4),
                  Text(AppStrings.t(_styleLabelKeys[s]!),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      )),
                  stateBadge,
                ],
              ),
            ),
          ),
          if (!kIsWeb)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 8, 6),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => ul.launchUrl(
                            Uri.parse(_downloadUrl(s)),
                            mode: ul.LaunchMode.externalApplication),
                    icon: const Icon(Icons.download, size: 16),
                    label: Text(AppStrings.t('sprite.downloadPack'),
                        style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: busy ? null : () => _pickAndImport(s),
                    icon: busy
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder_open, size: 16),
                    label: Text(AppStrings.t('sprite.importZip'),
                        style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  if (installed) ...[
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: busy ? null : () => _confirmAndRemove(s),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: Text(AppStrings.t('sprite.removePack'),
                          style: const TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: Colors.redAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return AlertDialog(
      title: Text(AppStrings.t('app.spriteStyle')),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      content: SizedBox(
        width: 360,
        child: ListenableBuilder(
          // Either source can change while the dialog is open.
          listenable: Listenable.merge([
            SpriteService.instance,
            SpritePackManager.instance,
          ]),
          builder: (ctx, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!kIsWeb)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    AppStrings.t('sprite.importHowTo'),
                    style: TextStyle(fontSize: 12, color: hint, height: 1.4),
                  ),
                ),
              for (final s in SpriteStyle.values)
                // Hide styles without a downloadable pack on mobile —
                // selecting them would just leave the user staring at
                // pokéballs with no way to fix it. Web stays
                // unfiltered (it streams from Showdown's CDN
                // directly, no pack involved).
                if (kIsWeb || s.hasMobilePack) _styleRow(s),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  AppStrings.t('sprite.creditBody'),
                  style: TextStyle(fontSize: 11, color: hint, height: 1.4),
                ),
              ),
            ],
          ),
        ),
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
