import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/i18n/app_strings.dart';
import 'package:damage_calc/views/damage_calculator_screen.dart'
    show AppAboutDialog;

/// The design reviewer is credited as someone who works on the app:
/// a role line in the maker block, right under the developer and at
/// the same size — not in the small grey sprite-source credits at the
/// bottom — with the name linking to their channel.
void main() {
  const launcher = MethodChannel('plugins.flutter.io/url_launcher');
  late List<MethodCall> launches;

  setUp(() {
    launches = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, (call) async {
      launches.add(call);
      return true;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, null);
  });

  Future<void> pumpAbout(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AppAboutDialog()),
    ));
    await tester.pump();
  }

  double top(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;
  double? fontSize(WidgetTester tester, Finder f) =>
      tester.renderObject<RenderParagraph>(f).text.style?.fontSize;

  testWidgets('sits right under the developer, above the links and the sprite credits',
      (tester) async {
    await pumpAbout(tester);
    final by = find.text('By  Elyss');
    final role = find.text('Design review  ');
    final name = find.text('참혈');
    expect(role, findsOneWidget);
    expect(name, findsOneWidget);
    expect(top(tester, by), lessThan(top(tester, role)));
    expect(top(tester, role), lessThan(top(tester, find.text('Web  damage-calc.com'))));
    expect(top(tester, role),
        lessThan(top(tester, find.text(AppStrings.t('sprite.creditTitle')))));
    // The name is on the role's line, straight after it.
    expect(top(tester, name), closeTo(top(tester, role), 1.0));
    expect(tester.getTopLeft(name).dx,
        closeTo(tester.getTopRight(role).dx, 1.0));
  });

  testWidgets('is set at the developer line\'s size, not the source credits\' small print',
      (tester) async {
    await pumpAbout(tester);
    final bySize = fontSize(tester, find.text('By  Elyss'));
    expect(fontSize(tester, find.text('Design review  ')), bySize);
    expect(fontSize(tester, find.text('참혈')), bySize);
    expect(fontSize(tester, find.text(AppStrings.t('sprite.creditBody'))),
        lessThan(bySize!));
  });

  testWidgets('the name opens the reviewer\'s channel', (tester) async {
    await pumpAbout(tester);
    await tester.tap(find.text('참혈'));
    await tester.pump();
    expect(launches, hasLength(1));
    expect(launches.single.method, 'launch');
    expect((launches.single.arguments as Map)['url'],
        'https://www.youtube.com/channel/UCosEFmvzPgbzLWZhKYE4fkw');
  });
}
