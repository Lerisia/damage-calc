part of '../dex_screen.dart';

class _Header extends StatelessWidget {
  final Pokemon pokemon;
  final bool shiny;
  final ValueChanged<bool> onShinyChanged;
  const _Header({
    required this.pokemon,
    required this.shiny,
    required this.onShinyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final altName = AppStrings.current == AppLanguage.ko
        ? '${pokemon.nameEn ?? pokemon.name} · ${pokemon.nameJa}'
        : (AppStrings.current == AppLanguage.ja
            ? '${pokemon.nameEn ?? pokemon.name} · ${pokemon.nameKo}'
            : '${pokemon.nameKo} · ${pokemon.nameJa}');
    // The header gets a sprite slot down the left — the slot is always
    // reserved (pokéball placeholder when no sprite is available) so
    // the layout stays the same shape regardless of platform / cache /
    // Champions-original coverage. The send buttons used to share the
    // name row here but they squeezed the name into a stub on narrow
    // screens; they now live in the app bar instead.
    //
    // Dex number used to live to the left of the name as `#0042`
    // but that's redundant — list rows already surface it and the
    // detail page benefits more from giving the name (and the new
    // shiny toggle) the full row width.
    final infoColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                pokemon.localizedName,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Shiny toggle anchored to the right of the species name
            // (per UX direction — easier to spot at the natural end
            // of the title row). Session-only — `_MainTabState`
            // resets it whenever the user navigates to a different
            // species. Persisting a shiny pick is what saved samples
            // are for.
            InkWell(
              onTap: () => onShinyChanged(!shiny),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 2, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      shiny
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: shiny
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppStrings.t('dex.shinyToggle'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(altName,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            TypeChip(pokemon.type1),
            if (pokemon.type2 != null) TypeChip(pokemon.type2!),
          ],
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PokemonSprite(
                  pokemonName: pokemon.name, size: 80, shiny: shiny),
              const SizedBox(width: 12),
              Expanded(child: infoColumn),
            ],
          ),
          const SizedBox(height: 8),
          DefaultTextStyle(
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: _metaCell(
                          AppStrings.t('dex.height'), '${pokemon.height} m'),
                    ),
                    Expanded(
                      child: _metaCell(
                          AppStrings.t('dex.weight'), '${pokemon.weight} kg'),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                _metaCell(AppStrings.t('dex.gender'), _genderValue(pokemon)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _metaCell(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 56,
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Flexible(child: Text(value)),
      ],
    );
  }

  static String _genderValue(Pokemon p) {
    if (p.genderRate == -1) return AppStrings.t('dex.genderless');
    if (p.genderRate == 0) return '♂';
    if (p.genderRate == 8) return '♀';
    final female = p.genderRate / 8 * 100;
    final male = 100 - female;
    return '♂ ${male.toStringAsFixed(male % 1 == 0 ? 0 : 1)}% / '
        '♀ ${female.toStringAsFixed(female % 1 == 0 ? 0 : 1)}%';
  }

}

class _StatRow extends StatelessWidget {
  final Pokemon pokemon;
  const _StatRow({required this.pokemon});

  @override
  Widget build(BuildContext context) {
    final s = pokemon.baseStats;
    final values = [s.hp, s.attack, s.defense, s.spAttack, s.spDefense, s.speed];
    final labels = [
      AppStrings.t('stat.hp'),
      AppStrings.t('stat.attack'),
      AppStrings.t('stat.defense'),
      AppStrings.t('stat.spAttack'),
      AppStrings.t('stat.spDefense'),
      AppStrings.t('stat.speed'),
    ];
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final total = values.reduce((a, b) => a + b);

    Widget cell(String label, int v, {bool isTotal = false}) {
      Color? color;
      FontWeight weight = FontWeight.w600;
      if (!isTotal) {
        if (v == maxValue) {
          color = Colors.red;
          weight = FontWeight.w700;
        } else if (v == minValue) {
          color = Colors.grey;
        }
      }
      return Expanded(
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('$v',
                style: TextStyle(fontSize: 15, color: color, fontWeight: weight)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (int i = 0; i < 6; i++) cell(labels[i], values[i]),
          Container(
            width: 1, height: 30, color: Colors.grey.withValues(alpha: 0.4),
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          cell(AppStrings.t('dex.statTotal'), total, isTotal: true),
        ],
      ),
    );
  }
}
