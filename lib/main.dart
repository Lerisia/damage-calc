import 'package:flutter/material.dart';
import 'data/abilitydex.dart';
import 'data/itemdex.dart';
import 'data/movedex.dart';
import 'data/pokedex.dart';
import 'views/damage_calculator_screen.dart';

void main() {
  runApp(const DamageCalcApp());
}

class DamageCalcApp extends StatelessWidget {
  const DamageCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Damage Calculator',
      theme: ThemeData(
        colorSchemeSeed: Colors.red,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.red,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
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

  @override
  void initState() {
    super.initState();
    _preload();
  }

  Future<void> _preload() async {
    await Future.wait([
      loadPokedex(),
      loadAllMoves(),
      loadAbilitydex(),
      loadItemdex(),
    ]);
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const DamageCalculatorScreen();

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('로딩 중...',
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
