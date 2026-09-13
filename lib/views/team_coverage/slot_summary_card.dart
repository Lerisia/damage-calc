part of '../team_coverage_screen.dart';

/// Read-only summary of a party slot — sprite + name + type chips +
/// ability/item labels + 4 move pills. Tapping the card opens the
/// modal editor that owns the actual form widgets ([_SlotCard]).
/// Empty slots render a dashed-frame "탭하여 추가" prompt instead.
class _SlotSummaryCard extends StatelessWidget {
  /// Fixed inner-content height shared by both empty and filled
  /// cards so the 6-row column doesn't jitter as the user populates
  /// slots. Sized for a 64-px sprite + 4 stacked text rows (name,
  /// ability/item, moves, EV line).
  static const _contentHeight = 86.0;

  final int index;
  final _TeamSlot slot;
  final Map<String, String> abilityNames;
  final Map<String, String> itemNames;
  final VoidCallback onTap;

  const _SlotSummaryCard({
    super.key,
    required this.index,
    required this.slot,
    required this.abilityNames,
    required this.itemNames,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = slot.pokemon;
    final empty = p == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: scheme.outlineVariant,
            style: empty ? BorderStyle.solid : BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(8),
          color: empty ? null : scheme.surface,
        ),
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        child: empty ? _emptyContent(scheme) : _filledContent(context, p, scheme),
      ),
    );
  }

  Widget _emptyContent(ColorScheme scheme) {
    return SizedBox(
      height: _contentHeight,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(Icons.catching_pokemon,
                size: 44, color: scheme.outlineVariant),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppStrings.t('team.slot.tapToAdd'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filledContent(BuildContext context, Pokemon p, ColorScheme scheme) {
    final abilityKey = slot.ability;
    final abilityLabel = abilityKey == null
        ? null
        : (abilityNames[abilityKey] ?? abilityKey);
    final itemKey = slot.heldItem;
    final itemLabel = itemKey == null ? null : (itemNames[itemKey] ?? itemKey);

    return SizedBox(
      height: _contentHeight,
      child: Row(
      // Content column stays top-aligned (name reads at the top of
      // the card). Sprite gets its own Center wrapper below so it
      // sits in the middle of the card vertically — vs floating at
      // the top with empty space below when content is taller.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: PokemonSprite(
              pokemonName: p.name, size: 64, shiny: slot.shiny),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      p.localizedName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (slot.effectiveType1 != null) ...[
                    const SizedBox(width: 4),
                    TypeChip(slot.effectiveType1!, dense: true),
                  ],
                  if (slot.effectiveType2 != null) ...[
                    const SizedBox(width: 2),
                    TypeChip(slot.effectiveType2!, dense: true),
                  ],
                  if (slot.effectiveType3 != null) ...[
                    const SizedBox(width: 2),
                    TypeChip(slot.effectiveType3!, dense: true),
                  ],
                ],
              ),
              // Ability + Item on a single inline line — item flows
              // immediately after the ability so a short ability name
              // pulls the item label leftward instead of locking each
              // field to a fixed column.
              _abilityItemLine(scheme, abilityLabel, itemLabel),
              const SizedBox(height: 4),
              // Stat row: HP-Atk-Def-SpA-SpD-Spe shown as real
              // (Lv50, IV 31) numbers with the SP investment and
              // nature glyph carried in parens. Parens drop entirely
              // when the stat is uninvested + nature-neutral so a
              // plain spread reads with minimum noise. Same Pokémon
              // order as the popup editor.
              _statRealLine(scheme, p, slot.evs, slot.nature),
              const SizedBox(height: 4),
              // Move pills — forced to a single line via equal-width
              // Expanded cells. Long move names truncate with the
              // pill's ellipsis style rather than wrapping to a 2nd
              // row.
              Row(
                children: [
                  for (int i = 0; i < 4; i++) ...[
                    Expanded(child: _movePill(slot.moves[i])),
                    if (i < 3) const SizedBox(width: 3),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }

  /// "특성 ㅇㅇㅇ  아이템 ㅇㅇㅇ" inline rendering. Uses Text.rich so
  /// the item label flows immediately after the ability instead of
  /// being locked to a 50% column. Truncates with a trailing ellipsis
  /// when the combined string overflows the card width.
  Widget _abilityItemLine(
      ColorScheme scheme, String? abilityLabel, String? itemLabel) {
    final muted = TextStyle(
      fontSize: 11,
      color: scheme.onSurface.withValues(alpha: 0.5),
    );
    const value = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
    final mutedValue = value.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.3),
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${AppStrings.t('label.ability')} ', style: muted),
          TextSpan(
            text: (abilityLabel == null || abilityLabel.isEmpty)
                ? '—'
                : abilityLabel,
            style: (abilityLabel == null || abilityLabel.isEmpty)
                ? mutedValue
                : value,
          ),
          TextSpan(text: '   ${AppStrings.t('label.item')} ', style: muted),
          TextSpan(
            text: (itemLabel == null || itemLabel.isEmpty) ? '—' : itemLabel,
            style: (itemLabel == null || itemLabel.isEmpty)
                ? mutedValue
                : value,
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// EV row — six numbers separated by middle dots, with a small ▲
  /// (nature boost) or ▼ (nature reduction) appended right after
  /// the affected stat's value. Renders zeroes when the slot has no
  /// loaded EVs / nature so the row's footprint stays constant.
  /// Numbers shown in Champions SP units (0-32), matching the rest
  /// of the team-builder / simple-mode UI — the calc itself stays
  /// in EV units, conversion happens here at the display boundary.
  Widget _statRealLine(ColorScheme scheme, Pokemon? pokemon,
      Stats? evs, NatureProfile? nature) {
    if (pokemon == null) return const SizedBox.shrink();

    // Compute Lv50 / IV-31 real stats from this slot's EVs + nature.
    // Mirrors the calculator's StatCalculator so the numbers shown
    // here are the same numbers used in damage calcs downstream.
    final evStats = evs ?? ChampionsMode.spToEvStats(ChampionsMode.zeroSp);
    final natureProfile = nature ?? NatureProfile.neutral;
    final real = StatCalculator.calculate(
      baseStats: pokemon.baseStats,
      iv: ChampionsMode.fixedIv,
      ev: evStats,
      nature: natureProfile,
      level: ChampionsMode.level,
    );
    final sp = ChampionsMode.evToSpStats(evStats);

    const keys = ['hp', 'atk', 'def', 'spa', 'spd', 'spe'];
    int realOf(String k) => switch (k) {
          'hp' => real.hp,
          'atk' => real.attack,
          'def' => real.defense,
          'spa' => real.spAttack,
          'spd' => real.spDefense,
          'spe' => real.speed,
          _ => 0,
        };
    int spOf(String k) => switch (k) {
          'hp' => sp.hp,
          'atk' => sp.attack,
          'def' => sp.defense,
          'spa' => sp.spAttack,
          'spd' => sp.spDefense,
          'spe' => sp.speed,
          _ => 0,
        };
    NatureStat? statFor(String k) => switch (k) {
          'atk' => NatureStat.atk,
          'def' => NatureStat.def,
          'spa' => NatureStat.spa,
          'spd' => NatureStat.spd,
          'spe' => NatureStat.spe,
          _ => null, // HP never has a nature glyph.
        };

    final base = TextStyle(
      fontSize: 11,
      color: scheme.onSurface.withValues(alpha: 0.85),
    );
    final muted = TextStyle(
      fontSize: 11,
      color: scheme.onSurface.withValues(alpha: 0.55),
    );
    final upStyle = TextStyle(
      fontSize: 9,
      color: Colors.red.shade400,
      fontWeight: FontWeight.w700,
    );
    final downStyle = TextStyle(
      fontSize: 9,
      color: Colors.blue.shade400,
      fontWeight: FontWeight.w700,
    );
    final sepStyle = muted.copyWith(color: scheme.outlineVariant);

    final spans = <InlineSpan>[];
    for (int i = 0; i < keys.length; i++) {
      final k = keys[i];
      spans.add(TextSpan(text: '${realOf(k)}', style: base));

      final spVal = spOf(k);
      final ns = statFor(k);
      String? arrow;
      TextStyle? arrowStyle;
      if (ns != null) {
        if (natureProfile.up == ns) {
          arrow = '▲';
          arrowStyle = upStyle;
        } else if (natureProfile.down == ns) {
          arrow = '▼';
          arrowStyle = downStyle;
        }
      }
      // Parens drop entirely when there's nothing to annotate
      // (uninvested + nature-neutral on this stat).
      if (spVal > 0 || arrow != null) {
        spans.add(TextSpan(text: '(', style: muted));
        if (spVal > 0) {
          spans.add(TextSpan(text: '$spVal', style: muted));
        }
        if (arrow != null) {
          spans.add(TextSpan(text: arrow, style: arrowStyle));
        }
        spans.add(TextSpan(text: ')', style: muted));
      }

      if (i < keys.length - 1) {
        spans.add(TextSpan(text: ' - ', style: sepStyle));
      }
    }

    // FittedBox keeps the line single-row no matter how narrow the
    // card gets — text auto-scales down on phone widths instead of
    // ellipsizing the rightmost stats. Card height stays stable.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(children: spans),
        maxLines: 1,
        softWrap: false,
      ),
    );
  }

  Widget _movePill(Move? move) {
    if (move == null) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '—',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      );
    }
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: KoStrings.getTypeColor(move.type),
        borderRadius: BorderRadius.circular(8),
      ),
      // Long move names auto-shrink instead of ellipsizing — users
      // would rather read a 7-pt 'Last Respects' than '...'. The
      // 10-pt size below is the *max*; FittedBox scales down only
      // when the natural width exceeds the pill.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
        move.localizedName,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      ),
    );
  }
}
