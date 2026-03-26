import 'package:flutter/material.dart';
import 'utils/app_strings.dart';
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

const _fontFallback = ['MPLUSRounded1c', 'NotoSansKR', 'sans-serif'];

ThemeData _buildTheme(Brightness brightness) {
  final base = ThemeData(
    colorSchemeSeed: Colors.red,
    brightness: brightness,
    useMaterial3: true,
    fontFamily: 'Jua',
  );
  // Apply fontFamilyFallback to all text styles so missing Jua glyphs
  // (e.g. rare syllables during Korean IME composition) fall back to
  // NotoSansKR instead of showing □.
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamilyFallback: _fontFallback),
  );
}

class DamageCalcApp extends StatelessWidget {
  const DamageCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
            fontFamily: 'Jua',
            fontFamilyFallback: _fontFallback,
          ),
          child: mediaChild,
        );
      },
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const _AppLoader(),
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
    await AppStrings.loadSavedLanguage();
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
