import 'package:flutter/material.dart';
import '../../models/type.dart';
import '../../utils/app_strings.dart';
import '../../utils/localization.dart';
import '../../data/pokedex.dart';

/// Result returned by [showTypePickerDialog].
class TypePickerResult {
  final PokemonType type1;
  final PokemonType? type2;
  final PokemonType? type3;
  const TypePickerResult({
    required this.type1,
    this.type2,
    this.type3,
  });
}

/// Multi-select picker for the up-to-3 effective types of a Pokemon
/// (manual overrides for Soak / Forest's Curse / Burn Up scenarios).
///
/// The dialog renders the 18 main types plus a special "없음" chip
/// (PokemonType.typeless). Typeless is mutually exclusive with the
/// real types — picking it clears any others, and picking a real type
/// clears typeless. The user must keep at least one slot filled (a
/// pure-typeless Pokemon counts: it represents a post-Burn Up pure
/// Fire mon).
///
/// "초기화" reverts to the species' natural type1/type2 from
/// [pokemonName] (looked up against pokedex.dart).
Future<TypePickerResult?> showTypePickerDialog({
  required BuildContext context,
  required PokemonType currentType1,
  required PokemonType? currentType2,
  required PokemonType? currentType3,
  required String pokemonName,
}) {
  return showDialog<TypePickerResult>(
    context: context,
    builder: (ctx) => _TypePickerDialog(
      initial: TypePickerResult(
        type1: currentType1,
        type2: currentType2,
        type3: currentType3,
      ),
      pokemonName: pokemonName,
    ),
  );
}

class _TypePickerDialog extends StatefulWidget {
  final TypePickerResult initial;
  final String pokemonName;

  const _TypePickerDialog({
    required this.initial,
    required this.pokemonName,
  });

  @override
  State<_TypePickerDialog> createState() => _TypePickerDialogState();
}

class _TypePickerDialogState extends State<_TypePickerDialog> {
  /// Currently selected types in pick order. Length 1-3. When the
  /// user clears a slot we compact so type1 stays first, etc.
  late List<PokemonType> _selected;

  @override
  void initState() {
    super.initState();
    // Typeless is represented as an empty selection — the "선택 해제"
    // button maps to it and the picker shows zero highlighted chips.
    _selected = [
      if (widget.initial.type1 != PokemonType.typeless) widget.initial.type1,
      if (widget.initial.type2 != null && widget.initial.type2 != PokemonType.typeless)
        widget.initial.type2!,
      if (widget.initial.type3 != null && widget.initial.type3 != PokemonType.typeless)
        widget.initial.type3!,
    ];
  }

  /// 18 main types in dex order. Typeless isn't a chip — it's the
  /// "no selection" state, reachable via "선택 해제".
  static const _options = <PokemonType>[
    PokemonType.normal,
    PokemonType.fire,
    PokemonType.water,
    PokemonType.electric,
    PokemonType.grass,
    PokemonType.ice,
    PokemonType.fighting,
    PokemonType.poison,
    PokemonType.ground,
    PokemonType.flying,
    PokemonType.psychic,
    PokemonType.bug,
    PokemonType.rock,
    PokemonType.ghost,
    PokemonType.dragon,
    PokemonType.dark,
    PokemonType.steel,
    PokemonType.fairy,
  ];

  void _toggle(PokemonType t) {
    setState(() {
      if (_selected.contains(t)) {
        _selected.remove(t);
        return;
      }
      if (_selected.length >= 3) return;
      _selected.add(t);
    });
  }

  Future<void> _resetToSpecies() async {
    final pokedex = await loadPokedex();
    final matches = pokedex.where((p) => p.name == widget.pokemonName);
    if (matches.isEmpty || !mounted) return;
    final species = matches.first;
    setState(() {
      _selected = [species.type1, if (species.type2 != null) species.type2!];
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      title: Text(
        AppStrings.t('type.picker.title'),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in _options)
                _TypeOptionChip(
                  type: t,
                  selected: _selected.contains(t),
                  order: _selected.indexOf(t),
                  onTap: () => _toggle(t),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _resetToSpecies,
          child: Text(AppStrings.t('action.reset')),
        ),
        TextButton(
          onPressed: () => setState(() => _selected = []),
          child: Text(AppStrings.t('type.picker.clear')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            // Empty selection ↔ typeless (post-Burn Up on pure mon).
            _selected.isEmpty
                ? const TypePickerResult(type1: PokemonType.typeless)
                : TypePickerResult(
                    type1: _selected[0],
                    type2: _selected.length > 1 ? _selected[1] : null,
                    type3: _selected.length > 2 ? _selected[2] : null,
                  ),
          ),
          style: TextButton.styleFrom(foregroundColor: scheme.primary),
          child: Text(AppStrings.t('action.confirm')),
        ),
      ],
    );
  }
}

class _TypeOptionChip extends StatelessWidget {
  final PokemonType type;
  final bool selected;
  /// 0-indexed pick order; -1 if not selected. Rendered as a corner
  /// overlay so the chip's box doesn't grow when the badge appears.
  final int order;
  final VoidCallback onTap;

  const _TypeOptionChip({
    required this.type,
    required this.selected,
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Fixed surface color for typeless — the theme outline read as
    // disabled, which made the chip look untappable.
    final scheme = Theme.of(context).colorScheme;
    final color = type == PokemonType.typeless
        ? scheme.onSurface
        : KoStrings.getTypeColor(type);
    final label = type == PokemonType.typeless
        ? AppStrings.t('type.none')
        : KoStrings.getTypeName(type);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // Stack lets the order badge float over the chip's corner
      // without affecting the chip's outer dimensions — Wrap doesn't
      // reflow on toggle.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? color : color.withValues(alpha: 0.08),
              // Constant 1.5px border so picking doesn't grow the box.
              border: Border.all(
                color: selected ? color : color.withValues(alpha: 0.55),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : color,
              ),
            ),
          ),
          if (selected)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Text(
                  '${order + 1}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

