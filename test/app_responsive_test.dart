@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/app.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/navigation_page.dart';
import 'package:ign_itineraires/src/theme/app_theme.dart';

import 'support/fakes.dart';
import 'support/test_fixtures.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')..addFont(
          rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  final goldenCases = <_GoldenCase>[
    const _GoldenCase(
      name: 'planner_mobile_light',
      size: Size(390, 844),
      brightness: Brightness.light,
    ),
    const _GoldenCase(
      name: 'planner_tablet_light',
      size: Size(820, 1180),
      brightness: Brightness.light,
    ),
    const _GoldenCase(
      name: 'planner_desktop_dark',
      size: Size(1440, 900),
      brightness: Brightness.dark,
    ),
    const _GoldenCase(
      name: 'planner_mobile_large_text',
      size: Size(390, 844),
      brightness: Brightness.light,
      textScale: 2,
    ),
  ];

  for (final goldenCase in goldenCases) {
    testWidgets('${goldenCase.name} has no overflow and matches golden', (
      tester,
    ) async {
      final harness = TestAppHarness();
      await tester.binding.setSurfaceSize(goldenCase.size);
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          goldenCase.brightness;
      tester.binding.platformDispatcher.textScaleFactorTestValue =
          goldenCase.textScale;
      addTearDown(() async {
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.binding.setSurfaceSize(null);
        await harness.dispose();
      });

      await tester.pumpWidget(
        IgnItinerairesApp(dependencies: harness.dependencies),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('goldens/${goldenCase.name}.png'),
      );
    });
  }

  final navigationCases = <_GoldenCase>[
    const _GoldenCase(
      name: 'navigation_mobile_light',
      size: Size(390, 844),
      brightness: Brightness.light,
    ),
    const _GoldenCase(
      name: 'navigation_landscape_dark',
      size: Size(844, 390),
      brightness: Brightness.dark,
    ),
    const _GoldenCase(
      name: 'navigation_tablet_light',
      size: Size(1024, 768),
      brightness: Brightness.light,
    ),
    const _GoldenCase(
      name: 'navigation_mobile_large_text_dark',
      size: Size(390, 844),
      brightness: Brightness.dark,
      textScale: 2,
    ),
  ];

  for (final goldenCase in navigationCases) {
    testWidgets('${goldenCase.name} has no overflow and matches golden', (
      tester,
    ) async {
      final harness = TestAppHarness();
      await tester.binding.setSurfaceSize(goldenCase.size);
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          goldenCase.brightness;
      tester.binding.platformDispatcher.textScaleFactorTestValue =
          goldenCase.textScale;
      addTearDown(() async {
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.binding.setSurfaceSize(null);
        await harness.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: goldenCase.brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          home: NavigationPage(
            destination: parisDestination,
            mode: TravelMode.car,
            dependencies: harness.dependencies,
            now: () => DateTime(2026, 1, 1, 14, 2),
          ),
        ),
      );
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/${goldenCase.name}.png'),
      );
    });
  }

  testWidgets('keyboard focus can move between address fields', (tester) async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(
      IgnItinerairesApp(dependencies: harness.dependencies),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(EditableText).first);
    var destinationFocused = false;
    for (var attempt = 0; attempt < 5 && !destinationFocused; attempt++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      destinationFocused = tester
          .widget<EditableText>(find.byType(EditableText).at(1))
          .focusNode
          .hasFocus;
    }

    expect(destinationFocused, isTrue);
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('addresses remain selectable on a small screen with keyboard', (
    tester,
  ) async {
    final harness = TestAppHarness();
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() async {
      tester.view.resetViewInsets();
      await tester.binding.setSurfaceSize(null);
      await harness.dispose();
    });
    await tester.pumpWidget(
      IgnItinerairesApp(dependencies: harness.dependencies),
    );
    await tester.pumpAndSettle();

    await _selectAddressWithKeyboard(
      tester,
      fieldLabel: 'Départ',
      query: 'Hôtel',
      expectedLabel: parisStart.label,
    );
    await _selectAddressWithKeyboard(
      tester,
      fieldLabel: 'Arrivée',
      query: 'Bastille',
      expectedLabel: parisDestination.label,
    );

    final plannerScroll = _plannerScroll();
    final calculateButton = find.widgetWithText(
      FilledButton,
      'Calculer l’itinéraire',
    );
    await tester.scrollUntilVisible(
      calculateButton,
      120,
      scrollable: plannerScroll,
    );
    expect(tester.widget<FilledButton>(calculateButton).onPressed, isNotNull);
  });
}

Finder _addressField(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _selectAddressWithKeyboard(
  WidgetTester tester, {
  required String fieldLabel,
  required String query,
  required String expectedLabel,
}) async {
  final plannerScroll = _plannerScroll();
  final field = _addressField(fieldLabel);
  await tester.scrollUntilVisible(field, 120, scrollable: plannerScroll);

  tester.view.viewInsets = const FakeViewPadding(bottom: 280);
  await tester.pump();
  await tester.enterText(field, query);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();

  final suggestion = find.widgetWithText(ListTile, expectedLabel);
  expect(suggestion, findsOneWidget);

  tester.view.viewInsets = FakeViewPadding.zero;
  await tester.pumpAndSettle();
  await tester.ensureVisible(suggestion);
  await tester.tap(suggestion);
  await tester.pumpAndSettle();
}

Finder _plannerScroll() => find
    .descendant(
      of: find.byType(ListView).first,
      matching: find.byType(Scrollable),
    )
    .first;

class _GoldenCase {
  const _GoldenCase({
    required this.name,
    required this.size,
    required this.brightness,
    this.textScale = 1,
  });

  final String name;
  final Size size;
  final Brightness brightness;
  final double textScale;
}
