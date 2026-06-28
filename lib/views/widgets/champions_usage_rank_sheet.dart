import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../data/champions_usage.dart';
import '../../data/pokedex.dart';
import '../../models/pokemon.dart';
import '../../utils/app_strings.dart';
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
class ChampionsUsageRankSheet extends StatelessWidget {
  /// Cross-tab dispatcher captured at [show] time. The dialog is
  /// mounted via `showDialog` on the ROOT navigator, which sits ABOVE
  /// the per-tab Navigator that RootShell installs — so looking the
  /// shell up from inside the dialog's BuildContext returns null.
  /// Resolving it here on the trigger's context (which IS under
  /// RootShell) and threading it down is the standard fix.
  final RootShellState? shell;

  const ChampionsUsageRankSheet({super.key, this.shell});

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
  Widget build(BuildContext context) {
    return Column(
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
                  // Update date pulled live from champions_usage.json's
                  // `_meta.updatedAt`. Stays empty if the field's
                  // missing rather than rendering "Updated: null".
                  FutureBuilder<String?>(
                    future: _loadUpdatedAt(),
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
            future: _buildRows(),
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
                itemBuilder: (_, i) =>
                    _RankRowTile(row: rows[i], shell: shell),
              );
            },
          ),
        ),
      ],
    );
  }

  /// One-shot read of `_meta.updatedAt` straight from
  /// `champions_usage.json`. The raw map is cached on first call so
  /// reopening the sheet doesn't re-parse the file. Cheap (~50 KB
  /// JSON) and Flutter's rootBundle caches the underlying asset too.
  static Map<String, dynamic>? _rawCache;
  static Future<String?> _loadUpdatedAt() async {
    try {
      final raw = _rawCache ??=
          jsonDecode(await rootBundle.loadString(
              'assets/champions_usage.json')) as Map<String, dynamic>;
      final meta = raw['_meta'];
      if (meta is Map && meta['updatedAt'] is String) {
        return meta['updatedAt'] as String;
      }
    } catch (_) { /* swallow — banner just won't render */ }
    return null;
  }

  /// Build the rendered rows — every Pokémon with a non-null
  /// `usageRank` from `champions_usage.json`, sorted ascending (1 =
  /// most-used at the top). Skips entries the global pokedex doesn't
  /// know about (typo'd key, unreleased form).
  static Future<List<_RankRow>> _buildRows() async {
    final pokedex = await loadPokedex();
    final usage = await loadChampionsUsage();
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
  const _RankRowTile({required this.row, this.shell});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: shell == null ? null : () {
        // Close the sheet first so the user lands on a clean dex stack,
        // then dispatch the cross-tab dex jump on the captured shell
        // (NOT a fresh lookup — context after pop is stale).
        Navigator.of(context).pop();
        shell!.requestDexDetail(row.name);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                pokemonName: row.name, size: 32, useBoxIcon: true),
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
