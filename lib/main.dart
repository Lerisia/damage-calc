import 'package:flutter/material.dart';
import 'utils/app_strings.dart';
import 'utils/doubles_controller.dart';
import 'utils/theme_controller.dart';
import 'data/abilitydex.dart';
import 'data/itemdex.dart';
import 'models/ability.dart';
import 'models/item.dart';
import 'data/movedex.dart';
import 'data/pokedex.dart';
import 'views/damage_calculator_screen.dart';

void main() {
  runApp(const DamageCalcApp());
}

// Pretendard covers Korean + Latin. MPLUSRounded1c handles Japanese glyphs
// (hiragana/katakana/JP kanji) that Pretendard lacks. NotoSansKR catches any
// remaining Korean glyphs. System sans-serif is the final fallback.
const _fontFallback = ['MPLUSRounded1c', 'NotoSansKR', 'sans-serif'];

// Neutral palette — Linear/Raycast style. Data-tool aesthetic: tight borders,
// flat surfaces, grayscale dominant. Red/blue only surface in attacker /
// defender panels as thin accent strokes, not background tints.
class AppColors {
  AppColors._();
  // Zinc scale (shadcn defaults) — tuned for utility tool density.
  static const zinc50 = Color(0xFFFAFAFA);
  static const zinc100 = Color(0xFFF4F4F5);
  static const zinc200 = Color(0xFFE4E4E7);
  static const zinc300 = Color(0xFFD4D4D8);
  static const zinc400 = Color(0xFFA1A1AA);
  static const zinc500 = Color(0xFF71717A);
  static const zinc600 = Color(0xFF52525B);
  static const zinc700 = Color(0xFF3F3F46);
  static const zinc800 = Color(0xFF27272A);
  static const zinc900 = Color(0xFF18181B);
  static const zinc950 = Color(0xFF09090B);
  // Domain accents — attacker red / defender blue (Tailwind 500 / 400).
  static const attackerLight = Color(0xFFEF4444);
  static const attackerDark = Color(0xFFF87171);
  static const defenderLight = Color(0xFF3B82F6);
  static const defenderDark = Color(0xFF60A5FA);
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final bg = isDark ? AppColors.zinc950 : AppColors.zinc50;
  final surface = isDark ? AppColors.zinc900 : Colors.white;
  final border = isDark ? AppColors.zinc800 : AppColors.zinc200;
  final textPrimary = isDark ? AppColors.zinc50 : AppColors.zinc900;
  final textSecondary = isDark ? AppColors.zinc400 : AppColors.zinc600;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: textPrimary,
    onPrimary: surface,
    secondary: textSecondary,
    onSecondary: surface,
    error: isDark ? AppColors.attackerDark : AppColors.attackerLight,
    onError: Colors.white,
    surface: surface,
    onSurface: textPrimary,
    surfaceContainerHighest: isDark ? AppColors.zinc800 : AppColors.zinc100,
    outline: border,
    outlineVariant: isDark ? AppColors.zinc700 : AppColors.zinc300,
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    useMaterial3: true,
    fontFamily: 'Pretendard',
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    dividerColor: border,
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border, width: 1),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: Border(bottom: BorderSide(color: border, width: 1)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      // No fill, no rectangle. A single hairline underneath at rest, bumping
      // to a stronger primary-colored line on focus. Subtle but signals
      // "editable" without a gray box.
      filled: false,
      isDense: true,
      border: UnderlineInputBorder(
        borderSide: BorderSide(
          color: isDark ? AppColors.zinc500 : AppColors.zinc400,
          width: 1,
        ),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: isDark ? AppColors.zinc500 : AppColors.zinc400,
          width: 1,
        ),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: textPrimary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      labelStyle: TextStyle(color: textSecondary, fontSize: 12),
      floatingLabelStyle: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
      hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    chipTheme: ChipThemeData(
      backgroundColor: isDark ? AppColors.zinc800 : AppColors.zinc100,
      labelStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: textPrimary,
      unselectedLabelColor: textSecondary,
      indicatorColor: textPrimary,
      dividerColor: border,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    textTheme: const TextTheme().apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    ),
  );
  // Medium (500) is the default body weight — Regular feels too thin on
  // Windows Chrome / Android renderings. SemiBold (600) for titles/labels.
  final base2 = base.textTheme.apply(
    fontFamilyFallback: _fontFallback,
    bodyColor: textPrimary,
    displayColor: textPrimary,
  );
  final tt = base2.copyWith(
    bodyLarge: base2.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
    bodyMedium: base2.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
    bodySmall: base2.bodySmall?.copyWith(fontWeight: FontWeight.w500),
    labelLarge: base2.labelLarge?.copyWith(fontWeight: FontWeight.w500),
    labelMedium: base2.labelMedium?.copyWith(fontWeight: FontWeight.w500),
    labelSmall: base2.labelSmall?.copyWith(fontWeight: FontWeight.w500),
    titleLarge: base2.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    titleMedium: base2.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: base2.titleSmall?.copyWith(fontWeight: FontWeight.w600),
  );
  return base.copyWith(textTheme: tt);
}

class DamageCalcApp extends StatelessWidget {
  const DamageCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (context, themeMode, _) => MaterialApp(
        title: '결정력 계산기',
        builder: (context, child) {
          final mediaChild = MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.1),
            ),
            child: child!,
          );
          // Wrap with DefaultTextStyle to guarantee fontFamilyFallback
          // reaches every widget, including TextField composing text.
          final defaultStyle = DefaultTextStyle.of(context).style;
          return DefaultTextStyle(
            style: defaultStyle.copyWith(
              fontFamily: 'Pretendard',
              fontFamilyFallback: _fontFallback,
            ),
            child: mediaChild,
          );
        },
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: themeMode,
        home: const _AppLoader(),
      ),
    );
  }
}

class _AppLoader extends StatefulWidget {
  const _AppLoader();

  @override
  State<_AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<_AppLoader> {
  bool _ready = false;
  Map<String, String> _abilityNameMap = {};
  Map<String, String> _itemNameMap = {};

  @override
  void initState() {
    super.initState();
    _preload();
  }

  Future<void> _preload() async {
    await Future.wait([
      AppStrings.loadSavedLanguage(),
      ThemeController.instance.load(),
      DoublesController.instance.load(),
    ]);
    final results = await Future.wait([
      loadPokedex(),
      loadAllMoves(),
      loadAbilitydex(),
      loadItemdex(),
    ]);

    // Build name maps from loaded data
    final abilities = results[2] as Map<String, Ability>;
    final aMap = <String, String>{};
    for (final e in abilities.values) {
      // Skip dummy abilities (nameKo has no Korean characters)
      if (!e.nameKo.runes.any((c) => c >= 0xAC00 && c <= 0xD7A3)) continue;
      aMap[e.name] = e.localizedName;
    }

    final items = results[3] as Map<String, Item>;
    final iMap = <String, String>{};
    for (final e in items.values) {
      if (e.battle) {
        iMap[e.name] = e.localizedName;
      }
    }

    if (mounted) {
      setState(() {
        _abilityNameMap = aMap;
        _itemNameMap = iMap;
        _ready = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return DamageCalculatorScreen(
        abilityNameMap: _abilityNameMap,
        itemNameMap: _itemNameMap,
      );
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading...',
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
