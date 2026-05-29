import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/pokemon.dart';
import '../../utils/app_strings.dart';
import '../../utils/party_image_save.dart';
import 'pokemon_sprite.dart';

/// Editor + capture flow for the trainer-card image. Layout:
///
///   ┌─────────────────────────────────────────┐
///   │ TRAINER CARD                            │
///   │ ○ {name}                                │
///   │                                         │
///   │ [P1] [P2] [P3]            [avatar]      │
///   │ [P4] [P5] [P6]                          │
///   │                                         │
///   │ 시즌: {season}              {score}점   │
///   └─────────────────────────────────────────┘
///
/// All fields are user-editable and persisted across launches via
/// SharedPreferences (name / season / score as strings, avatar bytes
/// as a base64 string keyed by `trainer_card.avatar_b64`).
class TrainerCardDialog extends StatefulWidget {
  /// 6-slot party — null entries render as empty tiles in the grid.
  /// Caller passes whatever's currently loaded in the team builder.
  final List<Pokemon?> party;

  const TrainerCardDialog({super.key, required this.party});

  @override
  State<TrainerCardDialog> createState() => _TrainerCardDialogState();
}

class _TrainerCardDialogState extends State<TrainerCardDialog> {
  static const _kName = 'trainer_card.name';
  static const _kSeason = 'trainer_card.season';
  static const _kScore = 'trainer_card.score';
  static const _kAvatarB64 = 'trainer_card.avatar_b64';

  late final TextEditingController _nameCtl;
  late final TextEditingController _seasonCtl;
  late final TextEditingController _scoreCtl;
  Uint8List? _avatarBytes;
  bool _loading = true;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController();
    _seasonCtl = TextEditingController();
    _scoreCtl = TextEditingController();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nameCtl.text = prefs.getString(_kName) ?? '';
      _seasonCtl.text = prefs.getString(_kSeason) ?? '';
      _scoreCtl.text = prefs.getString(_kScore) ?? '';
      final b64 = prefs.getString(_kAvatarB64);
      if (b64 != null && b64.isNotEmpty) {
        try {
          _avatarBytes = base64Decode(b64);
        } catch (_) {/* corrupt cache — ignore */}
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _seasonCtl.dispose();
    _scoreCtl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _avatarBytes = bytes);
  }

  Future<void> _persistFields() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, _nameCtl.text);
    await prefs.setString(_kSeason, _seasonCtl.text);
    await prefs.setString(_kScore, _scoreCtl.text);
    if (_avatarBytes != null) {
      await prefs.setString(_kAvatarB64, base64Encode(_avatarBytes!));
    }
  }

  Future<void> _saveAndCapture() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      await _persistFields();
      final bytes = await _renderCard();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${_sanitize(_nameCtl.text.isEmpty
              ? AppStrings.t('trainerCard.defaultName')
              : _nameCtl.text)}_trainer_$stamp.png';
      await savePartyImageBytes(bytes, filename);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t('team.image.saved')),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${AppStrings.t('team.image.failed')}: $e'),
      ));
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[^\w\-가-힣ㄱ-ㅎㅏ-ㅣ]'), '_');

  /// Renders the trainer-card composition off-screen and returns
  /// the resulting PNG bytes. Width is fixed (560 logical px) for a
  /// consistent share-friendly output size on any device.
  Future<Uint8List> _renderCard() async {
    final scheme = Theme.of(context).colorScheme;
    final boundaryKey = GlobalKey();
    final score = _scoreCtl.text.trim();
    final season = _seasonCtl.text.trim();
    final name = _nameCtl.text.trim().isEmpty
        ? AppStrings.t('trainerCard.defaultName')
        : _nameCtl.text.trim();
    final card = Material(
      color: Colors.white,
      child: RepaintBoundary(
        key: boundaryKey,
        child: Container(
          width: 560,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title band — flat coloured pill, no gradient effects
              // so the rendering stays predictable across themes.
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'TRAINER CARD',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              // Name row — circle bullet then large name.
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.amber.shade700, width: 2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Body row — 3x2 sprite grid on the left, avatar on
              // the right.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 1.0,
                      children: [
                        for (int i = 0; i < 6; i++)
                          _spriteTile(scheme, widget.party[i]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Avatar slot — fixed 140×180 portrait so the
                  // user's character image gets the dominant
                  // visual weight (matches the reference layout).
                  SizedBox(
                    width: 140,
                    height: 180,
                    child: _avatarBytes == null
                        ? Container(
                            color: Colors.grey.shade100,
                            alignment: Alignment.center,
                            child: Text(
                              AppStrings.t('trainerCard.avatarMissing'),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : Image.memory(
                            _avatarBytes!,
                            fit: BoxFit.cover,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Footer — season (free text) + optional score.
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: Colors.amber.shade300, width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        season.isEmpty ? '' : season,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (score.isNotEmpty)
                      Text(
                        '$score${AppStrings.t('trainerCard.scoreSuffix')}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Off-screen render so the user doesn't see a flash before the
    // capture. Same OverlayEntry+Positioned(-10000) pattern as the
    // party-image export.
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned(left: -10000, top: 0, child: card),
    );
    overlay.insert(entry);
    try {
      await Future.delayed(const Duration(milliseconds: 250));
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('RepaintBoundary missing render object');
      }
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('PNG encoding returned no bytes');
      }
      return byteData.buffer.asUint8List();
    } finally {
      entry.remove();
    }
  }

  Widget _spriteTile(ColorScheme scheme, Pokemon? p) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: p == null
          ? const SizedBox.shrink()
          : Center(
              child: PokemonSprite(pokemonName: p.name, size: 80),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AlertDialog(
        content: SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    return AlertDialog(
      title: Text(AppStrings.t('trainerCard.title')),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar picker — preview + tap to choose / change.
              Center(
                child: GestureDetector(
                  onTap: _capturing ? null : _pickAvatar,
                  child: Container(
                    width: 120,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _avatarBytes == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined,
                                  color: Colors.grey.shade500, size: 32),
                              const SizedBox(height: 6),
                              Text(
                                AppStrings.t('trainerCard.pickAvatar'),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(_avatarBytes!,
                                fit: BoxFit.cover),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtl,
                decoration: InputDecoration(
                  labelText: AppStrings.t('trainerCard.nameLabel'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                maxLength: 24,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _seasonCtl,
                decoration: InputDecoration(
                  labelText: AppStrings.t('trainerCard.seasonLabel'),
                  hintText: AppStrings.t('trainerCard.seasonHint'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                maxLength: 30,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _scoreCtl,
                decoration: InputDecoration(
                  labelText: AppStrings.t('trainerCard.scoreLabel'),
                  hintText: AppStrings.t('trainerCard.scoreHint'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: 10,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _capturing ? null : () => Navigator.pop(context),
          child: Text(AppStrings.t('action.cancel')),
        ),
        ElevatedButton(
          onPressed: _capturing ? null : _saveAndCapture,
          child: _capturing
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(AppStrings.t('trainerCard.save')),
        ),
      ],
    );
  }
}
