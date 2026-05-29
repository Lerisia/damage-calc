import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/trainer_aliases.dart';
import '../../models/pokemon.dart';
import '../../models/type.dart';
import '../../utils/app_strings.dart';
import '../../utils/localization.dart';
import '../../utils/party_image_save.dart';
import 'pokemon_sprite.dart';

/// Pre-bundled trainer sprites under assets/trainers/<key>.png —
/// 1455 entries mirroring Showdown's full trainer sprite folder.
/// Same Smogon Sprite Project provenance as the pokemon-side
/// packs (non-profit-with-credit). The picker loads the actual
/// list at runtime from [AssetManifest] so we don't have to
/// hand-maintain a list of that size in source.
String _trainerAssetPath(String key) => 'assets/trainers/$key.png';

/// Choice between the bundled curated set and a gallery upload.
/// Surfaced via [_openAvatarPicker] so the user is asked once per
/// avatar change rather than baking the source into the editor UI.
enum _AvatarSource { curated, upload }

/// Scrollable grid picker over the 1455 bundled trainer sprites
/// with a top-of-dialog search bar. Substring-matches on a
/// per-key corpus that combines the raw asset key with localized
/// aliases (Korean / Japanese / common English nicknames) — so
/// typing '레드' or 'レッド' surfaces the same Red sprites as
/// 'red'. Returns the selected key via Navigator.pop.
class _CuratedTrainerPicker extends StatefulWidget {
  final List<String> allKeys;
  const _CuratedTrainerPicker({required this.allKeys});

  @override
  State<_CuratedTrainerPicker> createState() =>
      _CuratedTrainerPickerState();
}

class _CuratedTrainerPickerState extends State<_CuratedTrainerPicker> {
  final _searchCtl = TextEditingController();
  TrainerCategory _category = TrainerCategory.all;
  /// When false the picker hides every key with a hyphen suffix
  /// (per-game / spinoff variants of the same character or class).
  /// 562 canonical sprites vs 893 variants out of 1455 total —
  /// off-by-default gives a much shorter scroll for users who just
  /// want 'modern Cynthia' and don't care about her gen-4 vs
  /// gen-4-DP vs Masters variants. Toggle on to see all.
  bool _showVariants = false;

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  String _categoryLabel(TrainerCategory c) => switch (c) {
        TrainerCategory.all =>
          AppStrings.t('trainerCard.category.all'),
        TrainerCategory.champion =>
          AppStrings.t('trainerCard.category.champion'),
        TrainerCategory.gymLeader =>
          AppStrings.t('trainerCard.category.gymLeader'),
        TrainerCategory.eliteFour =>
          AppStrings.t('trainerCard.category.eliteFour'),
        TrainerCategory.protagonistRival =>
          AppStrings.t('trainerCard.category.protagonistRival'),
        TrainerCategory.npc =>
          AppStrings.t('trainerCard.category.npc'),
        TrainerCategory.other =>
          AppStrings.t('trainerCard.category.other'),
      };


  @override
  Widget build(BuildContext context) {
    final query = _searchCtl.text.trim().toLowerCase();
    final byCategory = _category == TrainerCategory.all
        ? widget.allKeys
        : widget.allKeys
            .where((k) => trainerCategoryOf(k) == _category)
            .toList();
    final byVariant = _showVariants
        ? byCategory
        : byCategory.where((k) => !k.contains('-')).toList();
    final filtered = query.isEmpty
        ? byVariant
        : byVariant
            .where((k) => trainerSearchCorpus(k).any((s) => s.contains(query)))
            .toList();
    return Dialog(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: 520, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.t('trainerCard.avatarSource.curated'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Category chips — horizontal-scrollable so they fit on
            // narrow widths without wrapping. ChoiceChip rather than
            // a SegmentedButton because we have 7 options (the
            // material spec caps SegmentedButton at 5).
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final c in TrainerCategory.values) ...[
                    ChoiceChip(
                      label: Text(_categoryLabel(c)),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Search row + variants toggle. Variants off shows the
            // canonical (no-suffix) sprite per character/class —
            // ~562 entries vs 1455 total — which is the right
            // default for picking a 'modern Cynthia'. Toggle on
            // to surface every per-game pixel variant.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtl,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 18),
                        hintText: AppStrings.t('trainerCard.searchHint'),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                        AppStrings.t('trainerCard.showVariants')),
                    selected: _showVariants,
                    onSelected: (v) =>
                        setState(() => _showVariants = v),
                  ),
                ],
              ),
            ),
            if (widget.allKeys.isEmpty)
              const Expanded(
                child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    AppStrings.t('trainerCard.noMatches'),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              Flexible(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final key = filtered[i];
                    return InkWell(
                      onTap: () => Navigator.pop(context, key),
                      child: Container(
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Image.asset(
                          _trainerAssetPath(key),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One party slot worth of trainer-card input. Keeps the trainer
/// card decoupled from `_TeamSlot` (which is private to the team
/// builder screen) — we only need the species + shiny flag.
class TrainerCardSlot {
  final Pokemon? pokemon;
  final bool shiny;
  const TrainerCardSlot({required this.pokemon, required this.shiny});
}

/// Score-prefix choice the user picks before the numeric score —
/// per user direction, score should never appear naked: it's
/// always one of '최종 / 최고 / 현재' so the reader knows what
/// the number actually represents.
/// Frame/accent color presets for the trainer card — one per
/// Pokémon type. Per user direction: instead of a generic
/// palette ('amber', 'red', 'blue', …) we name the themes after
/// the 18 main-line types and pull the canonical type color from
/// [Localization.typeColor]. The selected type's name shows next
/// to the swatch row so the user knows they're picking "fire"
/// vs just "orange".
///
/// The card needs three shades for its frame:
///   - accent → title pill background, avatar ring, score text
///   - border → footer border
///   - tint   → footer background fill
/// Type colors are single values rather than MaterialColor
/// ramps, so we derive the lighter shades via Color.lerp toward
/// white — close enough for the card's flat look without per-type
/// hand-tuning.
class TrainerCardTheme {
  final String prefsValue;
  final PokemonType type;
  final Color base;

  const TrainerCardTheme({
    required this.prefsValue,
    required this.type,
    required this.base,
  });

  Color get accent => base;
  Color get border => Color.lerp(base, Colors.white, 0.55)!;
  Color get tint => Color.lerp(base, Colors.white, 0.88)!;

  String localizedName() => KoStrings.getTypeName(type);

  /// 18 themes in the canonical Pokédex type order, derived from
  /// [Localization.typeColor] so any future palette tweak there
  /// propagates here for free.
  static final List<TrainerCardTheme> all = [
    for (final t in const [
      PokemonType.normal, PokemonType.fire, PokemonType.water,
      PokemonType.electric, PokemonType.grass, PokemonType.ice,
      PokemonType.fighting, PokemonType.poison, PokemonType.ground,
      PokemonType.flying, PokemonType.psychic, PokemonType.bug,
      PokemonType.rock, PokemonType.ghost, PokemonType.dragon,
      PokemonType.dark, PokemonType.steel, PokemonType.fairy,
    ])
      TrainerCardTheme(
        prefsValue: t.name,
        type: t,
        base: KoStrings.getTypeColor(t),
      ),
  ];

  /// Map the previous generic-palette prefs values onto their
  /// closest type theme so users who saved a card under the old
  /// scheme don't suddenly see a different color on next launch.
  static const _legacyMapping = {
    'amber': 'fire',
    'red': 'fire',
    'deepOrange': 'fire',
    'pink': 'fairy',
    'purple': 'ghost',
    'indigo': 'dragon',
    'blue': 'water',
    'teal': 'water',
    'green': 'grass',
    'brown': 'ground',
    'blueGrey': 'steel',
    'grey': 'normal',
  };

  static TrainerCardTheme fromPrefs(String? raw) {
    final mapped = _legacyMapping[raw] ?? raw;
    for (final t in all) {
      if (t.prefsValue == mapped) return t;
    }
    return all.firstWhere((t) => t.type == PokemonType.fire);
  }
}

enum TrainerCardScorePrefix {
  finalPrefix('final'),
  best('best'),
  current('current');

  final String prefsValue;
  const TrainerCardScorePrefix(this.prefsValue);

  static TrainerCardScorePrefix fromPrefs(String? raw) {
    for (final p in TrainerCardScorePrefix.values) {
      if (p.prefsValue == raw) return p;
    }
    return TrainerCardScorePrefix.finalPrefix;
  }

  String localized() => switch (this) {
        TrainerCardScorePrefix.finalPrefix =>
          AppStrings.t('trainerCard.scorePrefix.final'),
        TrainerCardScorePrefix.best =>
          AppStrings.t('trainerCard.scorePrefix.best'),
        TrainerCardScorePrefix.current =>
          AppStrings.t('trainerCard.scorePrefix.current'),
      };
}

/// Live-preview editor for the trainer-card image.
///
/// Layout: card preview at the top auto-updates as the user types
/// or swaps avatar; form fields sit below. The Save button just
/// captures the same widget tree off-screen and downloads — no
/// separate confirm step, since the preview *is* the confirmation
/// surface.
///
/// All fields are persisted across launches via SharedPreferences
/// (name / season / score / prefix as strings, avatar as either
/// `trainer_card.avatar_asset` for a bundled key or
/// `trainer_card.avatar_b64` for an uploaded photo). Shiny status
/// comes from the party slots verbatim.
class TrainerCardDialog extends StatefulWidget {
  final List<TrainerCardSlot> party;

  const TrainerCardDialog({super.key, required this.party});

  @override
  State<TrainerCardDialog> createState() => _TrainerCardDialogState();
}

class _TrainerCardDialogState extends State<TrainerCardDialog> {
  static const _kName = 'trainer_card.name';
  static const _kSeason = 'trainer_card.season';
  static const _kScore = 'trainer_card.score';
  static const _kScorePrefix = 'trainer_card.score_prefix';
  static const _kAvatarB64 = 'trainer_card.avatar_b64';
  static const _kAvatarAsset = 'trainer_card.avatar_asset';
  static const _kThemeColor = 'trainer_card.theme_color';

  late final TextEditingController _nameCtl;
  late final TextEditingController _seasonCtl;
  late final TextEditingController _scoreCtl;
  /// Uploaded photo bytes — set when the user picks from gallery.
  /// Mutually exclusive with [_avatarAssetKey]; whichever was most
  /// recently chosen is the one that renders.
  Uint8List? _avatarBytes;
  /// Curated-set key (e.g. 'red'). Set when the user picks from
  /// the bundled trainer grid. Resolved to AssetImage at render.
  String? _avatarAssetKey;
  TrainerCardScorePrefix _scorePrefix = TrainerCardScorePrefix.finalPrefix;
  TrainerCardTheme _themeColor = TrainerCardTheme.fromPrefs(null);
  bool _loading = true;
  bool _busy = false;
  /// All trainer keys loaded from AssetManifest. Populated async
  /// in initState; until then the picker just shows a spinner.
  List<String> _allTrainerKeys = const [];

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController();
    _seasonCtl = TextEditingController();
    _scoreCtl = TextEditingController();
    // Live preview: every keystroke triggers a rebuild so the card
    // at the top reflects the new value. setState is cheap because
    // the preview is a single Material widget, no async work.
    _nameCtl.addListener(_rebuild);
    _seasonCtl.addListener(_rebuild);
    _scoreCtl.addListener(_rebuild);
    _loadPrefs();
    _loadTrainerKeys();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// Drop focus from whatever text field is active. Called from
  /// the tap-outside catcher and from every non-text interactive
  /// (chips, color swatches, dropdown, avatar) so the keyboard
  /// reliably goes away when the user moves on to a non-text
  /// control — iOS in particular doesn't auto-dismiss on tap
  /// outside in dialogs, and numeric keyboards have no native
  /// Done button.
  void _dismissKb() => FocusScope.of(context).unfocus();

  Future<void> _loadTrainerKeys() async {
    final manifest =
        await AssetManifest.loadFromAssetBundle(rootBundle);
    final keys = manifest
        .listAssets()
        .where((p) =>
            p.startsWith('assets/trainers/') && p.endsWith('.png'))
        .map((p) => p
            .substring('assets/trainers/'.length)
            .replaceAll(RegExp(r'\.png$'), ''))
        .toList()
      ..sort();
    if (!mounted) return;
    setState(() => _allTrainerKeys = keys);
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nameCtl.text = prefs.getString(_kName) ?? '';
      _seasonCtl.text = prefs.getString(_kSeason) ?? '';
      _scoreCtl.text = prefs.getString(_kScore) ?? '';
      _scorePrefix =
          TrainerCardScorePrefix.fromPrefs(prefs.getString(_kScorePrefix));
      _themeColor =
          TrainerCardTheme.fromPrefs(prefs.getString(_kThemeColor));
      // Asset key takes priority — if a previous session picked
      // from the curated set, restore that selection. We don't
      // gate on _allTrainerKeys here (which loads async) because
      // the asset path is verified at render time anyway; if the
      // bundle no longer contains it the Image.asset call simply
      // throws and we fall back to the placeholder.
      final assetKey = prefs.getString(_kAvatarAsset);
      if (assetKey != null && assetKey.isNotEmpty) {
        _avatarAssetKey = assetKey;
      } else {
        final b64 = prefs.getString(_kAvatarB64);
        if (b64 != null && b64.isNotEmpty) {
          try {
            _avatarBytes = base64Decode(b64);
          } catch (_) {/* corrupt cache — ignore */}
        }
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameCtl.removeListener(_rebuild);
    _seasonCtl.removeListener(_rebuild);
    _scoreCtl.removeListener(_rebuild);
    _nameCtl.dispose();
    _seasonCtl.dispose();
    _scoreCtl.dispose();
    super.dispose();
  }

  /// Avatar picker entry — shows a choice between the bundled
  /// curated trainer grid and a gallery upload. Users without a
  /// ready avatar image can always grab a recognisable trainer
  /// from the curated set; users who want their own photo upload
  /// it directly.
  Future<void> _openAvatarPicker() async {
    final choice = await showDialog<_AvatarSource>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(AppStrings.t('trainerCard.avatarSource.title')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, _AvatarSource.curated),
            child: Text(AppStrings.t('trainerCard.avatarSource.curated')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, _AvatarSource.upload),
            child: Text(AppStrings.t('trainerCard.avatarSource.upload')),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case _AvatarSource.curated:
        await _pickCuratedAvatar();
      case _AvatarSource.upload:
        await _pickUploadedAvatar();
    }
  }

  Future<void> _pickCuratedAvatar() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _CuratedTrainerPicker(allKeys: _allTrainerKeys),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _avatarAssetKey = picked;
      _avatarBytes = null; // mutual-exclusive with upload path
    });
  }

  Future<void> _pickUploadedAvatar() async {
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
    setState(() {
      _avatarBytes = bytes;
      _avatarAssetKey = null;
    });
  }

  Future<void> _persistFields() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, _nameCtl.text);
    await prefs.setString(_kSeason, _seasonCtl.text);
    await prefs.setString(_kScore, _scoreCtl.text);
    await prefs.setString(_kScorePrefix, _scorePrefix.prefsValue);
    await prefs.setString(_kThemeColor, _themeColor.prefsValue);
    // Avatar persistence: asset key and uploaded bytes are mutually
    // exclusive — set whichever the user picked last, clear the
    // other so a stale value doesn't ghost back on the next open.
    if (_avatarAssetKey != null) {
      await prefs.setString(_kAvatarAsset, _avatarAssetKey!);
      await prefs.remove(_kAvatarB64);
    } else if (_avatarBytes != null) {
      await prefs.setString(_kAvatarB64, base64Encode(_avatarBytes!));
      await prefs.remove(_kAvatarAsset);
    } else {
      await prefs.remove(_kAvatarAsset);
      await prefs.remove(_kAvatarB64);
    }
  }

  /// Avatar widget used in both the editor preview slot and the
  /// rendered card. Returns null when the user hasn't picked an
  /// avatar yet so the caller can render a placeholder.
  Widget? _avatarImage({required BoxFit fit}) {
    if (_avatarAssetKey != null) {
      return Image.asset(_trainerAssetPath(_avatarAssetKey!),
          fit: fit, filterQuality: FilterQuality.medium);
    }
    if (_avatarBytes != null) {
      return Image.memory(_avatarBytes!, fit: fit);
    }
    return null;
  }

  Future<void> _saveDirect() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _persistFields();
      final bytes = await _renderCardToBytes();
      if (!mounted) return;
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
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[^\w\-가-힣ㄱ-ㅎㅏ-ㅣ]'), '_');

  /// The card visual tree — used both for the live preview (wrapped
  /// in FittedBox to scale into the dialog) and for capture (wrapped
  /// in RepaintBoundary and rendered off-screen). Width is a fixed
  /// 560 logical px; downstream sizing is decided by the wrapper.
  Widget _buildCardBody() {
    final score = _scoreCtl.text.trim();
    final season = _seasonCtl.text.trim();
    final name = _nameCtl.text.trim().isEmpty
        ? AppStrings.t('trainerCard.defaultName')
        : _nameCtl.text.trim();
    return Material(
      color: Colors.white,
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
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _themeColor.accent,
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
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _themeColor.accent, width: 2),
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
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Column-of-Rows instead of GridView. GridView with
                // shrinkWrap inside an Expanded inside a Row whose
                // height is dominated by the avatar (180 pt) was
                // getting a tight vertical constraint of 180 and
                // padding the empty space at the TOP of its
                // viewport — which is exactly the 'huge gap above
                // the pokemon row' the user reported. Explicit
                // Rows with fixed-height tiles size to their
                // content unambiguously.
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int row = 0; row < 2; row++) ...[
                        if (row > 0) const SizedBox(height: 6),
                        SizedBox(
                          height: 90,
                          child: Row(
                            children: [
                              for (int col = 0; col < 3; col++) ...[
                                if (col > 0) const SizedBox(width: 6),
                                Expanded(
                                  child:
                                      _spriteTile(widget.party[row * 3 + col]),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  height: 186, // matches the 2 × 90 + 6 grid height
                  child: _avatarImage(fit: BoxFit.cover) ??
                      Container(
                        color: Colors.grey.shade100,
                        alignment: Alignment.center,
                        child: Text(
                          AppStrings.t('trainerCard.avatarMissing'),
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500),
                          textAlign: TextAlign.center,
                        ),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _themeColor.tint,
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: _themeColor.border, width: 1),
              ),
              // Center the season+score block as one continuous
              // line instead of pinning to opposite edges. The
              // previous Row+Expanded layout left a wide empty
              // band in the middle that made the text look smaller
              // than it actually was. Wrap drops to a second line
              // gracefully if both strings get unusually long.
              child: Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 14,
                  children: [
                    if (season.isNotEmpty)
                      Text(
                        season,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600),
                      ),
                    if (score.isNotEmpty)
                      Text(
                        '${_scorePrefix.localized()} $score'
                        '${AppStrings.t('trainerCard.scoreSuffix')}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _themeColor.accent),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List> _renderCardToBytes() async {
    final boundaryKey = GlobalKey();
    final card = RepaintBoundary(key: boundaryKey, child: _buildCardBody());

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

  /// Each pokémon tile: sprite scaled past the tile bounds via
  /// OverflowBox so the face fills the visible window instead of
  /// the sprite shrinking to fit. Shiny forwarded from the source
  /// slot.
  Widget _spriteTile(TrainerCardSlot slot) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          // Black border per user direction — the prior shade300
          // edge was too soft to register as a 'card frame'.
          border: Border.all(color: Colors.black, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: slot.pokemon == null
            ? const SizedBox.shrink()
            : OverflowBox(
                // Render the sprite at 150 logical px (well past
                // the ~118×90 tile) and let ClipRRect on the
                // parent crop whatever overflows. alignment picks
                // which window of the 150×150 sprite is shown —
                // (0, -0.35) puts the face/head region in frame
                // instead of the chest/feet.
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                alignment: const Alignment(0, -0.35),
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: PokemonSprite(
                    pokemonName: slot.pokemon!.name,
                    size: 150,
                    shiny: slot.shiny,
                  ),
                ),
              ),
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
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 400,
        // Tap-on-empty-space → unfocus. translucent so the GD
        // doesn't eat hits that should reach buttons/fields
        // underneath; onTap only fires for taps that bubble all
        // the way back here without a child handling them.
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _dismissKb,
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Live preview at the top — tapping the avatar
              // region opens the picker, all other changes flow
              // from the form fields below via controller listeners.
              GestureDetector(
                onTap: _busy
                    ? null
                    : () {
                        _dismissKb();
                        _openAvatarPicker();
                      },
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  child: _buildCardBody(),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.t('trainerCard.tapAvatarHint'),
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
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
              Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: DropdownButtonFormField<TrainerCardScorePrefix>(
                      value: _scorePrefix,
                      isDense: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final p in TrainerCardScorePrefix.values)
                          DropdownMenuItem(
                            value: p,
                            child: Text(p.localized()),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) {
                              if (v == null) return;
                              _dismissKb();
                              setState(() => _scorePrefix = v);
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
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
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Theme color picker — circular swatches in a Wrap,
              // one per Pokémon type. The currently selected
              // type's localized name shows in the header so the
              // user sees they're picking 'fire / 불꽃' vs just
              // 'orange'. Tooltip on each swatch surfaces the
              // name on long-press / hover for the rest.
              Align(
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade700),
                    children: [
                      TextSpan(
                          text: '${AppStrings.t('trainerCard.themeColor')}: '),
                      TextSpan(
                        text: _themeColor.localizedName(),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _themeColor.accent),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in TrainerCardTheme.all)
                    Tooltip(
                      message: t.localizedName(),
                      child: InkWell(
                        onTap: _busy
                            ? null
                            : () {
                                _dismissKb();
                                setState(() => _themeColor = t);
                              },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: t.accent,
                            shape: BoxShape.circle,
                            border: _themeColor.prefsValue == t.prefsValue
                                ? Border.all(color: Colors.black, width: 3)
                                : Border.all(
                                    color: Colors.grey.shade300, width: 1),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(AppStrings.t('action.cancel')),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _saveDirect,
          child: _busy
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
