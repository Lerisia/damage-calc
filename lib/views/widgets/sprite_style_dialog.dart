import 'dart:io' show File;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

import '../../utils/app_strings.dart';
import '../../utils/sprite_pack_manager.dart';
import '../../utils/sprite_service.dart';
import 'sprite_credits_dialog.dart';
import 'sprite_override_dialog.dart';

/// Open the sprite style + pack-management dialog. Used both from
/// the calculator's overflow menu and from the [PokemonSprite]
/// placeholder's tap target.
Future<void> showSpriteStyleDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const SpriteStyleDialog(),
  );
}

/// Sprite style + pack-management dialog. On web it's a plain
/// style picker (the web build streams sprites directly from
/// Showdown's CDN and has no pack-import flow). On mobile each
/// style row gains 다운로드 / 가져오기 / 제거 controls so users
/// can manage their imported packs without leaving the dialog.
class SpriteStyleDialog extends StatefulWidget {
  const SpriteStyleDialog({super.key});

  @override
  State<SpriteStyleDialog> createState() => _SpriteStyleDialogState();
}

class _SpriteStyleDialogState extends State<SpriteStyleDialog> {
  final Map<SpriteStyle, bool> _busy = {
    for (final s in SpriteStyle.values) s: false,
  };

  static const _styleLabelKeys = {
    SpriteStyle.bw: 'sprite.style.bw',
    SpriteStyle.ani: 'sprite.style.ani',
    SpriteStyle.dex: 'sprite.style.dex',
  };

  /// `/releases/latest/download/<name>` always resolves to whatever
  /// the most-recent release tags as that asset, so the URL stays
  /// correct as the nightly pack-build workflow re-publishes.
  String _downloadUrl(SpriteStyle style) =>
      'https://github.com/Lerisia/damage-calc-sprite-pack/'
      'releases/latest/download/${style.name}.zip';

  Future<void> _pickAndImport(SpriteStyle style) async {
    setState(() => _busy[style] = true);
    try {
      // No XTypeGroup filter — both iOS UIDocumentPickerViewController
      // and Android SAF hide downloaded files from "Recent" when we
      // restrict to application/zip + public.zip-archive (GitHub
      // releases sometimes ship as application/octet-stream, and
      // Safari downloads aren't always tagged with the zip UTI). We
      // accept any file and validate the ZIP contents inside
      // installFromZip, which surfaces a clear error for non-zip /
      // wrong-style picks.
      // file_selector is the Flutter team's official picker — we
      // moved off file_picker 8.x after it caused Apple's TestFlight
      // pipeline to silently drop our IPAs (see
      // feedback_file_picker_ios_silent_drop.md).
      final picked = await openFile();
      if (picked == null) return;
      final n = await SpritePackManager.instance
          .installFromZip(File(picked.path), style);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t('sprite.importedCount')
            .replaceAll('{n}', '$n')),
        duration: const Duration(seconds: 3),
      ));
    } on FormatException catch (e) {
      if (!mounted) return;
      final messageKey = e.message == 'Not a ZIP archive'
          ? 'sprite.importNotZip'
          : 'sprite.importWrongStyle';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t(messageKey)),
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
              // Wrap (not Row) so the three buttons reflow onto a
              // second line on narrow screens instead of overflowing.
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _PackActionButton(
                    icon: Icons.download,
                    labelKey: 'sprite.downloadPack',
                    onPressed: busy
                        ? null
                        : () => ul.launchUrl(
                            Uri.parse(_downloadUrl(s)),
                            mode: ul.LaunchMode.externalApplication),
                  ),
                  _PackActionButton(
                    icon: busy ? null : Icons.folder_open,
                    busy: busy,
                    labelKey: 'sprite.importZip',
                    onPressed: busy ? null : () => _pickAndImport(s),
                  ),
                  if (installed)
                    _PackActionButton(
                      icon: Icons.delete_outline,
                      labelKey: 'sprite.removePack',
                      foreground: Colors.redAccent,
                      onPressed:
                          busy ? null : () => _confirmAndRemove(s),
                    ),
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
    // Constrain the dialog content to the viewport — without this,
    // long button labels (특히 Korean '이미지팩 다운로드' / 'Download
    // sprite pack') push the row past the dialog's chrome on narrow
    // phones. ConstrainedBox with the MediaQuery width cap forces
    // the inner Wrap to actually wrap.
    final maxWidth = MediaQuery.of(context).size.width - 80;
    final width = maxWidth.clamp(280.0, 380.0);
    return AlertDialog(
      title: Text(AppStrings.t('app.spriteStyle')),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: ListenableBuilder(
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
                      style:
                          TextStyle(fontSize: 12, color: hint, height: 1.4),
                    ),
                  ),
                for (final s in SpriteStyle.values)
                  // hasMobilePack==false (only `ani`) → hidden
                  // everywhere until we ship a source for it.
                  if (s.hasMobilePack) _styleRow(s),
                const Divider(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => showSpriteOverrideDialog(context),
                    icon: const Icon(Icons.tune, size: 18),
                    label: Text(AppStrings.t('sprite.override.menu')),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => showSpriteCreditsDialog(context),
                    icon: const Icon(Icons.people_outline, size: 18),
                    label:
                        Text(AppStrings.t('sprite.credits.viewCredits')),
                  ),
                ),
              ],
            ),
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

/// Compact icon+text button used in the style row. Smaller padding +
/// the optional CircularProgressIndicator-as-icon variant lets the
/// three actions fit on one or two lines without busting out of the
/// dialog width.
class _PackActionButton extends StatelessWidget {
  final IconData? icon;
  final String labelKey;
  final bool busy;
  final Color? foreground;
  final VoidCallback? onPressed;

  const _PackActionButton({
    required this.icon,
    required this.labelKey,
    this.busy = false,
    this.foreground,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = busy
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon ?? Icons.help_outline, size: 16);
    return TextButton.icon(
      onPressed: onPressed,
      icon: iconWidget,
      label: Text(AppStrings.t(labelKey),
          style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: foreground,
      ),
    );
  }
}
