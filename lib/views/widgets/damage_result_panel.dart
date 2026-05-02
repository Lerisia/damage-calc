import 'package:flutter/material.dart';

import '../../models/battle_pokemon.dart';
import '../../models/dynamax.dart';
import '../../models/move.dart';
import '../../models/type.dart';
import '../../utils/app_strings.dart';
import '../../utils/damage_calculator.dart';
import '../../utils/localization.dart';

/// Pixel-for-pixel reuse of the main Damage tab's per-move result card
/// — including the type-tinted background, effectiveness label, KO
/// prediction, and modifier notes. Simple Mode renders a single card
/// via this widget so the two UIs look identical.
///
/// The ability/item name maps are passed in (rather than loaded here)
/// so the parent can share one copy across many panels and control the
/// load lifecycle.
class DamageResultPanel extends StatelessWidget {
  final BattlePokemonState attacker;
  final BattlePokemonState defender;
  final DamageResult result;
  final int? offensivePower;
  final int physBulk;
  final int specBulk;
  final int defCurrentHp;
  final int defMaxHp;
  final Map<String, String> abilityNameMap;
  final Map<String, String> itemNameMap;

  /// When true, renders the names / types / HP / bulk header above the
  /// move card. Simple Mode passes false because that info is already
  /// visible in the attacker/defender panels.
  final bool showHeader;

  const DamageResultPanel({
    super.key,
    required this.attacker,
    required this.defender,
    required this.result,
    required this.offensivePower,
    required this.physBulk,
    required this.specBulk,
    required this.defCurrentHp,
    required this.defMaxHp,
    required this.abilityNameMap,
    required this.itemNameMap,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showHeader) return _moveCard(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${attacker.localizedPokemonName}${_dynamaxLabel(attacker)} → '
            '${defender.localizedPokemonName}${_dynamaxLabel(defender)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _dmgTypeText(attacker),
            const Text('  →  ', style: TextStyle(fontSize: 12, color: Colors.grey)),
            _dmgTypeText(defender),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'HP $defCurrentHp/$defMaxHp | ${AppStrings.t('section.physBulk')} $physBulk | ${AppStrings.t('section.specBulk')} $specBulk',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        _moveCard(context),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Move card (tint by type, effectiveness label, KO, modifier notes)
  // ────────────────────────────────────────────────────────────────────────

  Widget _moveCard(BuildContext context) {
    // Status moves don't have meaningful damage output; collapse the
    // card so we don't render a "0~0%" block that looks like a bug.
    // (Simple Mode never picks status moves anyway, but Extended Mode
    // may pass a status-move slot through here in the future.)
    if (result.move.category == MoveCategory.status) {
      return const SizedBox.shrink();
    }
    final effectiveType = result.move.type == PokemonType.typeless
        ? null : result.move.type;
    final offLabel = result.isPhysical ? AppStrings.t('damage.physical') : AppStrings.t('damage.special');
    final defLabel = result.targetPhysDef ? AppStrings.t('damage.physical') : AppStrings.t('damage.special');
    final defBulk = result.targetPhysDef ? physBulk : specBulk;

    final eff = result.effectiveness;
    final String effLabel;
    final Color effColor;
    if (eff == 0) {
      effLabel = '${AppStrings.t('eff.immune')} (x0)';
      effColor = Colors.grey;
    } else if (eff >= 4) {
      effLabel = '${AppStrings.t('eff.superEffective4x')} (x${_fmtEff(eff)})';
      effColor = Colors.red[700]!;
    } else if (eff >= 2) {
      effLabel = '${AppStrings.t('eff.superEffective')} (x${_fmtEff(eff)})';
      effColor = Colors.red;
    } else if (eff <= 0.25) {
      effLabel = '${AppStrings.t('eff.notVeryEffective025')} (x${_fmtEff(eff)})';
      effColor = Colors.blue[700]!;
    } else if (eff <= 0.5) {
      effLabel = '${AppStrings.t('eff.notVeryEffective')} (x${_fmtEff(eff)})';
      effColor = Colors.blue;
    } else {
      effLabel = '${AppStrings.t('eff.neutral')} (x${_fmtEff(eff)})';
      effColor = Colors.grey;
    }

    String koText = '';
    Color koColor = Colors.grey;
    if (!result.isEmpty && eff > 0) {
      final info = result.koInfo;
      if (info.hits > 0) {
        if (info.koCount >= info.totalCount) {
          koText = '${AppStrings.t('ko.guaranteed')} ${info.hits}${AppStrings.t('ko.hit')}';
          koColor = info.hits <= 2 ? Colors.red : Colors.orange;
        } else {
          final pct = (info.koCount / info.totalCount * 100);
          koText = '${AppStrings.t('ko.random')} ${info.hits}${AppStrings.t('ko.hit')} (${pct.toStringAsFixed(1)}%)';
          koColor = Colors.orange;
        }
      }
    }

    final typeColor = effectiveType != null
        ? KoStrings.getTypeColor(effectiveType) : Colors.grey;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = Theme.of(context).scaffoldBackgroundColor;
    final cardBg = Color.lerp(baseBg, typeColor, isDark ? 0.18 : 0.09);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(result.move.localizedName, style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold,
                )),
              ),
              const SizedBox(width: 8),
              Text(effectiveType != null ? KoStrings.getTypeName(effectiveType) : '-',
                  style: TextStyle(fontSize: 14, color: typeColor, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(effLabel,
                    style: TextStyle(fontSize: 14, color: effColor, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$offLabel ${AppStrings.t('move.offensive')} ${offensivePower ?? '-'} → $defLabel ${AppStrings.t('section.bulk')} $defBulk',
            style: TextStyle(fontSize: 15, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(
                  '${result.minPercent.toStringAsFixed(1)}~${result.maxPercent.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${result.minDamage}~${result.maxDamage})',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                if (koText.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Text(koText, style: TextStyle(
                    fontSize: 16, color: koColor, fontWeight: FontWeight.bold,
                  )),
                ],
              ],
            ),
          ),
          // 16-roll distribution (collapsed when every multi-hit row
          // matches; per-hit rows when escalating power or Parental
          // Bond differentiates them).
          ..._buildDamageRolls(result),
          if (result.modifierNotes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: result.modifierNotes.map((note) => Text(
                _formatNote(note),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildDamageRolls(DamageResult result) {
    final perHit = result.perHitAllRolls;
    final List<List<int>> rows;
    if (perHit == null || perHit.isEmpty) {
      if (result.allRolls.isEmpty) return const [];
      rows = [result.allRolls];
    } else {
      final unique = perHit.map((r) => r.join(',')).toSet();
      rows = unique.length == 1 ? [perHit[0]] : perHit;
    }
    final showHitLabels = rows.length > 1;
    return [
      const SizedBox(height: 6),
      for (int i = 0; i < rows.length; i++)
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            showHitLabels
                ? '${i + 1}: ${rows[i].join(', ')}'
                : rows[i].join(', '),
            style: TextStyle(fontSize: 11, color: Colors.grey[600],
                fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
    ];
  }

  // ────────────────────────────────────────────────────────────────────────
  // Helpers (mirrors damage_calculator_screen's private versions)
  // ────────────────────────────────────────────────────────────────────────

  Widget _dmgTypeText(BattlePokemonState state) {
    if (state.terastal.active && state.terastal.teraType != null &&
        state.terastal.teraType != PokemonType.stellar) {
      final t = state.terastal.teraType!;
      return Text.rich(TextSpan(children: [
        TextSpan(text: KoStrings.getTypeName(t),
          style: TextStyle(fontSize: 13, color: KoStrings.getTypeColor(t), fontWeight: FontWeight.bold)),
        TextSpan(text: ' (${AppStrings.t('label.terastalShort')})', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ]));
    }
    final parts = <InlineSpan>[
      TextSpan(text: KoStrings.getTypeName(state.type1),
        style: TextStyle(fontSize: 13, color: KoStrings.getTypeColor(state.type1), fontWeight: FontWeight.bold)),
    ];
    if (state.type2 != null) {
      parts.add(TextSpan(text: '/', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)));
      parts.add(TextSpan(text: KoStrings.getTypeName(state.type2!),
        style: TextStyle(fontSize: 13, color: KoStrings.getTypeColor(state.type2!), fontWeight: FontWeight.bold)));
    }
    return Text.rich(TextSpan(children: parts));
  }

  String _dynamaxLabel(BattlePokemonState state) {
    switch (state.dynamax) {
      case DynamaxState.dynamax:
        return ' (${AppStrings.t("label.dynamax")})';
      case DynamaxState.gigantamax:
        return ' (${AppStrings.t("label.gigantamax")})';
      default:
        return '';
    }
  }

  String _fmtEff(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  String _formatNote(String note) {
    final parts = note.split(':');
    if (parts.length < 2) return note;

    switch (parts[0]) {
      case 'gravity':
        if (parts.length >= 2 && parts[1] == 'disabled') {
          return AppStrings.t('note.gravityDisabled');
        }
        return note;
      case 'ability':
        final name = abilityNameMap[parts[1]] ?? parts[1];
        if (parts.length >= 3) {
          if (parts[2] == 'immune') return '$name ${AppStrings.t('note.abilityImmune')}';
          final detail = parts[2];
          if (detail.startsWith('-')) return '$name$detail';
          return '$name $detail';
        }
        return name;
      case 'disguise':
        final name = abilityNameMap[parts[1]] ?? parts[1];
        return '$name: ${AppStrings.t('note.disguiseDamage')}';
      case 'berryDefBoost':
        final itemName = itemNameMap[parts[1]] ?? parts[1];
        final key = parts[1] == 'kee-berry' ? 'note.keeBerryBoost' : 'note.marangaBerryBoost';
        return '$itemName: ${AppStrings.t(key)}';
      case 'abilityDefChange':
        final abilityName = abilityNameMap[parts[1]] ?? parts[1];
        final change = parts.length >= 3 ? parts[2] : '+1';
        final noteKey = switch (change) {
          '+2' => 'note.defUp2',
          '-1' => 'note.defDown1',
          _ => 'note.defUp1',
        };
        return '$abilityName: ${AppStrings.t(noteKey)}';
      case 'item':
        final name = itemNameMap[parts[1]] ?? parts[1];
        if (parts.length >= 3) return '$name ${parts[2]}';
        return name;
      case 'screen':
        const screenKeys = {
          'reflect': 'note.reflect',
          'light_screen': 'note.lightScreen',
          'bypass_crit': 'note.critBypass',
          'bypass_infiltrator': 'note.infiltrator',
        };
        final key = screenKeys[parts[1]];
        return key != null ? AppStrings.t(key) : note;
      case 'move':
        const moveKeys = {
          'knock_off': 'note.knockOff',
          'hex': 'note.hex',
          'venoshock': 'note.venoshock',
          'brine': 'note.brine',
          'collision': 'note.collision',
          'solar_halve': 'note.solarHalve',
          'grav_apple': 'note.gravity',
          'wake_up_slap': 'note.sleep',
          'smelling_salts': 'note.paralysis',
          'barb_barrage': 'note.venoshock',
          'bolt_beak': 'note.boltBeak',
          'payback': 'note.payback',
          'spread': 'note.spread',
          'helpingHand': 'note.helpingHand',
          'powerSpot': 'note.powerSpot',
          'battery': 'note.battery',
          'flowerGift': 'note.flowerGift',
          'plusMinus': 'note.plusMinus',
          'friendGuard': 'note.friendGuard',
        };
        final key = parts[1];
        final noteKey = moveKeys[key];
        final label = noteKey != null ? AppStrings.t(noteKey) : key;
        if (parts.length >= 3) return '$label ${parts[2]}';
        return label;
      case 'weather_negate':
        final name = abilityNameMap[parts[1]] ?? parts[1];
        return '$name: ${AppStrings.t('note.weatherNegate')}';
      case 'terrain_negate':
        final name = abilityNameMap[parts[1]] ?? parts[1];
        return '$name: ${AppStrings.t('note.terrainNegate')}';
      case 'moldbreaker':
        return abilityNameMap[parts[1]] ?? parts[1];
      case 'unaware':
        return abilityNameMap['Unaware'] ?? 'Unaware';
      case 'weather':
        const weatherKeys = {
          'strong_winds': 'note.strongWinds',
          'harsh_sun_water': 'note.harshSunWater',
          'heavy_rain_fire': 'note.heavyRainFire',
        };
        final wKey = weatherKeys[parts[1]];
        return wKey != null ? AppStrings.t(wKey) : note;
      case 'ground':
        return AppStrings.t('note.groundImmune');
      case 'type':
        return AppStrings.t('note.typeImmune');
      default:
        return note;
    }
  }
}
