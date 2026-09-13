import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/views/widgets/typeahead_helpers.dart';

/// `idleText`: the helper owns "show the current pick while idle".
///
/// Hosts used to write the pick's label into the controller from their
/// own build() whenever the field's FocusNode had no focus. ↓ moves
/// focus into the suggestions list, so the next parent rebuild wiped
/// the query and re-ran the search — item and ability pickers could
/// not be navigated by keyboard while the species picker (no such
/// write) could. The helper now takes the label and applies it only
/// while no search session is open.
void main() {
  Future<void> pump(WidgetTester t, [int times = 1]) async {
    for (var i = 0; i < times; i++) {
      await t.pump();
      final e = t.takeException();
      if (e != null) {
        expect('$e', anyOf(contains('RenderAnimatedSize'), startsWith('Multiple exceptions')));
      }
    }
  }

  Future<void> key(WidgetTester t, LogicalKeyboardKey k) async {
    await t.sendKeyDownEvent(k);
    await t.sendKeyUpEvent(k);
    await pump(t, 2);
  }

  late TextEditingController ctl;
  late List<String> picked;

  setUp(() {
    ctl = TextEditingController();
    picked = [];
  });

  Future<void> typeQuery(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: _Host(ctl, picked))));
    expect(ctl.text, 'banana', reason: 'idleText is applied on mount');
    await tester.tap(find.byType(TextField));
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'ap');
    await pump(tester);
    expect(find.text('apple'), findsOneWidget);
  }

  testWidgets('a parent rebuild while the list has focus keeps the query',
      (tester) async {
    await typeQuery(tester);
    await key(tester, LogicalKeyboardKey.arrowDown);
    _Host.rebuild!();
    await pump(tester, 2);
    expect(ctl.text, 'ap');
    expect(find.text('apple'), findsOneWidget);
    await key(tester, LogicalKeyboardKey.enter);
    expect(picked, ['apple']);
  });

  testWidgets('a parent rebuild while typing keeps the query', (tester) async {
    await typeQuery(tester);
    _Host.rebuild!();
    await pump(tester, 2);
    expect(ctl.text, 'ap');
  });

  testWidgets('an idleText change while idle updates the field', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: _Host(ctl, picked))));
    expect(ctl.text, 'banana');
    _Host.setPick!('apricot');
    await pump(tester);
    expect(ctl.text, 'apricot');
  });

  testWidgets('leaving without a pick restores idleText', (tester) async {
    await typeQuery(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await pump(tester, 2);
    expect(ctl.text, 'banana');
    expect(picked, isEmpty);
  });
}

class _Host extends StatefulWidget {
  final TextEditingController ctl;
  final List<String> picked;
  const _Host(this.ctl, this.picked);
  static VoidCallback? rebuild;
  static ValueChanged<String>? setPick;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String _pick = 'banana';

  @override
  void initState() {
    super.initState();
    _Host.rebuild = () => setState(() {});
    _Host.setPick = (v) => setState(() => _pick = v);
  }

  @override
  Widget build(BuildContext context) {
    return buildTypeAhead<String>(
      controller: widget.ctl,
      idleText: _pick,
      suggestionsCallback: (q) =>
          ['apple', 'apricot', 'banana'].where((s) => s.startsWith(q)).toList(),
      itemBuilder: (_, s) => Padding(padding: const EdgeInsets.all(8), child: Text(s)),
      onSelected: (s) {
        widget.picked.add(s);
        setState(() => _pick = s);
        FocusManager.instance.primaryFocus?.unfocus();
      },
      decoration: const InputDecoration(),
    );
  }
}
