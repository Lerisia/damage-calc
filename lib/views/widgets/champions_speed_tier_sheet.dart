import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../../data/champions_usage.dart';
import '../../data/pokedex.dart';
import '../../models/pokemon.dart';
import '../../utils/app_strings.dart';
import '../../utils/speed_tier_display_controller.dart';
import '../../utils/speed_tier_variants.dart';
import '../../utils/sprite_service.dart';
import 'pokemon_sprite.dart';
import 'segmented_toggle.dart';

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
    return ValueListenableBuilder<SpeedTierDisplayMode>(
      valueListenable: SpeedTierDisplayController.instance.mode,
      builder: (context, mode, _) => _buildSheet(context, mode),
    );
  }

  Widget _buildSheet(BuildContext context, SpeedTierDisplayMode mode) {
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedToggle(
            labels: [
              AppStrings.t('speedTier.display.base'),
              AppStrings.t('speedTier.display.realized'),
            ],
            selectedIndex: mode == SpeedTierDisplayMode.realized ? 1 : 0,
            onSelect: (i) => SpeedTierDisplayController.instance.set(
              i == 1
                  ? SpeedTierDisplayMode.realized
                  : SpeedTierDisplayMode.base,
            ),
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: FutureBuilder<List<_SpeedRow>>(
            future: _buildRows(mode),
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

  /// One row per distinct speed value, descending.
  ///
  /// Base mode lists species base Speed — the number players quote at
  /// each other. Realized mode lists Lv50 values, so a Pokémon shows
  /// up under each spread it plausibly runs (무보정 / 준보정 / 극보정,
  /// plus Choice Scarf lines when it actually holds one). That is
  /// roughly three times as many rows, which is why base stays the
  /// default.
  static Future<List<_SpeedRow>> _buildRows(SpeedTierDisplayMode mode) async {
    final pokedex = await loadPokedex();
    await loadChampionsUsage(); // prime cache for isInChampions
    final bySpeed = <int, List<_PokeOnTier>>{};

    void add(int speed, Pokemon p, [SpeedVariantKind? kind]) {
      bySpeed.putIfAbsent(speed, () => []).add(_PokeOnTier(
            name: p.name,
            localizedName: p.localizedName,
            dexNumber: p.dexNumber,
            kind: kind,
          ));
    }

    for (final p in pokedex) {
      if (!isInChampions(p.name)) continue;
      if (mode == SpeedTierDisplayMode.base) {
        add(p.baseStats.speed, p);
      } else {
        for (final v in speedVariantsFor(p)) {
          add(v.speed, p, v.kind);
        }
      }
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
  /// Which spread put this Pokémon on this speed. Null in base mode,
  /// where a species appears exactly once.
  final SpeedVariantKind? kind;
  _PokeOnTier({
    required this.name,
    required this.localizedName,
    required this.dexNumber,
    this.kind,
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
                  _PokeChip(
                      name: p.name,
                      label: p.localizedName,
                      kind: p.kind),
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
  final SpeedVariantKind? kind;
  const _PokeChip({required this.name, required this.label, this.kind});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PokemonSprite(pokemonName: name, size: 26, useBoxIcon: true),
        const SizedBox(width: 2),
        Text(label, style: const TextStyle(fontSize: 13)),
        if (kind != null) ...[
          const SizedBox(width: 3),
          _SpreadMarker(kind: kind!),
        ],
      ],
    );
  }
}

/// Which spread a chip belongs to. The two Scarf tiers carry the
/// item's own icon rather than a word, so the eye can pick the Scarf
/// lines out of a dense row at a glance; the icon sits next to the
/// spread it modifies (준 or 극).
class _SpreadMarker extends StatelessWidget {
  final SpeedVariantKind kind;
  const _SpreadMarker({required this.kind});

  static const _scarfItemId = 'choice-scarf';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spreadLabel = switch (kind) {
      SpeedVariantKind.neutral => AppStrings.t('speedTier.spread.neutral'),
      SpeedVariantKind.invested ||
      SpeedVariantKind.scarfInvested =>
        AppStrings.t('speedTier.spread.invested'),
      SpeedVariantKind.boosted ||
      SpeedVariantKind.scarfBoosted =>
        AppStrings.t('speedTier.spread.boosted'),
    };
    final text = Text(
      spreadLabel,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
    );
    if (!kind.isScarf) return text;

    // Icon comes from the sprite pack (web: jsDelivr, mobile: the
    // imported pack). It can be absent — a user who hasn't imported a
    // pack, or an older pack without items/ — so the label alone has
    // to remain readable, hence the text stays either way.
    final icon = SpriteService.instance.itemIconFor(_scarfItemId);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        text,
        const SizedBox(width: 1),
        if (icon != null)
          Image(
            image: icon,
            width: 16,
            height: 16,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
      ],
    );
  }
}
