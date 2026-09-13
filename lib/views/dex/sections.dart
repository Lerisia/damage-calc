part of '../dex_screen.dart';

class _AbilitiesSection extends StatelessWidget {
  final Pokemon pokemon;
  final Map<String, Ability> abilityDex;

  const _AbilitiesSection({required this.pokemon, required this.abilityDex});

  @override
  Widget build(BuildContext context) {
    final abs = pokemon.abilities;
    // Convention: last ability in the list is the hidden one when 3
    // are listed (PokeAPI convention is preserved in our data). We
    // tag with '*' when this looks like a HA pattern.
    final hiddenIndex = abs.length >= 2 ? abs.length - 1 : -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(AppStrings.t('dex.abilities')),
        const SizedBox(height: 6),
        if (abs.isEmpty)
          // Placeholder for fan/unreleased mega forms whose abilities
          // haven't been officially revealed — show "미공개" with a
          // short note that it'll be updated once official info drops.
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.t('dex.abilityUnrevealed'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 2),
                  child: Text(
                    AppStrings.t('dex.abilityUnrevealedDesc'),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (int i = 0; i < abs.length; i++)
            _abilityRow(abs[i], isHidden: i == hiddenIndex && abs.length >= 2),
      ],
    );
  }

  Widget _abilityRow(String key, {required bool isHidden}) {
    final ab = abilityDex[key];
    // Stateful abilities ship as numbered / state-suffixed variants
    // ("Supreme Overlord 0", "Disguise Busted") with no descriptions
    // of their own. Fall back to the base entry — added with
    // descriptionOnly: true — so the dex shows the canonical name +
    // explanation instead of "총대장 ×0" + nothing.
    final base = abilityBaseFor(key);
    final baseAb = base != null ? abilityDex[base] : null;
    final name = baseAb?.localizedName ?? ab?.localizedName ?? key;
    final desc =
        baseAb?.localizedDescription ?? ab?.localizedDescription;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(name,
                  style:
                      const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (isHidden)
                Text(' *',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w700)),
            ],
          ),
          if (desc != null && desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 2),
              child: Text(desc,
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 2),
              child: Text(AppStrings.t('dex.noDescription'),
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                      fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }
}

class _TypeMatchupsSection extends StatelessWidget {
  final Pokemon pokemon;
  final String? ability;
  const _TypeMatchupsSection({required this.pokemon, this.ability});

  @override
  Widget build(BuildContext context) {
    // Build buckets keyed by multiplier. Hide buckets that end up empty.
    final buckets = <double, List<PokemonType>>{
      4.0: [],
      2.0: [],
      1.0: [],
      0.5: [],
      0.25: [],
      0.0: [],
    };
    for (final atkType in PokemonType.values) {
      if (atkType == PokemonType.typeless) continue;
      // Stellar is a Terastal-only attacker type with a fixed 1×/2× rule
      // against Terastallized targets; hiding it from the dex chart
      // matches user expectation for "normal" matchups.
      if (atkType == PokemonType.stellar) continue;
      // abilityAdjustedDefensiveMultiplier folds the pure type chart,
      // the type immunity table (Ground vs Flying, Poison vs Steel,
      // etc.), and any ability-driven changes (Levitate / Thick Fat /
      // Wonder Guard / Fluffy / …) into one number that lines up with
      // the chart's bucket keys. Pass ability=null for the pure-type
      // view.
      final mult = abilityAdjustedDefensiveMultiplier(
        atkType,
        pokemon.type1,
        pokemon.type2,
        ability: ability,
      );
      if (buckets.containsKey(mult)) buckets[mult]!.add(atkType);
    }
    final activeKeys = buckets.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => e.key)
        .toList();
    if (activeKeys.isEmpty) return const SizedBox.shrink();

    // Responsive chip font: shrink as more columns are visible / on
    // narrow phones.
    final width = MediaQuery.of(context).size.width;
    final colCount = activeKeys.length;
    final tightFactor = (width / (colCount * 70)).clamp(0.7, 1.0);
    final fontSize = 11.0 * tightFactor;
    final padH = (6 * tightFactor).clamp(3.0, 6.0);
    final padV = (2 * tightFactor).clamp(1.5, 2.0);

    Widget chip(PokemonType t) => Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            color: KoStrings.getTypeColor(t),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(KoStrings.getTypeName(t),
              style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
        );

    Widget column(double key) {
      final types = buckets[key]!;
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Dex chart is hard-pinned to numeric labels regardless
            // of the global CoverageDisplayController (symbolic mode
            // is a team-tab affordance — dex users expect numbers).
            // showNeutral: true so the 1× column carries an explicit
            // header instead of a blank slot next to 2×/½/등.
            MatchupBadge(
              multiplier: key,
              symbolic: false,
              showNeutral: true,
              fontSize: 16,
            ),
            const SizedBox(height: 6),
            for (final t in types) ...[
              chip(t),
              const SizedBox(height: 4),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(AppStrings.t('dex.typeMatchups')),
        const SizedBox(height: 8),
        // Per-pokemon matchup chart renders at its natural size
        // on every breakpoint. Mobile fit is handled by the
        // per-chip `tightFactor` font/padding scaler above —
        // NO FittedBox here. (Earlier I wrapped this in one
        // mistakenly thinking the "mobile shrink to fit" ask
        // applied here; it was scoped to TypeChartSheet only.)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final k in activeKeys) column(k)],
        ),
      ],
    );
  }
}

/// Build a stripped-down [BattlePokemonState] the dex can feed into
/// [BattleFacade]. All defender-specific battle toggles (status, rank,
/// allies, rooms, etc.) stay at their defaults — the dex is a raw
/// species baseline, not an in-battle snapshot.
BattlePokemonState _dexState({
  required Pokemon pokemon,
  required String? ability,
  required Stats ev,
  required NatureProfile nature,
  required Stats iv,
  required int level,
  Move? move,
  int? hits,
  int? powerOverride,
}) {
  return BattlePokemonState(
    pokemonName: pokemon.name,
    pokemonNameKo: pokemon.nameKo,
    pokemonNameJa: pokemon.nameJa,
    pokemonNameEn: pokemon.nameEn,
    dexNumber: pokemon.dexNumber,
    finalEvo: pokemon.finalEvo,
    genderRate: pokemon.genderRate,
    type1: pokemon.type1,
    type2: pokemon.type2,
    weight: pokemon.weight,
    baseStats: pokemon.baseStats,
    pokemonAbilities: pokemon.abilities,
    selectedAbility: BattlePokemonState.expandAbilityKey(ability),
    level: level,
    nature: nature,
    iv: iv,
    ev: ev,
    moves: [move, null, null, null],
    hitOverrides: [hits, null, null, null],
    powerOverrides: [powerOverride, null, null, null],
    isMega: pokemon.isMega,
    canDynamax: pokemon.canDynamax,
    canGmax: pokemon.canGmax,
    selectedItem: pokemon.requiredItem,
  );
}

class _BulkSection extends StatelessWidget {
  final Pokemon pokemon;
  /// Ability used by the bulk calc. Unconditional Def/SpD modifiers
  /// (Fur Coat, Ice Scales-adjacent, Grass Pelt under terrain, etc.)
  /// flow into the numbers; weather/terrain that the ability implies
  /// (Drought → Sun, Grassy Surge → Grassy terrain) is auto-activated
  /// so bulk reflects the on-field reality of that species.
  final String? ability;
  const _BulkSection({required this.pokemon, this.ability});

  static const _level = 50;
  static const _fullIv = Stats(
      hp: 31, attack: 31, defense: 31, spAttack: 31, spDefense: 31, speed: 31);

  @override
  Widget build(BuildContext context) {
    // Three investment tiers — "준보정" is rare in practice so we skip
    // it. Bulk routes through [BattleFacade.calcBulk] so the numbers
    // match what the calculator's defender panel shows (HP × Def /
    // 0.411, with the full ability chain applied).
    const baseEv = Stats(
        hp: 0, attack: 0, defense: 0, spAttack: 0, spDefense: 0, speed: 0);

    final weather =
        ability != null ? (abilityWeatherMap[ability!] ?? Weather.none) : Weather.none;
    final terrain =
        ability != null ? (abilityTerrainMap[ability!] ?? Terrain.none) : Terrain.none;

    ({int physical, int special}) bulk(Stats ev, NatureProfile nat) =>
        BattleFacade.calcBulk(
          state: _dexState(
            pokemon: pokemon,
            ability: ability,
            ev: ev,
            nature: nat,
            iv: _fullIv,
            level: _level,
          ),
          weather: weather,
          terrain: terrain,
          room: const RoomConditions(),
        );

    final none = bulk(baseEv, const NatureProfile());
    final hpOnly = bulk(baseEv.copyWith(hp: 252), const NatureProfile());
    final hb = bulk(baseEv.copyWith(hp: 252, defense: 252),
        const NatureProfile(up: NatureStat.def));
    final hd = bulk(baseEv.copyWith(hp: 252, spDefense: 252),
        const NatureProfile(up: NatureStat.spd));

    // 4-row layout. For HB/HD rows the "off-axis" column (SpD on HB,
    // Def on HD) is mathematically identical to the H32 value — no
    // EV or nature changes that stat — so we surface that value
    // rather than leaving it blank. The user still gets a complete
    // picture of the spread's total bulk footprint.
    final rows = <(String, int, int)>[
      (AppStrings.t('dex.bulkNone'), none.physical, none.special),
      (AppStrings.t('dex.bulkH'), hpOnly.physical, hpOnly.special),
      (AppStrings.t('dex.bulkHB'), hb.physical, hpOnly.special),
      (AppStrings.t('dex.bulkHD'), hpOnly.physical, hd.special),
    ];

    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(AppStrings.t('dex.bulk')),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(
            color: scheme.outlineVariant,
            width: 1,
          ),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(3),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              children: [
                const SizedBox.shrink(),
                _DexTableCell(AppStrings.t('dex.bulkPhysical'),
                    bold: true, dim: true),
                _DexTableCell(AppStrings.t('dex.bulkSpecial'),
                    bold: true, dim: true),
              ],
            ),
            for (final r in rows)
              TableRow(children: [
                _DexTableCell(r.$1, align: TextAlign.left, bold: true),
                _DexTableCell(_fmt(r.$2), bold: true),
                _DexTableCell(_fmt(r.$3), bold: true),
              ]),
          ],
        ),
      ],
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// 결정력 table — shows raw offensive output for each of the
/// species' curated key moves at three investment tiers (none /
/// half / full). STAB is applied when the move's type matches the
/// species's type; no item, rank or ability modifiers are included.
class _DecisivePowerSection extends StatefulWidget {
  final Pokemon pokemon;
  final Map<String, Move> moveDex;
  /// Ability for decisive power. Offensive modifiers (Adaptability,
  /// Huge Power, Sheer Force, …) flow through OffensiveCalculator via
  /// `attackerAbility`; weather/terrain this ability would set on
  /// switch-in (Drought, Grassy Surge, …) is auto-activated for the
  /// duration of the calc.
  final String? ability;

  const _DecisivePowerSection({
    required this.pokemon,
    required this.moveDex,
    this.ability,
  });

  @override
  State<_DecisivePowerSection> createState() => _DecisivePowerSectionState();
}

class _DecisivePowerSectionState extends State<_DecisivePowerSection> {
  static const _level = 50;
  static const _fullIv = Stats(
      hp: 31, attack: 31, defense: 31, spAttack: 31, spDefense: 31, speed: 31);
  static const _baseEv = Stats(
      hp: 0, attack: 0, defense: 0, spAttack: 0, spDefense: 0, speed: 0);

  // Per-row hit count for multi-hit moves, keyed by move English name.
  final Map<String, int> _hits = {};

  // Scratch-row move picked by the user for ad-hoc damage lookups.
  Move? _customMove;
  int _customHits = 1;

  /// True while the scratch selector has focus. Drives the layout
  /// swap — picking widens the selector back to full row, collapsing
  /// to the fused 4-column layout on blur.
  bool _scratchFocused = false;

  @override
  void initState() {
    super.initState();
    _seedHits();
  }

  @override
  void didUpdateWidget(_DecisivePowerSection old) {
    super.didUpdateWidget(old);
    if (old.pokemon != widget.pokemon || old.moveDex != widget.moveDex) {
      _hits.clear();
      _customMove = null;
      _customHits = 1;
      _seedHits();
    }
  }

  /// Curated damage-move pool from the Champions Singles usage data.
  /// Falls back to the legacy `pokemon.keyMoves` list (unsuffixed names
  /// only) for species that haven't been curated yet. Filters out moves
  /// whose output doesn't reflect the user's own offensive stats —
  /// status moves (power 0), fixed-damage / OHKO moves, and Foul Play
  /// (which scales off the target's Attack).
  List<Move> _decisiveMoves() {
    final usage = championsUsageFor(widget.pokemon.name);
    final rawNames = <String>[];
    if (usage != null && usage.moves.isNotEmpty) {
      rawNames.addAll(usage.moves.map((row) => row.name));
    } else {
      // Legacy fallback: strip the ":N" hit-count suffix if present.
      rawNames.addAll(widget.pokemon.keyMoves.map((s) => s.split(':').first));
    }
    final out = <Move>[];
    for (final name in rawNames) {
      final m = widget.moveDex[name];
      if (m == null) continue;
      if (m.power <= 0) continue;
      if (_doesntScaleWithUserOffense(m)) continue;
      out.add(m);
    }
    return out;
  }

  bool _doesntScaleWithUserOffense(Move m) =>
      m.hasTag(MoveTags.ohko) ||
      m.hasTag(MoveTags.fixedLevel) ||
      m.hasTag(MoveTags.fixedHalfHp) ||
      m.hasTag(MoveTags.fixedThreeQuarterHp) ||
      m.hasTag(MoveTags.fixed20) ||
      m.hasTag(MoveTags.fixed40) ||
      m.hasTag(MoveTags.useOpponentAtk);

  void _seedHits() {
    for (final m in _decisiveMoves()) {
      if (m.isMultiHit) {
        _hits[m.name] = m.maxHits;
      } else if (isStackingPower(m)) {
        _hits[m.name] = stackingDefaultTier(m);
      }
    }
  }

  /// Run a decisive-power calc for [m] under the given EV/nature. We
  /// route the call through [BattleFacade.getMoveSlotInfo] so every
  /// ability-driven transform (Pixilate, Liquid Voice, Sheer Force,
  /// Adaptability, Huge Power, …) is applied the same way the
  /// calculator does. Multi-hit `hits` feeds into the move slot's
  /// hit-count override; for stacking-power moves (Last Respects)
  /// `hits` is reinterpreted as a power override.
  int _outputFor(Move m, Stats ev, NatureProfile nat, int hits) {
    final ab = widget.ability;
    final weather =
        ab != null ? (abilityWeatherMap[ab] ?? Weather.none) : Weather.none;
    final terrain =
        ab != null ? (abilityTerrainMap[ab] ?? Terrain.none) : Terrain.none;
    final state = _dexState(
      pokemon: widget.pokemon,
      ability: ab,
      ev: ev,
      nature: nat,
      iv: _fullIv,
      level: _level,
      move: m,
      hits: m.isMultiHit ? hits : null,
      powerOverride:
          isStackingPower(m) ? stackingPower(m, hits) : null,
    );
    final info = BattleFacade.getMoveSlotInfo(
      state: state,
      moveIndex: 0,
      weather: weather,
      terrain: terrain,
      room: const RoomConditions(),
    );
    return info.offensivePower ?? 0;
  }

  /// Whether [m] should expose an ×N picker — either it's a
  /// variable multi-hit or a stacking-power move.
  bool _hasTierPicker(Move m) =>
      (m.isMultiHit && m.minHits != m.maxHits) || isStackingPower(m);

  /// Which stat the move scales off (Body Press → Def, etc.). Kept
  /// here only to pick the right EV/nature column; actual stat
  /// selection inside the calc happens in [transformMove].
  NatureStat _investStat(Move m) {
    if (m.hasTag(MoveTags.useDefense)) return NatureStat.def;
    return m.category == MoveCategory.physical
        ? NatureStat.atk
        : NatureStat.spa;
  }

  NatureProfile _fullNature(Move m) => NatureProfile(up: _investStat(m));

  Stats _halfEv(Move m) {
    switch (_investStat(m)) {
      case NatureStat.atk:
        return _baseEv.copyWith(attack: 252);
      case NatureStat.spa:
        return _baseEv.copyWith(spAttack: 252);
      case NatureStat.def:
        return _baseEv.copyWith(defense: 252);
      case NatureStat.spd:
        return _baseEv.copyWith(spDefense: 252);
      case NatureStat.spe:
        return _baseEv.copyWith(speed: 252);
    }
  }

  Future<int?> _showHitPicker(Move m) async {
    if (!_hasTierPicker(m)) return null;
    final stackMaxVal = stackingMax(m);
    final (lo, hi) = stackMaxVal != null
        ? (1, stackMaxVal)
        : (m.minHits, m.maxHits);
    return showDialog<int>(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (int n = lo; n <= hi; n++)
                InkWell(
                  onTap: () => Navigator.pop(ctx, n),
                  child: Container(
                    width: 44,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('×$n',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickKeyMoveHits(String rawKey, Move m) async {
    final picked = await _showHitPicker(m);
    if (picked != null && mounted) {
      setState(() => _hits[rawKey] = picked);
    }
  }

  Future<void> _pickCustomHits(Move m) async {
    final picked = await _showHitPicker(m);
    if (picked != null && mounted) {
      setState(() => _customHits = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String tierLabel(String k) => k == 'dex.bulkHp'
        ? AppStrings.t('dex.decisiveHalf')
        : AppStrings.t(k);

    final curatedRows = <TableRow>[];
    for (final m in _decisiveMoves()) {
      final hits = _hits[m.name] ?? 1;
      final v1 = _outputFor(m, _baseEv, const NatureProfile(), hits);
      final v2 = _outputFor(m, _halfEv(m), const NatureProfile(), hits);
      final v3 = _outputFor(m, _halfEv(m), _fullNature(m), hits);
      curatedRows.add(TableRow(children: [
        _moveLabel(m, hits: hits, onTap: () => _pickKeyMoveHits(m.name, m)),
        _DexTableCell(_BulkSection._fmt(v1), bold: true),
        _DexTableCell(_BulkSection._fmt(v2), bold: true),
        _DexTableCell(_BulkSection._fmt(v3), bold: true),
      ]));
    }

    // Scratch area below the table. The MoveSelector claims the full
    // section width (no column-1 squeeze) so search is roomy; once a
    // move is picked, a compact 4-column row beneath shows its values
    // aligned with the main table's columns.
    final custom = _customMove;
    int? c1, c2, c3;
    int customHits = _customHits;
    if (custom != null && custom.power > 0) {
      customHits = custom.isMultiHit && _customHits < custom.minHits
          ? custom.minHits
          : _customHits;
      c1 = _outputFor(custom, _baseEv, const NatureProfile(), customHits);
      c2 = _outputFor(
          custom, _halfEv(custom), const NatureProfile(), customHits);
      c3 = _outputFor(
          custom, _halfEv(custom), _fullNature(custom), customHits);
    }

    final customHasTierPicker = custom != null && _hasTierPicker(custom);

    // Single Row layout — flex values change instead of the widget
    // tree, so tapping the compact selector doesn't unmount it (which
    // was losing focus and forcing a second tap). Expand to flex 9
    // (the full 3+2+2+2 table width) while focused or empty; collapse
    // to flex 3 (matching the column-1 width) once a move is set and
    // focus is lost so the results line up with the main table.
    final fuseWithValues =
        !_scratchFocused && custom != null && custom.power > 0;
    final scratchArea = Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
        border: Border.all(color: scheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: fuseWithValues ? 3 : 9,
            child: Row(
              children: [
                Expanded(
                  child: MoveSelector(
                    key: ValueKey(
                        'dex_decisive_custom_${widget.pokemon.name}'),
                    initialMoveName: custom?.name,
                    pokemonName: widget.pokemon.name,
                    pokemonNameKo: widget.pokemon.nameKo,
                    dexNumber: widget.pokemon.dexNumber,
                    onFocusChanged: (f) {
                      if (_scratchFocused != f) {
                        setState(() => _scratchFocused = f);
                      }
                    },
                    onSelected: (m) => setState(() {
                      _customMove = m;
                      _customHits = m.isMultiHit ? m.maxHits : 1;
                    }),
                  ),
                ),
                if (customHasTierPicker) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _pickCustomHits(custom),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: scheme.onSurface.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '×$customHits',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (fuseWithValues) ...[
            Expanded(
              flex: 2,
              child: _DexTableCell(_BulkSection._fmt(c1!), bold: true),
            ),
            Expanded(
              flex: 2,
              child: _DexTableCell(_BulkSection._fmt(c2!), bold: true),
            ),
            Expanded(
              flex: 2,
              child: _DexTableCell(_BulkSection._fmt(c3!), bold: true),
            ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(AppStrings.t('dex.decisive')),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(
            color: scheme.outlineVariant,
            width: 1,
          ),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(2),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              children: [
                const SizedBox.shrink(),
                for (final k in const [
                  'dex.bulkNone',
                  'dex.bulkHp',
                  'dex.bulkFull',
                ])
                  _DexTableCell(tierLabel(k), bold: true, dim: true),
              ],
            ),
            ...curatedRows,
          ],
        ),
        const SizedBox(height: 6),
        scratchArea,
      ],
    );
  }

  Widget _moveLabel(Move m,
      {required int hits, required VoidCallback onTap}) {
    final canPick = _hasTierPicker(m);
    final isStacking = isStackingPower(m);
    final name = m.localizedName;
    // Stacking moves (Last Respects) always keep the chip so the
    // picker is discoverable even at the x1 baseline. Multi-hit moves
    // collapse to a plain row when the user's picked x1.
    if (!canPick || (!isStacking && hits <= 1)) {
      return _DexTableCell(name, align: TextAlign.left, bold: true);
    }
    // Multi-hit: name + tappable (×N) chip. Inside the same cell so
    // table column sizing is still driven by label column flex.
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: canPick ? onTap : null,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(
                    color: scheme.onSurface.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '×$hits',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared cell widget for the dex tables — gives consistent padding,
/// alignment, font sizing across the bulk and decisive-power tables.
class _DexTableCell extends StatelessWidget {
  final String text;
  final bool bold;
  final bool dim;
  final TextAlign align;

  const _DexTableCell(
    this.text, {
    this.bold = false,
    this.dim = false,
    this.align = TextAlign.right,
  });

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 14,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: dim ? fg.withValues(alpha: 0.7) : fg,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800));
  }
}
