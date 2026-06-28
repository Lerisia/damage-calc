import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/champions_usage.dart';
import '../../data/pokedex.dart';
import '../../models/pokemon.dart';
import '../../utils/app_strings.dart';
import '../../utils/champions_format_controller.dart';
import '../root_shell.dart';
import 'pokemon_sprite.dart';

/// Champions usage-ranking quick-reference sheet — ordered list of
/// Pokémon by `usageRank` (1 = most-used). Same popup ergonomics as
/// [ChampionsSpeedTierSheet]: a centred dialog with a header (title
/// + 갱신 날짜), a scrollable body, and a dismiss-X in the corner.
///
/// Tap a row → pops the sheet and dispatches a dex cross-link via
/// [RootShellState.requestDexDetail] so the user lands on that
/// species' dex page with all browse-state preserved.
class ChampionsUsageRankSheet extends StatefulWidget {
  /// Cross-tab dispatcher captured at [show] time. The dialog is
  /// mounted via `showDialog` on the ROOT navigator, which sits ABOVE
  /// the per-tab Navigator that RootShell installs — so looking the
  /// shell up from inside the dialog's BuildContext returns null.
  /// Resolving it here on the trigger's context (which IS under
  /// RootShell) and threading it down is the standard fix.
  final RootShellState? shell;

  const ChampionsUsageRankSheet({super.key, this.shell});

  /// Sprite-size preference. Default `true` (BW battle sprite) per
  /// user preference; persisted across sessions via
  /// SharedPreferences. The static field is the in-memory cache —
  /// reads sync, writes flush to disk on every toggle. Preload at
  /// app startup with [load] so the first sheet open has the saved
  /// value already in hand and doesn't flash on hydrate.
  static bool _bigSprites = true;
  static const String _bigSpritesKey = 'usageRankBigSprites';

  /// Reads the persisted [_bigSprites] preference into memory. Call
  /// from `main.dart`'s preload chain alongside the other
  /// controllers' `.load()` calls.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _bigSprites = prefs.getBool(_bigSpritesKey) ?? true;
    } catch (_) {
      // Pref-store unavailable (private mode? denied storage?) →
      // stay on default. The toggle still works in-memory for the
      // rest of the session.
    }
  }

  static Future<void> _saveBigSprites(bool v) async {
    _bigSprites = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_bigSpritesKey, v);
    } catch (_) { /* swallow — in-memory toggle still works */ }
  }

  static void show(BuildContext context) {
    final shell = RootShell.maybeOf(context);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 480,
              maxHeight: size.height * 0.85,
            ),
            child: ChampionsUsageRankSheet(shell: shell),
          ),
        );
      },
    );
  }

  @override
  State<ChampionsUsageRankSheet> createState() =>
      _ChampionsUsageRankSheetState();

  /// Per-format `_meta.updatedAt` cache so reopening the sheet
  /// doesn't re-parse the JSON. Cheap files (~50 KB) and Flutter's
  /// rootBundle caches the asset too, but parsing is the avoidable
  /// cost here.
  static final Map<ChampionsFormat, Map<String, dynamic>?> _rawCache = {};
  static Future<String?> _loadUpdatedAt(ChampionsFormat format) async {
    try {
      final asset = format == ChampionsFormat.doubles
          ? 'assets/champions_usage_doubles.json'
          : 'assets/champions_usage.json';
      final raw = _rawCache[format] ??=
          jsonDecode(await rootBundle.loadString(asset)) as Map<String, dynamic>;
      final meta = raw!['_meta'];
      if (meta is Map && meta['updatedAt'] is String) {
        return meta['updatedAt'] as String;
      }
    } catch (_) { /* swallow — banner just won't render */ }
    return null;
  }

  /// Build the rendered rows for [format] — every Pokémon with a
  /// non-null `usageRank` in that format's usage JSON, sorted
  /// ascending (1 = most-used at the top). Skips entries the global
  /// pokedex doesn't know about (typo'd key, unreleased form).
  static Future<List<_RankRow>> _buildRows(ChampionsFormat format) async {
    final pokedex = await loadPokedex();
    final usage = await loadChampionsUsage(format: format);
    final byName = <String, Pokemon>{
      for (final p in pokedex) p.name: p,
    };
    final rows = <_RankRow>[];
    for (final entry in usage.entries) {
      final rank = entry.value.usageRank;
      if (rank == null) continue;
      final poke = byName[entry.key];
      if (poke == null) continue;
      rows.add(_RankRow(
        rank: rank,
        name: poke.name,
        localizedName: poke.localizedName,
      ));
    }
    rows.sort((a, b) => a.rank.compareTo(b.rank));
    return rows;
  }
}

class _ChampionsUsageRankSheetState extends State<ChampionsUsageRankSheet> {
  late bool _big = ChampionsUsageRankSheet._bigSprites;

  ChampionsFormatController get _ctrl => ChampionsFormatController.instance;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChampionsFormat>(
      valueListenable: _ctrl.format,
      builder: (context, format, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.t('usageRank.title'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    // Update date for the *currently displayed* format
                    // (not a fixed file) — flipping singles ↔ doubles
                    // re-runs the lookup so the header date stays in
                    // sync with the rows below.
                    FutureBuilder<String?>(
                      future: ChampionsUsageRankSheet._loadUpdatedAt(format),
                      builder: (context, snap) {
                        final date = snap.data;
                        if (date == null || date.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          AppStrings.t('usageRank.updatedAt')
                              .replaceFirst('{date}', date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Sprite-size toggle — between the date and the close X
              // so it reads as a view-mode control, not a destructive
              // action. The label sits to the left of the checkbox so
              // the tap target reaches both.
              InkWell(
                onTap: () {
                  setState(() {
                    _big = !_big;
                    ChampionsUsageRankSheet._saveBigSprites(_big);
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      AppStrings.t('usageRank.bigSprites'),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 2),
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _big,
                        onChanged: (v) {
                          setState(() {
                            _big = v ?? false;
                            ChampionsUsageRankSheet._saveBigSprites(_big);
                          });
                        },
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 6),
              // Singles / doubles segmented control — bound to the
              // global [ChampionsFormatController] so flipping it
              // here ALSO updates the dex defaults, team-builder
              // curated lists, etc. Opens at whatever the user's
              // global format is so the first-shown list matches
              // their current setting.
              _FormatSegmented(
                format: format,
                onChanged: (v) => _ctrl.set(v),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ),
          const Divider(height: 1),
          Flexible(
            child: FutureBuilder<List<_RankRow>>(
              // Key the future on `format` so swapping mode re-runs
              // the build instead of showing the cached singles list
              // forever after a doubles flip.
              key: ValueKey(format),
              future: ChampionsUsageRankSheet._buildRows(format),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final rows = snap.data!;
                if (rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(AppStrings.t('usageRank.empty')),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _RankRowTile(
                    row: rows[i],
                    shell: widget.shell,
                    big: _big,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact singles/doubles segmented control. Kept as its own widget
/// so the same shape can be dropped into the settings menu without
/// duplicating the styling.
class _FormatSegmented extends StatelessWidget {
  final ChampionsFormat format;
  final ValueChanged<ChampionsFormat> onChanged;
  const _FormatSegmented({required this.format, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ChampionsFormat>(
      segments: [
        ButtonSegment(
          value: ChampionsFormat.singles,
          label: Text(
            AppStrings.t('championsFormat.singles'),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        ButtonSegment(
          value: ChampionsFormat.doubles,
          label: Text(
            AppStrings.t('championsFormat.doubles'),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
      selected: {format},
      onSelectionChanged: (s) => onChanged(s.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
    );
  }
}

class _RankRow {
  final int rank;
  final String name;            // English internal name
  final String localizedName;   // User-facing
  _RankRow({
    required this.rank,
    required this.name,
    required this.localizedName,
  });
}

class _RankRowTile extends StatelessWidget {
  final _RankRow row;
  /// Pre-captured shell ref (the dialog can't look it up itself —
  /// see [ChampionsUsageRankSheet.shell] for the why).
  final RootShellState? shell;
  /// `true` → render the dex-style BW battle sprite (no box icon),
  /// roughly 2× the compact box-icon row. Toggled via the header
  /// checkbox; same source the dex header uses so the two views
  /// read as the same image.
  final bool big;
  const _RankRowTile({required this.row, this.shell, this.big = false});

  @override
  Widget build(BuildContext context) {
    final spriteSize = big ? 64.0 : 32.0;
    return InkWell(
      onTap: shell == null ? null : () {
        // Close the sheet first so the user lands on a clean dex stack,
        // then dispatch the cross-tab dex jump on the captured shell
        // (NOT a fresh lookup — context after pop is stale).
        Navigator.of(context).pop();
        shell!.requestDexDetail(row.name);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          // Tighter vertical padding in box-icon mode keeps the row
          // dense; the BW sprite is twice as tall so it needs less
          // padding to feel balanced.
          vertical: big ? 4 : 8,
        ),
        child: Row(
          children: [
            // Fixed-width rank column so sprites line up across single,
            // double, and triple-digit ranks.
            SizedBox(
              width: 32,
              child: Text(
                '${row.rank}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PokemonSprite(
              pokemonName: row.name,
              size: spriteSize,
              useBoxIcon: !big,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                row.localizedName,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
