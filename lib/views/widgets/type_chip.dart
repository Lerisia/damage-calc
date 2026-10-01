import 'package:flutter/material.dart';

import '../../i18n/app_strings.dart';
import '../../i18n/localization.dart';
import '../../models/type.dart';

/// One chip shape at three scales.
enum TypeChipSize {
  /// Rows, lists and headers that sit next to other content.
  dense,

  /// Stand-alone headers (dex header, damage card).
  regular,

  /// Tap targets in type pickers.
  large,
}

/// THE way a Pokémon type is shown anywhere in the app: the type's
/// colour as the fill, its name in bold white.
///
/// Until 2026-10-02 the same information was drawn four different ways
/// — a coloured chip next to the species, coloured text in move lists,
/// plain text in the move rows, a coloured dot in Simple Mode — plus a
/// dozen hand-rolled copies of the chip with slightly different
/// paddings and radii. Design review: the same information must look
/// the same. So nothing else builds a type-coloured box; the guard in
/// `test/widgets/type_chip_usage_test.dart` keeps it that way.
///
/// Variants are parameters of the one shape, not new shapes:
///  * [size] — dense / regular / large.
///  * [selected] — null for a plain display chip. Non-null turns it
///    into a picker option: `true` is the filled chip, `false` the
///    outlined, tinted "off" state. Both carry the same border width,
///    so toggling never changes the chip's size.
///  * [dimmed] — secondary: an option that matches nothing, a move the
///    Pokémon can't learn.
///  * [ringColor] — a ring drawn inside the chip's bounds (no size
///    change): white for a Terastallized type.
///  * [dotColor] — a small dot on the top-right corner, half outside
///    the chip (no size change either): orange for a manually
///    overridden move type. A dot rather than a ring because an orange
///    ring disappears on a Fire chip.
///  * [width] — a fixed column width (tables) or `double.infinity` to
///    fill the cell; the label is centred and scales down to fit.
///  * [scale] — uniform shrink for a crowded grid, so every chip in it
///    stays the same size as its neighbours.
///
/// [PokemonType.typeless] renders as a neutral "없음" chip.
class TypeChip extends StatelessWidget {
  final PokemonType type;
  final TypeChipSize size;
  final bool? selected;
  final bool dimmed;
  final Color? ringColor;
  final Color? dotColor;
  final double? width;
  final double scale;
  final VoidCallback? onTap;

  const TypeChip(
    this.type, {
    super.key,
    this.size = TypeChipSize.regular,
    this.selected,
    this.dimmed = false,
    this.ringColor,
    this.dotColor,
    this.width,
    this.scale = 1.0,
    this.onTap,
  });

  const TypeChip.dense(
    this.type, {
    super.key,
    this.selected,
    this.dimmed = false,
    this.ringColor,
    this.dotColor,
    this.width,
    this.scale = 1.0,
    this.onTap,
  }) : size = TypeChipSize.dense;

  /// A picker option: [selected] is required.
  const TypeChip.option(
    this.type, {
    super.key,
    required bool this.selected,
    this.dimmed = false,
    this.onTap,
  })  : size = TypeChipSize.large,
        ringColor = null,
        dotColor = null,
        width = null,
        scale = 1.0;

  static const double _borderWidth = 1.5;

  /// In a fixed-width chip the side padding is only a minimum margin —
  /// the label is centred — so a three-letter name still fits a narrow
  /// table column at full size.
  static const double _fixedWidthPadH = 3;

  /// (font size, horizontal padding, vertical padding, corner radius).
  /// The radius grows with the chip so the large one reads as the same
  /// shape scaled up, not a boxier one.
  static (double, double, double, double) _metrics(TypeChipSize s) =>
      switch (s) {
        TypeChipSize.dense => (11, 6, 2, 4),
        TypeChipSize.regular => (12, 8, 3, 4),
        TypeChipSize.large => (13, 10, 6, 6),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOption = selected != null;
    final on = selected ?? true;
    final typeless = type == PokemonType.typeless;

    // Typeless has no colour of its own: a quiet grey as a display
    // chip, the text colour as a picker option (the outline grey read
    // as "disabled" there).
    final base = typeless
        ? (isOption ? scheme.onSurface : scheme.outline)
        : KoStrings.getTypeColor(type);
    final label =
        typeless ? AppStrings.t('type.none') : KoStrings.getTypeName(type);

    final (font, padH, padV, radius) = _metrics(size);
    final Color fill;
    final Color text;
    if (on) {
      fill = base;
      text = typeless && isOption ? scheme.surface : Colors.white;
    } else {
      fill = base.withValues(alpha: dimmed ? 0.04 : 0.08);
      text = base.withValues(alpha: dimmed ? 0.55 : 1.0);
    }
    final borderRadius = BorderRadius.circular(radius * scale);

    Widget name = Text(
      label,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontSize: font * scale,
        color: text,
        fontWeight: FontWeight.bold,
      ),
    );
    if (width != null) {
      // Centred across the fixed width, but only as tall as the label:
      // a plain `alignment` would stretch the chip to the row's height.
      name = Align(
        heightFactor: 1.0,
        child: FittedBox(fit: BoxFit.scaleDown, child: name),
      );
    }

    Widget chip = Container(
      width: width,
      padding: EdgeInsets.symmetric(
        horizontal: (width != null ? _fixedWidthPadH : padH) * scale,
        vertical: padV * scale,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        // Picker options keep a constant border in both states.
        border: isOption
            ? Border.all(
                color: on
                    ? base
                    : base.withValues(alpha: dimmed ? 0.25 : 0.55),
                width: _borderWidth,
              )
            : null,
      ),
      // The ring is painted over the chip, inside its bounds.
      foregroundDecoration: ringColor == null
          ? null
          : BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: ringColor!, width: _borderWidth),
            ),
      child: name,
    );
    if (dimmed && on) chip = Opacity(opacity: 0.45, child: chip);
    if (dotColor != null) {
      chip = Stack(
        clipBehavior: Clip.none,
        children: [
          chip,
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 1.5),
              ),
            ),
          ),
        ],
      );
    }
    if (onTap == null) return chip;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: chip,
    );
  }
}
