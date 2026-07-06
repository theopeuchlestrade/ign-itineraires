@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/app.dart';

import 'support/fakes.dart';

void main() {
  final defaultComparator = goldenFileComparator;

  setUpAll(() async {
    goldenFileComparator = _TolerantGoldenComparator(
      Uri.file('${Directory.current.path}/test/app_responsive_test.dart'),
      tolerance: 0.01,
    );
    await (FontLoader('Marianne')..addFont(
          rootBundle.load('assets/fonts/Marianne-Regular.otf'),
        )..addFont(
          rootBundle.load('assets/fonts/Marianne-Medium.otf'),
        )..addFont(
          rootBundle.load('assets/fonts/Marianne-Bold.otf'),
        )..addFont(
          rootBundle.load('assets/fonts/Marianne-Light.otf'),
        ))
        .load();
    await (FontLoader('Manrope')..addFont(
          rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  tearDownAll(() {
    goldenFileComparator = defaultComparator;
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
}

class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(super.testFile, {required this._tolerance});

  final double _tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final passed = result.passed || result.diffPercent <= _tolerance;
    if (passed) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

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
