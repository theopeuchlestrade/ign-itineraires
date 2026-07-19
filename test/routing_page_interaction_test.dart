import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/app.dart';
import 'package:ign_itineraires/src/features/routing/data/geoplateforme_api.dart';

import 'support/fakes.dart';
import 'support/test_fixtures.dart';

void main() {
  testWidgets('swaps departure and destination from the planner', (
    tester,
  ) async {
    final harness = TestAppHarness();
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      await harness.dispose();
    });
    await tester.pumpWidget(
      IgnItinerairesApp(dependencies: harness.dependencies),
    );
    await tester.pump();

    await _selectAddress(tester, 'Départ', 'Hôtel', parisStart.label);
    await _selectAddress(tester, 'Arrivée', 'Bastille', parisDestination.label);

    await tester.tap(find.byTooltip('Inverser le départ et l’arrivée'));
    await tester.pump();

    expect(_fieldText(tester, 'Départ'), parisDestination.label);
    expect(_fieldText(tester, 'Arrivée'), parisStart.label);
    await tester.pump(const Duration(milliseconds: 180));
  });

  testWidgets('shows the quota countdown and retries the route', (
    tester,
  ) async {
    final api = FakeGeoplateforme()
      ..routeError = const GeoplateformeException(
        'Trop de demandes. Réessayez dans quelques secondes.',
        kind: GeoplateformeFailureKind.rateLimited,
        retryAfter: Duration(seconds: 2),
      );
    final harness = TestAppHarness(api: api);
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      await harness.dispose();
    });
    await tester.pumpWidget(
      IgnItinerairesApp(dependencies: harness.dependencies),
    );
    await tester.pump();

    await _selectAddress(tester, 'Départ', 'Hôtel', parisStart.label);
    await _selectAddress(tester, 'Arrivée', 'Bastille', parisDestination.label);
    await tester.tap(find.text('Calculer l’itinéraire'));
    await tester.pump();

    expect(find.text('Réessayer dans 2 s'), findsOneWidget);
    api.routeError = null;
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Réessayer'));
    await tester.pump();

    expect(find.text('10 min · 1.0 km'), findsOneWidget);
    expect(api.routeCalls, 2);
  });
}

Future<void> _selectAddress(
  WidgetTester tester,
  String label,
  String query,
  String expected,
) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  await tester.enterText(field, query);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  final suggestion = find.widgetWithText(ListTile, expected).last;
  await tester.ensureVisible(suggestion);
  await tester.pump();
  await tester.tap(suggestion);
  await tester.pump();
}

String _fieldText(WidgetTester tester, String label) {
  final field = tester.widget<TextField>(
    find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    ),
  );
  return field.controller!.text;
}
