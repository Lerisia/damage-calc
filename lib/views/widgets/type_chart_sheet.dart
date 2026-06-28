import 'package:flutter/material.dart';
import '../../models/type.dart';
import '../../utils/ability_effects.dart' show abilityAdjustedDefensiveMultiplier;
import '../../utils/app_strings.dart';
import '../../utils/localization.dart' show KoStrings;

/// Classic Pokémon 18×18 type-effectiveness matrix in the same
/// `Table` form the team-coverage matrix uses: type labels in the
/// header row/column with cells coloured by multiplier.
///
/// Rows = attacking type, columns = defending type. Labels use
/// `KoStrings.getTypeName` so they pick up the user's locale
/// (한국어 / English / 日本語).
class TypeChartSheet extends StatelessWidget {
  const TypeChartSheet({super.key});

  static void show(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        // Cap width at the table's natural size on desktop so the
        // dialog doesn't waste horizontal space, but let it shrink
        // to whatever the screen offers on mobile — the inner Table
        // is responsive (cells/font scale with available width).
        const naturalWidth = _labelColMax + 18 * _cellColMax + 24;
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: naturalWidth,
              maxHeight: size.height * 0.85,
            ),
            child: const TypeChartSheet(),
          ),
        );
      },
    );
  }

  static const _types = <PokemonType>[
    PokemonType.normal, PokemonType.fire, PokemonType.water, PokemonType.electric,
    PokemonType.grass, PokemonType.ice, PokemonType.fighting, PokemonType.poison,
    PokemonType.ground, PokemonType.flying, PokemonType.psychic, PokemonType.bug,
    PokemonType.rock, PokemonType.ghost, PokemonType.dragon, PokemonType.dark,
    PokemonType.steel, PokemonType.fairy,
  ];

  // Natural column widths — the Table always renders at these sizes;
  // FittedBox(scaleDown) handles narrow viewports by scaling the
  // whole matrix proportionally.
  static const _labelColMax = 52.0;
  static const _cellColMax = 36.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          child: Row(children: [
            Expanded(
              child: Text(
                AppStrings.t('typeChart.title'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(
            AppStrings.t('typeChart.legend'),
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              padding: const EdgeInsets.all(8),
              // Image-style scale-down on mobile: build the table at
              // its native column sizes (the wide-screen layout) and
              // let FittedBox shrink the whole matrix proportionally
              // when the dialog is narrower than ~720 px. Cleaner
              // than per-cell tightening — fonts/borders/cell aspect
              // ratios all shrink together so the chart reads as one
              // image at any width.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: _buildTable(
                  scheme,
                  labelCol: _labelColMax,
                  cellCol: _cellColMax,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(ColorScheme scheme,
      {required double labelCol, required double cellCol}) {
    // Cell font shrinks with width once we're below the natural cell
    // size — keeps the glyph centred and readable instead of clipping.
    final shrink = (cellCol / _cellColMax).clamp(0.45, 1.0);
    final cellFont = (13 * shrink).clamp(8.5, 13).toDouble();
    final headerFont = (11 * shrink).clamp(8.0, 11).toDouble();
    final rowH = (cellCol * 0.9).clamp(20.0, 32.0);
    return Table(
      columnWidths: {
        0: FixedColumnWidth(labelCol),
        for (int i = 0; i < _types.length; i++)
          i + 1: FixedColumnWidth(cellCol),
      },
      border: TableBorder(
        top:    BorderSide(color: scheme.outlineVariant, width: 0.6),
        bottom: BorderSide(color: scheme.outlineVariant, width: 0.6),
        left:   BorderSide(color: scheme.outlineVariant, width: 0.6),
        right:  BorderSide(color: scheme.outlineVariant, width: 0.6),
        horizontalInside: BorderSide(color: scheme.outlineVariant, width: 0.5),
        verticalInside:   BorderSide(color: scheme.outlineVariant, width: 0.5),
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Header row — defender types
        TableRow(children: [
          _CornerHeader(height: rowH),
          for (final d in _types)
            _TypeLabelCell(type: d, height: rowH, fontSize: headerFont),
        ]),
        // 18 attacker rows
        for (final atk in _types)
          TableRow(children: [
            _TypeLabelCell(type: atk, height: rowH, fontSize: headerFont),
            for (final def in _types)
              _MultCell(
                mult: abilityAdjustedDefensiveMultiplier(atk, def, null),
                height: rowH,
                fontSize: cellFont,
              ),
          ]),
      ],
    );
  }
}

class _CornerHeader extends StatelessWidget {
  final double height;
  const _CornerHeader({required this.height});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: Text('↘', style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}

class _TypeLabelCell extends StatelessWidget {
  final PokemonType type;
  final double height;
  final double fontSize;
  const _TypeLabelCell(
      {required this.type, required this.height, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: KoStrings.getTypeColor(type),
      alignment: Alignment.center,
      child: Text(
        KoStrings.getTypeName(type),
        style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.clip,
      ),
    );
  }
}

class _MultCell extends StatelessWidget {
  final double mult;
  final double height;
  final double fontSize;
  const _MultCell(
      {required this.mult, required this.height, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final (bg, label, fg) = _styleFor(mult);
    return Container(
      height: height,
      color: bg,
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
            color: fg, fontSize: fontSize, fontWeight: FontWeight.w700),
      ),
    );
  }

  static (Color, String, Color) _styleFor(double m) {
    if (m == 0.0) return (Colors.grey.shade800, '0', Colors.white);
    if (m == 0.5) return (Colors.green.shade600, '½', Colors.white);
    if (m == 2.0) return (Colors.red.shade600,   '2', Colors.white);
    return (Colors.transparent, '', Colors.black);
  }
}
