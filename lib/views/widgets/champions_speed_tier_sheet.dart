import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../../data/champions_usage.dart';
import '../../data/pokedex.dart';
import '../../utils/app_strings.dart';
import '../../utils/champions_mode.dart';
import '../../utils/stat_calculator.dart';
import '../../models/nature_profile.dart';
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const SafeArea(
        top: false,
        child: SizedBox(
          height: 0,
          child: ChampionsSpeedTierSheet(),
        ),
      ),
      constraints: const BoxConstraints(maxWidth: 720),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              AppStrings.t('speedTier.title'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<_SpeedRow>>(
              future: _buildRows(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snap.data!;
                if (rows.isEmpty) {
                  return Center(
                    child: Text(AppStrings.t('speedTier.empty')),
                  );
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _SpeedRowTile(row: rows[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Build the rendered rows: one per unique speed value that has at
  /// least one Champions Pokémon, sorted descending. Each Pokémon's
  /// effective Lv50 speed is computed from its base + most-popular SP
  /// spread + nature (or base + neutral when no usage data exists).
  static Future<List<_SpeedRow>> _buildRows() async {
    final pokedex = await loadPokedex();
    // Prime the usage cache so the synchronous championsUsageFor /
    // isInChampions lookups below return populated data.
    await loadChampionsUsage();
    final bySpeed = <int, List<_PokeOnTier>>{};

    for (final p in pokedex) {
      // Skip non-Champions and Megas (Megas inherit base — listing
      // both would clutter the table with near-duplicates).
      if (!isInChampions(p.name)) continue;
      if (p.name.startsWith('Mega ')) continue;

      final entry = championsUsageFor(p.name);
      final ev = entry?.defaultSp == null
          ? ChampionsMode.evToSpStats(ChampionsMode.zeroSp)
          : ChampionsMode.spToEvStats(entry!.defaultSp!);
      // Take the top-rate nature from usage; fall back to neutral.
      final natureRow = entry?.natures.isNotEmpty ?? false
          ? entry!.natures.first
          : null;
      final natureProfile = natureRow == null
          ? NatureProfile.neutral
          : (NatureProfile.fromAny(natureRow.name));

      final stats = StatCalculator.calculate(
        baseStats: p.baseStats,
        iv: ChampionsMode.fixedIv,
        ev: ev,
        nature: natureProfile,
        level: ChampionsMode.level,
      );
      bySpeed
          .putIfAbsent(stats.speed, () => [])
          .add(_PokeOnTier(name: p.name, localizedName: p.localizedName));
    }

    final speeds = bySpeed.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final s in speeds)
        _SpeedRow(
          speed: s,
          pokemon: bySpeed[s]!
            ..sort((a, b) => a.localizedName.compareTo(b.localizedName)),
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
  _PokeOnTier({required this.name, required this.localizedName});
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
