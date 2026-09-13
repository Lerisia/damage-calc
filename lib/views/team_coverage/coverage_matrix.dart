part of '../team_coverage_screen.dart';

class _CoverageMatrix extends StatelessWidget {
  final List<_TeamSlot> team;
  /// Opponent slots — same data shape as [team]; rendered as
  /// additional columns on the right of the my-party block,
  /// separated by a thicker vertical divider. Summary still counts
  /// only [team] (lineup applies only to my pokemon).
  final List<_TeamSlot> opponents;
  final Map<String, String> abilityNames;
  /// `true` → render multipliers as the standard Pokemon-game symbol
  /// set (◎ / ○ / △ / ▲ / ✕). `false` → numeric ("4×", "½", …).
  /// The decisive-tier pill background is shown in both modes.
  final bool symbolic;
  /// `true` → show the offensive matrix (best damage multiplier each
  /// pokemon's moves can deal vs each defender type). `false` →
  /// defensive matrix (current default).
  final bool offensive;
  /// `true` → render header pokemon names horizontally (wide-screen
  /// layout where the column width is generous enough to fit the
  /// name on one line). Saves the ~60 px the vertical-stack layout
  /// reserves for narrow phones.
  final bool horizontalNames;
  /// Lineup mode + selected indices. When [lineupMode] is true, the
  /// summary collapses to only the selected slots and unselected
  /// columns dim out. Tapping a header name fires [onLineupToggle]
  /// to flip that slot's selection.
  final bool lineupMode;
  final Set<int> lineup;
  final ValueChanged<int> onLineupToggle;

  const _CoverageMatrix({
    required this.team,
    required this.opponents,
    required this.abilityNames,
    required this.lineupMode,
    required this.lineup,
    required this.onLineupToggle,
    this.symbolic = false,
    this.offensive = false,
    this.horizontalNames = false,
  });

  @override
  Widget build(BuildContext context) {
    // Listen on SpritePackManager so the header switches between name
    // text and box icons the moment the user imports / removes a pack
    // on mobile. Web doesn't change state but the listener is cheap.
    return ListenableBuilder(
      listenable: SpritePackManager.instance,
      builder: (ctx, _) => _buildMatrix(ctx),
    );
  }

  Widget _buildMatrix(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // ── Single up-front pass: resolve every slot's moves through
    // transformMove once. Without this cache each opp/my matchup
    // cell would re-run transformMove for every attacker move on
    // every render — opponents made it especially bad (6 my × 4
    // moves × N opps × 2 calls per opp summary). One cache, shared
    // by every helper below.
    final movesCache = <_TeamSlot, List<CoverageMove>>{};
    void cacheMoves(List<_TeamSlot> slots) {
      for (final slot in slots) {
        final p = slot.pokemon;
        if (p == null) {
          movesCache[slot] = const [];
          continue;
        }
        final t1 = slot.effectiveType1 ?? p.type1;
        movesCache[slot] = [
          for (final m in slot.moves)
            if (m != null)
              coverageMoveFromMove(
                m,
                ability: slot.ability,
                heldItem: slot.heldItem,
                userType1: t1,
                pokemonName: p.name,
              ),
        ];
      }
    }
    cacheMoves(team);
    cacheMoves(opponents);

    // Build per-slot cell rows for my party only — the opp display
    // matrix used to be computed here too but never consumed (opp
    // rows render via _opponentMatchCell, not the per-type matrix),
    // so dropping it removes another offensive-mode pass.
    final myDisplay = _buildDisplayMatrix(team, movesCache);

    // Summary counts only my slots (opponents are info-only). Lineup
    // further narrows to the picked subset; empty pick → 0/0.
    final summarySource = <List<CoverageCell>>[
      for (int i = 0; i < team.length; i++)
        if (myDisplay[i] != null &&
            (!lineupMode || lineup.contains(i))) myDisplay[i]!,
    ];
    final summary = summarize(summarySource);

    // Pre-compute opp×my matchup cells once. Reused by both the
    // opp row renderer and `_summaryForOpponentRow` so neither
    // recomputes the same coverageOf chain.
    final oppMatchCache = <_TeamSlot, Map<_TeamSlot, CoverageCell>>{};
    for (final opp in opponents) {
      if (opp.pokemon == null) continue;
      final perOpp = <_TeamSlot, CoverageCell>{};
      for (final mySlot in team) {
        if (mySlot.pokemon == null) continue;
        perOpp[mySlot] = _opponentMatchCell(opp, mySlot, movesCache);
      }
      oppMatchCache[opp] = perOpp;
    }

    // Type-label column is sized to a snug 3-char chip (Korean type
    // names cap at 3 chars: 에스퍼, 고스트, 드래곤, 페어리) — no
    // wasted whitespace around it. The remaining width is split
    // between the 6 Pokemon columns and the summary block via flex.
    return Table(
      defaultColumnWidth: const FlexColumnWidth(1.0),
      columnWidths: {
        0: const FixedColumnWidth(48),
        for (int i = 0; i < team.length; i++)
          i + 1: const FlexColumnWidth(1.0),
        team.length + 1: const FlexColumnWidth(1.8),
      },
      // Vertical separators between pokemon columns are deliberately
      // beefier than the horizontal row dividers — when scanning a
      // type row across 6 mons the eye needs the column boundaries
      // to pop. Horizontals stay thin since the zebra stripes carry
      // most of the row separation.
      border: TableBorder(
        top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: 0.6),
        bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: 0.6),
        left: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: 0.6),
        right: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: 0.6),
        horizontalInside: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: 0.6),
        verticalInside: BorderSide(
            color: scheme.outlineVariant, width: 1.2),
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _headerRow(scheme),
        // Opponent rows BEFORE the type rows. Each row's cell shows
        // the BEST multiplier between that opp and a my-pokemon
        // column — for the defensive matrix, that's the opp's best
        // attacking move vs my mon; for the offensive matrix, my
        // mon's best attacking move vs the opp.
        for (int oi = 0; oi < opponents.length; oi++)
          if (opponents[oi].pokemon != null)
            _opponentRow(
              opponents[oi],
              oppMatchCache[opponents[oi]] ?? const {},
              _summaryForOpponentRow(
                  opponents[oi],
                  oppMatchCache[opponents[oi]] ?? const {}),
              scheme,
              isLast: _isLastFilledOpp(oi),
            ),
        for (int t = 0; t < teamCoverageAttackTypes.length; t++)
          _typeRow(t, myDisplay, summary[t], scheme),
      ],
    );
  }

  /// Build a [slots.length] × 18 grid of [CoverageCell]s. Empty
  /// slots stay as `null` rows so the renderer can paint blanks.
  /// [movesCache] holds pre-resolved CoverageMoves per slot — see
  /// the cache build in the parent `build()`.
  List<List<CoverageCell>?> _buildDisplayMatrix(
      List<_TeamSlot> slots,
      Map<_TeamSlot, List<CoverageMove>> movesCache) {
    final filled = <CoverageSlot>[];
    final filledIdx = <int>[];
    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final p = slot.pokemon;
      if (p == null) continue;
      final t1 = slot.effectiveType1 ?? p.type1;
      final t2 = slot.effectiveType2;
      final t3 = slot.effectiveType3;
      filled.add(CoverageSlot(
        type1: t1,
        type2: t2,
        type3: t3,
        ability: slot.ability,
        heldItem: slot.heldItem,
        moves: offensive ? (movesCache[slot] ?? const []) : const [],
      ));
      filledIdx.add(i);
    }
    final matrix = offensive
        ? offensiveCoverageMatrix(filled)
        : defensiveCoverageMatrix(filled);
    final display = List<List<CoverageCell>?>.filled(slots.length, null);
    for (int j = 0; j < filledIdx.length; j++) {
      display[filledIdx[j]] = matrix[j];
    }
    return display;
  }

  TableRow _headerRow(ColorScheme scheme) {
    final hasIcons = kIsWeb || SpritePackManager.instance.iconsInstalled;
    final emptyHeight = hasIcons ? 44.0 : (horizontalNames ? 28.0 : 84.0);
    return TableRow(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      children: [
        const SizedBox.shrink(),
        for (int i = 0; i < team.length; i++)
          team[i].pokemon != null
              ? _wrapNameForLineup(
                  i,
                  _nameCell(
                    team[i].pokemon!.localizedName,
                    englishName: team[i].pokemon!.name,
                    type1: team[i].effectiveType1,
                    type2: team[i].effectiveType2,
                  ),
                )
              : SizedBox(height: emptyHeight),
        // Color-coded labels side-by-side, with the same thicker
        // left divider that the data rows carry below.
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: scheme.onSurface.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                AppStrings.t('team.matrix.weak'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.red.shade700,
                ),
              ),
              Text(
                AppStrings.t('team.matrix.resist'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Pokemon-name header cell. On wide layouts the column is roomy
  /// enough to render the name horizontally on a single line (saves
  /// ~60 px of header height). On narrow layouts the column is too
  /// tight; we stack each character of a Korean / Japanese name
  /// (킬 / 가 / 르 / 도) or rotate an English name 90°.
  ///
  /// A faded type-color tint sits behind the name — single type =
  /// flat, dual type split: left/right for horizontal layouts, top/
  /// bottom for vertical layouts (each matching the reading flow).
  Widget _nameCell(
    String rawName, {
    required String englishName,
    required PokemonType? type1,
    required PokemonType? type2,
  }) {
    // When an icon source is available, prefer the 40×30 box icon
    // over the localized name — it's recognized faster than a Korean
    // 3-char abbreviation and doesn't fight for column width. Web has
    // jsDelivr-fronted icons always available; mobile shows icons
    // only after the user imports a pack. spriteKeyFor only handles
    // English species names, so we route the canonical English name
    // separately from the localized display label.
    final hasIcons = kIsWeb || SpritePackManager.instance.iconsInstalled;
    if (hasIcons) {
      return _iconHeaderCell(englishName, type1: type1, type2: type2);
    }
    final lang = AppStrings.current;
    // Strip parenthesized form/variant suffixes for the matrix header
    // only — "킬가르도 (블레이드폼)" → "킬가르도", "오거폰 (우물의가면)"
    // → "오거폰". The slot card still shows the full name; it's only
    // here, where vertical space is tight and column reading speed
    // matters, that the parens get in the way.
    final parenIdx = rawName.indexOf('(');
    final name = parenIdx > 0 ? rawName.substring(0, parenIdx).trim() : rawName;
    if (horizontalNames) {
      // Try horizontal first; fall back to the vertical layout per
      // cell when the column is too narrow for the name. Mixed
      // layouts within one header row are fine — Table sizes the row
      // to its tallest cell, so as soon as one name needs the
      // vertical fallback the row goes back to 84 px. The user's
      // win is "horizontal whenever it fits", not "always
      // horizontal".
      return LayoutBuilder(builder: (context, constraints) {
        const style = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
        final tp = TextPainter(
          text: TextSpan(text: name, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        final fits = tp.width <= constraints.maxWidth - 8;
        if (fits) {
          return SizedBox(
            height: 28,
            child: DecoratedBox(
              decoration: _horizontalNameTint(type1, type2),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Center(
                  child: Text(name, maxLines: 1, style: style),
                ),
              ),
            ),
          );
        }
        return _verticalNameLayout(name, type1, type2, lang);
      });
    }
    return _verticalNameLayout(name, type1, type2, lang);
  }

  /// Vertical layout extracted so the horizontal-fits-or-fallback
  /// path can reuse it without code duplication.
  Widget _verticalNameLayout(
    String name,
    PokemonType? type1,
    PokemonType? type2,
    AppLanguage lang,
  ) {
    final Widget content;
    if (lang == AppLanguage.ko || lang == AppLanguage.ja) {
      // Drop spaces / hyphens that show up in some long names — they
      // waste a stack row and don't add information ("미라이돈"보다
      // "미라이 돈" 같은 케이스).
      final chars = name.runes
          .map((r) => String.fromCharCode(r))
          .where((c) => c.trim().isNotEmpty)
          .toList();
      // Cap at 6 stacked chars so 84 px is enough; longer names (rare
      // in the dex) trail off with an ellipsis row.
      final shown = chars.length <= 6 ? chars : [...chars.take(5), '…'];
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in shown)
              Text(
                c,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      );
    } else {
      content = Center(
        child: RotatedBox(
          quarterTurns: 3,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    return SizedBox(
      height: 84,
      child: DecoratedBox(
        decoration: _vertNameTint(type1, type2),
        child: content,
      ),
    );
  }

  /// Icon-style header cell used when an image pack is available.
  /// Renders the 40×30 box icon over the same type-tint background
  /// that the name cells use, so columns read consistently no matter
  /// which mode is active. Falls through to the pokéball placeholder
  /// for keys without an icon (handled inside [PokemonSprite]).
  Widget _iconHeaderCell(
    String rawName, {
    required PokemonType? type1,
    required PokemonType? type2,
  }) {
    return SizedBox(
      height: 44,
      child: DecoratedBox(
        decoration: _vertNameTint(type1, type2),
        child: Center(
          child: PokemonSprite(
            pokemonName: rawName,
            useBoxIcon: true,
            size: 40,
          ),
        ),
      ),
    );
  }

  /// Faded type-color background for the vertical name cell. Single
  /// type → flat 20% tint; dual type → top half [t1] / bottom half
  /// [t2] hard-stop gradient. Returns an empty decoration when no
  /// types are passed.
  static const double _vertTintAlpha = 0.20;
  BoxDecoration _vertNameTint(PokemonType? t1, PokemonType? t2) {
    if (t1 == null) return const BoxDecoration();
    final c1 = KoStrings.getTypeColor(t1).withValues(alpha: _vertTintAlpha);
    if (t2 == null) {
      return BoxDecoration(color: c1);
    }
    final c2 = KoStrings.getTypeColor(t2).withValues(alpha: _vertTintAlpha);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [c1, c1, c2, c2],
        stops: const [0.0, 0.5, 0.5, 1.0],
      ),
    );
  }

  /// Horizontal version — dual type splits left/right since the name
  /// reads left-to-right.
  BoxDecoration _horizontalNameTint(PokemonType? t1, PokemonType? t2) {
    if (t1 == null) return const BoxDecoration();
    final c1 = KoStrings.getTypeColor(t1).withValues(alpha: _vertTintAlpha);
    if (t2 == null) return BoxDecoration(color: c1);
    final c2 = KoStrings.getTypeColor(t2).withValues(alpha: _vertTintAlpha);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [c1, c1, c2, c2],
        stops: const [0.0, 0.5, 0.5, 1.0],
      ),
    );
  }

  TableRow _typeRow(
      int t,
      List<List<CoverageCell>?> myMatrix,
      CoverageColumnSummary summary,
      ColorScheme scheme) {
    final attackType = teamCoverageAttackTypes[t];
    return TableRow(
      // Zebra stripe with a 4% black overlay on top of zinc-100 so
      // it lands ~9% darker than the surface — louder than the
      // earlier ~5% so the row separation still reads through the
      // beefier vertical gridlines.
      decoration: BoxDecoration(
        color: t.isOdd
            ? Color.alphaBlend(
                scheme.onSurface.withValues(alpha: 0.04),
                scheme.surfaceContainerHighest,
              )
            : null,
      ),
      children: [
        // No horizontal padding — the type chip fills the 48 px
        // column flush, no whitespace either side. Vertical pad is
        // just enough to keep the chip from touching the row borders.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _attackTypeChip(attackType),
        ),
        for (int p = 0; p < team.length; p++)
          myMatrix[p] == null
              ? const SizedBox(height: 28)
              : _wrapCellForLineup(p, _multCell(myMatrix[p]![t], scheme)),
        _summaryCell(summary, scheme),
      ],
    );
  }

  /// Solid colored chip — same style as the team-builder slot's type
  /// chips and the attacker/defender panel badges. The chip fills the
  /// fixed-width type column edge-to-edge; the 3-char Korean name sits
  /// centered with the colored bg picking up any slack.
  /// Wrap a header name cell with InkWell so tapping toggles the
  /// slot in the lineup; outside lineup mode it's a passthrough.
  /// Selected lineup picks render at full opacity, the rest dim.
  Widget _wrapNameForLineup(int slotIdx, Widget child) {
    if (!lineupMode) return child;
    final selected = lineup.contains(slotIdx);
    final wrapped = Opacity(
      opacity: selected ? 1.0 : 0.30,
      child: child,
    );
    return InkWell(
      onTap: () => onLineupToggle(slotIdx),
      child: wrapped,
    );
  }

  /// Same dim treatment for the data cells in a column.
  /// True when no later opponent slot is filled — used to mark the
  /// last opp row so it carries the section-divider bottom border.
  bool _isLastFilledOpp(int idx) {
    for (int j = idx + 1; j < opponents.length; j++) {
      if (opponents[j].pokemon != null) return false;
    }
    return true;
  }

  /// One opponent row, shown above the type rows. Column 0 holds
  /// the opp's name (clipped to fit the 48 px label column, with a
  /// faded type-color background like the my-party header cells),
  /// each my-pokemon column holds the best matchup multiplier for
  /// that (opp, my) pair, and the summary column carries a
  /// weak/resist count across the my-party slots — same renderer
  /// the type rows use.
  TableRow _opponentRow(
      _TeamSlot opp,
      Map<_TeamSlot, CoverageCell> oppCells,
      CoverageColumnSummary summary,
      ColorScheme scheme,
      {required bool isLast}) {
    final p = opp.pokemon!;
    return TableRow(
      decoration: BoxDecoration(
        color: Colors.red.shade50.withValues(alpha: 0.4),
        // Thicker bottom border on the LAST opp row so the opp /
        // type sections separate cleanly. Border on top of the
        // first type row would do the same job; opp-side keeps the
        // logic local.
        border: isLast
            ? Border(
                bottom: BorderSide(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                  width: 1.8,
                ),
              )
            : null,
      ),
      children: [
        // Opp name with the same faded type-color tint we use for
        // my-party header names — single type flat, dual type a
        // left/right hard-stop gradient.
        DecoratedBox(
          decoration: _horizontalNameTint(
              opp.effectiveType1 ?? p.type1, opp.effectiveType2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Text(
              p.localizedName,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        // Per-my-pokemon cells with the best matchup multiplier.
        for (int mi = 0; mi < team.length; mi++)
          team[mi].pokemon == null
              ? const SizedBox(height: 28)
              : _wrapCellForLineup(
                  mi,
                  _multCell(
                    oppCells[team[mi]] ??
                        const CoverageCell(0,
                            immunityReason: 'noMoves'),
                    scheme,
                  ),
                ),
        // Summary uses the same renderer as type rows — its built-in
        // 1.5 px left border doubles as the divider between the per-
        // pokemon cells and the count column. lineup-filtered when
        // 선출 보기 is active (handled in _summaryForOpponentRow).
        _summaryCell(summary, scheme),
      ],
    );
  }

  /// Per-opp-row summary: bucket the (opp, my) cells across the my-
  /// party. Computed inline because `summarize()` from
  /// team_coverage.dart assumes an 18-column type matrix — we have
  /// one cell per my-pokemon, not 18.
  ///
  /// For the offensive matrix `weak` = my mons that hit opp super-
  /// effectively; for the defensive matrix `weak` = my mons that
  /// take super-effective damage from opp.
  CoverageColumnSummary _summaryForOpponentRow(
      _TeamSlot opp, Map<_TeamSlot, CoverageCell> oppCells) {
    int weak = 0, neutral = 0, resist = 0, immune = 0;
    for (int mi = 0; mi < team.length; mi++) {
      if (team[mi].pokemon == null) continue;
      if (lineupMode && !lineup.contains(mi)) continue;
      final c = oppCells[team[mi]] ??
          const CoverageCell(0, immunityReason: 'noMoves');
      if (c.isImmune) {
        immune++;
      } else if (c.isWeak) {
        weak++;
      } else if (c.isResist) {
        resist++;
      } else {
        neutral++;
      }
    }
    return CoverageColumnSummary(
        weak: weak, neutral: neutral, resist: resist, immune: immune);
  }

  /// Compute the best-effectiveness CoverageCell for the (opp, my)
  /// pair — direction depends on [offensive]:
  ///   - defensive matrix: opp attacks my pokemon. Take max over
  ///     opp's damaging moves of `coverageOf(moveType, my slot)`.
  ///   - offensive matrix: my pokemon attacks opp. Take max over
  ///     my pokemon's damaging moves of `coverageOf(moveType, opp
  ///     slot)`.
  /// In both directions empty / all-immune move sets collapse to
  /// 0× (rendered as 무 / ✕).
  CoverageCell _opponentMatchCell(
      _TeamSlot opp,
      _TeamSlot mySlot,
      Map<_TeamSlot, List<CoverageMove>> movesCache) {
    final attacker = offensive ? mySlot : opp;
    final defender = offensive ? opp : mySlot;
    final defenderP = defender.pokemon;
    if (defenderP == null) {
      return const CoverageCell(0, immunityReason: 'noMoves');
    }
    final defenderSlot = CoverageSlot(
      type1: defender.effectiveType1 ?? defenderP.type1,
      type2: defender.effectiveType2,
      type3: defender.effectiveType3,
      ability: defender.ability,
      heldItem: defender.heldItem,
    );
    final coverageMoves = movesCache[attacker] ?? const [];
    final damaging = coverageMoves.where((m) => m.isDamaging).toList();
    if (damaging.isEmpty) {
      return const CoverageCell(0, immunityReason: 'noMoves');
    }
    double best = 0;
    for (final m in damaging) {
      final cell = coverageOf(m.type, defenderSlot);
      if (cell.multiplier > best) best = cell.multiplier;
    }
    if (best == 0) {
      return const CoverageCell(0, immunityReason: 'allImmune');
    }
    return CoverageCell(best);
  }

  Widget _wrapCellForLineup(int slotIdx, Widget child) {
    if (!lineupMode) return child;
    final selected = lineup.contains(slotIdx);
    return Opacity(
      opacity: selected ? 1.0 : 0.30,
      child: child,
    );
  }

  Widget _attackTypeChip(PokemonType type) {
    return ClipRect(
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: KoStrings.getTypeColor(type),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          KoStrings.getTypeName(type),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: const TextStyle(
              fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Background tint for the weak/resist halves of the summary cell —
  /// gets denser the more team members fall into that bucket. 0 is
  /// transparent so it blends with the row's zebra stripe; 6 (full
  /// team) is the most saturated shade we'll show.
  Color _summaryBg(int count, MaterialColor base) {
    return switch (count) {
      0 => Colors.transparent,
      1 => base.shade50,
      2 => base.shade100,
      3 => base.shade200,
      4 => base.shade300,
      _ => base.shade400, // 5 or 6
    };
  }

  /// Side-by-side numbers — weak (red) on the left, resist+immune
  /// (blue) on the right. Each half carries a tint that grows with
  /// the count, so the eye can scan the column and spot the worst
  /// (densest red) and best (densest blue) types at a glance without
  /// reading the digits. Fenced off from the matrix by a thicker
  /// left border.
  Widget _summaryCell(CoverageColumnSummary summary, ColorScheme scheme) {
    final resistOrImmune = summary.resist + summary.immune;
    final weakBg = _summaryBg(summary.weak, Colors.red);
    final resistBg = _summaryBg(resistOrImmune, Colors.blue);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: scheme.onSurface.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              color: weakBg,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${summary.weak}',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  color: summary.weak > 0
                      ? Colors.red.shade900
                      : scheme.onSurface.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: resistBg,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '$resistOrImmune',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  color: resistOrImmune > 0
                      ? Colors.blue.shade900
                      : scheme.onSurface.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One matrix cell — thin wrapper around [MatchupBadge] (shared
  /// with the dex's per-Pokemon matchup chart). The badge owns the
  /// label/colour/pill mapping; this wrapper just sizes the cell to
  /// the matrix row height and shrinks the badge if it overflows the
  /// column. See [MatchupBadge] for the full visual spec.
  Widget _multCell(CoverageCell cell, ColorScheme scheme) {
    final multiplier = cell.isImmune ? 0.0 : cell.multiplier;
    // Per-label fontSize so the column doesn't read as lopsided.
    // Precomposed fractions (½ ¼) and the symbol-mode glyphs render
    // at sub-digit visual size in most fonts, while digit-glyph
    // labels (4×, 2×) and the localized "immune" CJK label (무) come
    // out full-height. Trim the full-height ones a touch so the row
    // feels balanced. FittedBox(scaleDown) still kicks in for narrow
    // columns regardless.
    final isFullHeight = !symbolic
        && (multiplier == 4 || multiplier == 2 || cell.isImmune);
    final fontSize = isFullHeight ? 15.0 : 17.0;
    return Container(
      height: 28,
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: MatchupBadge(
          multiplier: multiplier,
          symbolic: symbolic,
          fontSize: fontSize,
        ),
      ),
    );
  }

}
