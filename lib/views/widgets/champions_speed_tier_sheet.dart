import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../../data/champions_usage.dart';
import '../../data/pokedex.dart';
import '../../utils/app_strings.dart';
import 'pokemon_sprite.dart';

/// Quick-reference Champions speed tier table — left column is the
/// realized Lv50 speed, right column lists every Champions Pokémon
/// that lands on that exact speed (sprite + name).
///
/// Pokémon with usage data use their most-popular SP spread + nature
/// (mirrors the team-builder default), so the speed shown matches
/// what the user actually sees on their own builds. Pokémon without
/// usage data fall back to base-speed-only (0 EV, neutral nature).
class ChampionsSpeedTierSheet extends StatelessWidget {
  const ChampionsSpeedTierSheet({super.key});

  static void show(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 720,
              maxHeight: size.height * 0.85,
            ),
            child: const ChampionsSpeedTierSheet(),
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
              child: Text(
                AppStrings.t('speedTier.title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
          child: FutureBuilder<List<_SpeedRow>>(
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
                    child: Text(AppStrings.t('speedTier.empty')),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _SpeedRowTile(row: rows[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Build the rendered rows: one per unique BASE speed value that
  /// has at least one Champions Pokémon, sorted descending. Speed
  /// shown is the species base stat (종족값), not a Lv50 realized
  /// value — players compare in base terms, and a realized number
  /// confusingly mixes in the popular spread / nature.
  static Future<List<_SpeedRow>> _buildRows() async {
    final pokedex = await loadPokedex();
    await loadChampionsUsage(); // prime cache for isInChampions
    final bySpeed = <int, List<_PokeOnTier>>{};

    for (final p in pokedex) {
      if (!isInChampions(p.name)) continue;
      final baseSpeed = p.baseStats.speed;
      bySpeed.putIfAbsent(baseSpeed, () => []).add(_PokeOnTier(
            name: p.name,
            localizedName: p.localizedName,
            dexNumber: p.dexNumber,
          ));
    }

    final speeds = bySpeed.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final s in speeds)
        _SpeedRow(
          speed: s,
          // Within each tier, dex-number order is what users expect
          // (mirrors any other species list in the app). Localized
          // alphabetic order shuffles families apart.
          pokemon: bySpeed[s]!..sort((a, b) => a.dexNumber.compareTo(b.dexNumber)),
        ),
    ];
  }
}

class _SpeedRow {
  final int speed;
  final List<_PokeOnTier> pokemon;
  _SpeedRow({required this.speed, required this.pokemon});
}

class _PokeOnTier {
  final String name;            // English internal name
  final String localizedName;   // User-facing
  final int dexNumber;          // For intra-tier sort
  _PokeOnTier({
    required this.name,
    required this.localizedName,
    required this.dexNumber,
  });
}

class _SpeedRowTile extends StatelessWidget {
  final _SpeedRow row;
  const _SpeedRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '${row.speed}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final p in row.pokemon)
                  _PokeChip(name: p.name, label: p.localizedName),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PokeChip extends StatelessWidget {
  final String name;
  final String label;
  const _PokeChip({required this.name, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PokemonSprite(pokemonName: name, size: 26, useBoxIcon: true),
        const SizedBox(width: 2),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
