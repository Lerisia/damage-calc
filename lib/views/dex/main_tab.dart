part of '../dex_screen.dart';

class _MainTab extends StatefulWidget {
  final Pokemon? pokemon;
  final Map<String, Ability> abilityDex;
  final Map<String, Move> moveDex;

  const _MainTab({
    required this.pokemon,
    required this.abilityDex,
    required this.moveDex,
  });

  @override
  State<_MainTab> createState() => _MainTabState();
}

class _MainTabState extends State<_MainTab> {
  /// Ability the user has selected for the bulk / decisive power
  /// tables. Defaulted from curated usage data (or species' first
  /// ability) when the species changes.
  String? _selectedAbility;

  /// Show shiny art for the header sprite. Session-only — resets to
  /// false whenever the user lands on a new species. The dex is a
  /// browse / inspect surface; users who want a persistent shiny
  /// pick should save the Pokémon as a sample (carries `shiny`).
  bool _shiny = false;

  @override
  void initState() {
    super.initState();
    _seedAbility();
  }

  @override
  void didUpdateWidget(_MainTab old) {
    super.didUpdateWidget(old);
    if (old.pokemon?.name != widget.pokemon?.name) {
      _seedAbility();
      // Different species → wipe the shiny toggle so the new entry
      // starts at its default art.
      _shiny = false;
    }
  }

  /// Pick a default ability for calc tables — curated top pick wins
  /// when the species has usage data; otherwise falls back to the
  /// species' first listed ability.
  void _seedAbility() {
    final p = widget.pokemon;
    if (p == null) {
      _selectedAbility = null;
      return;
    }
    final curated = championsUsageFor(p.name)?.abilities;
    String? picked;
    if (curated != null && curated.isNotEmpty) {
      final first = curated.first.name;
      if (p.abilities.contains(first)) picked = first;
    }
    picked ??= p.abilities.isNotEmpty ? p.abilities.first : null;
    _selectedAbility = picked;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pokemon;
    if (p == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(AppStrings.t('dex.title'),
              style: TextStyle(color: Colors.grey.shade600)),
        ),
      );
    }
    return SingleChildScrollView(
      // Generous bottom inset matches the calculator tabs (120 px) so
      // the last decisive-power row never butts against the system
      // gesture bar / keyboard, and gives the eye some breathing room.
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            pokemon: p,
            shiny: _shiny,
            onShinyChanged: (v) => setState(() => _shiny = v),
          ),
          const SizedBox(height: 12),
          _StatRow(pokemon: p),
          const SizedBox(height: 16),
          _AbilitiesSection(pokemon: p, abilityDex: widget.abilityDex),
          const SizedBox(height: 16),
          // Picker comes BEFORE the type matchup chart so the user
          // can see the chart change as they switch abilities
          // (Snorlax + Thick Fat shifts Fire/Ice into the resist
          // bucket, Levitate moves Ground into the immunity bucket,
          // Wonder Guard collapses everything that isn't SE to 0×,
          // etc.). "특성 없음" reverts to the pure-type chart.
          if (p.abilities.isNotEmpty) ...[
            _CalcAbilityPicker(
              pokemon: p,
              abilityDex: widget.abilityDex,
              selected: _selectedAbility,
              onChanged: (ab) => setState(() => _selectedAbility = ab),
            ),
            const SizedBox(height: 12),
          ],
          _TypeMatchupsSection(pokemon: p, ability: _selectedAbility),
          const SizedBox(height: 16),
          _BulkSection(pokemon: p, ability: _selectedAbility),
          const SizedBox(height: 16),
          _DecisivePowerSection(
            pokemon: p,
            moveDex: widget.moveDex,
            ability: _selectedAbility,
          ),
        ],
      ),
    );
  }
}

/// Flat chip used by the calc-ability picker. Deliberately not
/// [ChoiceChip] — Material's chip animates a checkmark in/out on
/// selection which jiggles the row's metrics. Here we only flip the
/// fill color so tapping is visually instant.
class _AbilityChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AbilityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? scheme.primary.withValues(alpha: 0.18) : Colors.transparent;
    final fg = selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.8);
    final border = selected ? scheme.primary : scheme.outlineVariant;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

/// Compact picker that drives the bulk + decisive-power tables. Shows
/// the species' ability list (one row) and lets the user tap to switch.
/// Auto-applied weather/terrain (Drought → Sun, etc.) is handled by the
/// table sections themselves.
class _CalcAbilityPicker extends StatelessWidget {
  final Pokemon pokemon;
  final Map<String, Ability> abilityDex;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _CalcAbilityPicker({
    required this.pokemon,
    required this.abilityDex,
    required this.selected,
    required this.onChanged,
  });

  String _label(String key) => abilityDex[key]?.localizedName ?? key;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Text(
            AppStrings.t('dex.calcAbility'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                // Stateful ability bases (Supreme Overlord, Rivalry)
                // get mapped to a default variant ("Supreme Overlord
                // 0", "Rivalry Same") so the chip carries a key the
                // damage calc actually understands. Mirrors what
                // applyPokemon does on the calc side.
                for (final raw in pokemon.abilities)
                  _AbilityChip(
                    label: _label(
                        BattlePokemonState.expandAbilityKey(raw) ?? raw),
                    selected: selected ==
                        (BattlePokemonState.expandAbilityKey(raw) ?? raw),
                    onTap: () => onChanged(
                        BattlePokemonState.expandAbilityKey(raw) ?? raw),
                  ),
                // "특성 없음" — lets the user remove the ability so
                // the type matchup chart and downstream calc tables
                // recompute as if no ability were active.
                _AbilityChip(
                  label: AppStrings.t('dex.calcAbility.none'),
                  selected: selected == null,
                  onTap: () => onChanged(null),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
