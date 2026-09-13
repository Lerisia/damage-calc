part of '../simple_mode_screen.dart';

/// Slider track shape that paints the standard rounded active/
/// inactive tracks first, then overlays the defender damage-range
/// bands on top of the active track.
///
/// Two-tone overlay anchored to [thumbCenter] (the slider's
/// interpolated thumb position — NOT the snapped value) so the red
/// stays glued to the thumb during drags, no matter how the slider
/// interpolates between division snap points:
///   - dark red, width = minDmgFraction × trackWidth, ending at
///     thumbCenter — the defender loses AT LEAST this much in the
///     worst roll for them (smallest damage roll).
///   - light red, width = (maxDmg − minDmg)/sliderMax × trackWidth,
///     ending where the dark band starts — uncertain zone that may
///     or may not be lost depending on the roll.
///
/// Both bands clamp at the track's left edge so very large damages
/// (certain KO) collapse into a single dark band covering the full
/// active region. The slider's thumb paints AFTER this track paint
/// pass, so it visually sits on top of the overlay — user direction
/// was to keep the thumb visually unobstructed.
class _DamageRangeTrackShape extends RoundedRectSliderTrackShape {
  final double minDmgFraction;
  final double maxDmgFraction;

  const _DamageRangeTrackShape({
    required this.minDmgFraction,
    required this.maxDmgFraction,
  });

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
    required TextDirection textDirection,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
      textDirection: textDirection,
    );

    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final maxDmgPx = maxDmgFraction * trackRect.width;
    final minDmgPx = minDmgFraction * trackRect.width;

    final darkLeft = math.max(trackRect.left, thumbCenter.dx - minDmgPx);
    final darkRight = math.max(trackRect.left, thumbCenter.dx);
    if (darkRight > darkLeft) {
      context.canvas.drawRect(
        Rect.fromLTRB(darkLeft, trackRect.top, darkRight, trackRect.bottom),
        Paint()..color = const Color(0xFFC62828),
      );
    }

    final lightRight = darkLeft;
    final lightLeft = math.max(trackRect.left, thumbCenter.dx - maxDmgPx);
    if (lightRight > lightLeft) {
      context.canvas.drawRect(
        Rect.fromLTRB(lightLeft, trackRect.top, lightRight, trackRect.bottom),
        Paint()..color = const Color(0xFFEF9A9A),
      );
    }
  }
}
