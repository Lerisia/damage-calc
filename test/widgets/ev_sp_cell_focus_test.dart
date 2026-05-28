// Regression test for feedback_ev_input_focus_regression.md.
//
// History: the team builder's EV/SP input cell shipped a focus-loss
// bug THREE times. Every keystroke caused the field to be
// unmounted+remounted (because the wrapper interpolated the current
// value into a ValueKey), which on a real device dismissed the
// keyboard. This is invisible to non-widget tests — and the user
// has explicitly flagged this as a user-churn-level bug.
//
// This test pumps EvSpCell inside a parent that echoes the value
// back via setState (the exact pattern that triggered the prior
// regressions). If the FocusNode instance changes across a
// keystroke, the widget got remounted — fail loudly so the
// regression cannot ship again.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/views/widgets/ev_sp_cell.dart';

void main() {
  group('EvSpCell focus persistence (recurring user-churn bug)', () {
    testWidgets('FocusNode instance survives a value-echo rebuild',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: _Echo())));

      // Tap to focus the field.
      await tester.tap(find.byType(TextField));
      await tester.pump();

      final focusBefore = tester.binding.focusManager.primaryFocus;
      expect(focusBefore, isNotNull,
          reason: 'tapping the EV cell should grant it focus');

      // Type a digit. SelectAllField.onChanged → EvSpCell.onChanged →
      // parent setState → EvSpCell rebuilds with the new value.
      // With the value-in-key regression, the TextField underneath
      // gets unmounted and remounted with a fresh FocusNode, which
      // on a real device dismisses the keyboard.
      await tester.enterText(find.byType(TextField), '3');
      await tester.pump();

      final focusAfter = tester.binding.focusManager.primaryFocus;
      expect(focusAfter, isNotNull,
          reason:
              'EV/SP input must retain focus across keystrokes. '
              'See feedback_ev_input_focus_regression.md.');
      expect(focusAfter, same(focusBefore),
          reason:
              'FocusNode instance changed across a keystroke → the '
              'inner TextField was unmounted+remounted, which on a '
              'real device dismisses the keyboard. This is the exact '
              'regression the user has flagged as user-churn-level. '
              'Check EvSpCell.build for a key: that interpolates the '
              'current value (e.g. ValueKey("ev_\${label}_\${value}")) '
              '— keep it stable (label-only).');
    });

    testWidgets('Focus survives several consecutive keystrokes',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: _Echo())));

      await tester.tap(find.byType(TextField));
      await tester.pump();
      final originalFocus = tester.binding.focusManager.primaryFocus;
      expect(originalFocus, isNotNull);

      // Simulate the user typing "32" character by character. Any
      // single rebuild that remounts the field would break the same
      // instance assertion.
      for (final partial in ['3', '32']) {
        await tester.enterText(find.byType(TextField), partial);
        await tester.pump();
        expect(tester.binding.focusManager.primaryFocus, same(originalFocus),
            reason:
                'focus must persist through every keystroke (failed after '
                'entering "$partial"). The cell is remounting on value '
                'change — see feedback_ev_input_focus_regression.md.');
      }
    });

    testWidgets('External value change (sample load) syncs the display',
        (tester) async {
      // The complement to the focus-persistence rule: when the field
      // is NOT focused and the parent pushes a new value (e.g.
      // sample load), the displayed text should update to match.
      // Otherwise stale text would mislead the user about what got
      // loaded.
      final harness = _ExternalChangeHarness();
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: harness)));

      // Field starts empty (value = 0).
      expect(
          (tester.widget<TextField>(find.byType(TextField))).controller?.text,
          '0');

      // Parent updates value externally — no focus involved.
      harness.set(32);
      await tester.pump();

      expect(
          (tester.widget<TextField>(find.byType(TextField))).controller?.text,
          '32',
          reason:
              'When the field has no focus, the controller text must '
              'sync to widget.initialText so external mutations (sample '
              'load, species pick) actually show up. The focus-guard in '
              'SelectAllField.didUpdateWidget is what enables this — do '
              'not remove it without re-thinking the typing path.');
    });
  });
}

class _Echo extends StatefulWidget {
  const _Echo();

  @override
  State<_Echo> createState() => _EchoState();
}

class _EchoState extends State<_Echo> {
  int _v = 0;

  @override
  Widget build(BuildContext context) {
    return EvSpCell(
      label: 'HP',
      value: _v,
      max: 32,
      onChanged: (n) => setState(() => _v = n),
    );
  }
}

/// Programmatic-set harness for the external-change path. The test
/// drives [set] directly so we exercise "parent pushed a new value
/// without any keystroke" — exactly what a sample load does.
class _ExternalChangeHarness extends StatefulWidget {
  final _externalChangeHarnessState _state = _externalChangeHarnessState();

  _ExternalChangeHarness();

  void set(int v) => _state.set(v);

  @override
  State<_ExternalChangeHarness> createState() => _state;
}

class _externalChangeHarnessState extends State<_ExternalChangeHarness> {
  int _v = 0;

  void set(int v) => setState(() => _v = v);

  @override
  Widget build(BuildContext context) {
    return EvSpCell(
      label: 'HP',
      value: _v,
      max: 32,
      onChanged: (n) => setState(() => _v = n),
    );
  }
}
