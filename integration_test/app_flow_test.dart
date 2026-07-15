import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ign_itineraires/src/app.dart';
import 'package:ign_itineraires/src/features/routing/data/device_location_service.dart';
import 'package:ign_itineraires/src/features/routing/data/geoplateforme_api.dart';

import 'support/fakes.dart';
import 'support/test_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('complete route planning and persistence flow', (tester) async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(
      IgnItinerairesApp(dependencies: harness.dependencies),
    );
    await _pumpUi(tester);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
    }

    await _selectAddress(
      tester,
      fieldLabel: 'Départ',
      query: 'Hôtel',
      expectedLabel: parisStart.label,
    );
    await _selectAddress(
      tester,
      fieldLabel: 'Arrivée',
      query: 'Bastille',
      expectedLabel: parisDestination.label,
    );
    await tester.tap(find.text('À pied'));
    await tester.tap(find.text('Calculer l’itinéraire'));
    await _pumpUi(tester);

    expect(find.text('10 min · 1.0 km'), findsOneWidget);
    expect(find.textContaining('Feuille de route'), findsOneWidget);
    if (!kIsWeb) {
      await binding.takeScreenshot('planned-route');
    }

    await tester.tap(find.byTooltip('Ajouter aux favoris'));
    await tester.pump();
    expect(harness.store.favorites, [parisDestination]);

    await tester.tap(find.byTooltip('Trajets récents'));
    await _pumpUi(tester);
    await tester.tap(find.byType(Switch));
    await _pumpUi(tester);
    await tester.tap(find.byType(ModalBarrier).last);
    await _pumpUi(tester);
    await tester.tap(find.text('Calculer l’itinéraire'));
    await _pumpUi(tester);
    expect(harness.store.recents, hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpUi(tester);
    await tester.pumpWidget(
      IgnItinerairesApp(dependencies: harness.dependencies),
    );
    await _pumpUi(tester);
    await tester.tap(find.byTooltip('Favoris'));
    await _pumpUi(tester);
    expect(find.text(parisDestination.label), findsOneWidget);
    await tester.tap(find.byType(ModalBarrier).last);
    await _pumpUi(tester);
    await tester.tap(find.byTooltip('Trajets récents'));
    await _pumpUi(tester);
    await tester.tap(find.text(parisDestination.label));
    await _pumpUi(tester);
    await tester.tap(find.text('Calculer l’itinéraire'));
    await _pumpUi(tester);

    expect(find.text('10 min · 1.0 km'), findsOneWidget);
  });

  testWidgets('navigation progresses, reroutes and arrives', (tester) async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(
      IgnItinerairesApp(dependencies: harness.dependencies),
    );
    await _pumpUi(tester);

    await _selectAddress(
      tester,
      fieldLabel: 'Départ',
      query: 'Hôtel',
      expectedLabel: parisStart.label,
    );
    await _selectAddress(
      tester,
      fieldLabel: 'Arrivée',
      query: 'Bastille',
      expectedLabel: parisDestination.label,
    );
    await tester.tap(find.text('À pied'));
    await tester.tap(find.text('Calculer l’itinéraire'));
    await _pumpUi(tester);

    harness.location.current = navigationPosition(
      parisStart.latitude,
      parisStart.longitude,
    );
    await tester.tap(find.text('Démarrer le guidage'));
    await _pumpUi(tester);
    expect(find.text('Guidage à pied'), findsOneWidget);
    expect(harness.speech.initializeCalls, kIsWeb ? 1 : 0);
    expect(harness.wakeLock.enabled, isTrue);
    expect(harness.speech.messages, isNotEmpty);

    expect(find.byType(FlutterMap), findsOneWidget);
    if (kIsWeb) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpUi(tester);
      return;
    }

    _pressIconButton(tester, 'Couper les instructions vocales');
    await tester.pump();
    expect(harness.store.voiceEnabled, isFalse);
    _pressIconButton(tester, 'Activer les instructions vocales');
    await tester.pump();

    _pressIconButton(tester, 'Ouvrir dans une autre application');
    await _pumpUi(tester);
    await tester.tap(find.text('Google Maps'));
    await _pumpUi(tester);
    expect(harness.externalNavigation.launchCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _pumpUi(tester);
    expect(harness.wakeLock.enabled, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpUi(tester);
    expect(harness.wakeLock.enabled, isTrue);

    final offRouteNow = DateTime.now();
    for (var index = 0; index < 3; index++) {
      harness.location.emit(
        navigationPosition(
          48.8580,
          2.3571,
          timestamp: offRouteNow.subtract(Duration(seconds: 4 - index * 2)),
        ),
      );
      await tester.pump();
    }
    await _pumpUi(tester);
    expect(harness.api.routeCalls, greaterThanOrEqualTo(3));

    harness.location.emit(
      navigationPosition(parisDestination.latitude, parisDestination.longitude),
    );
    await tester.pump();
    harness.location.emit(
      navigationPosition(parisDestination.latitude, parisDestination.longitude),
    );
    await _pumpUi(tester);
    expect(find.text('Vous êtes arrivé'), findsOneWidget);
    expect(harness.wakeLock.enabled, isFalse);
    if (!kIsWeb) {
      await binding.takeScreenshot('navigation-arrival');
    }

    await tester.tap(find.text('Terminer'));
    await _pumpUi(tester);
    expect(find.text('Préparer le trajet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpUi(tester);
  });

  testWidgets('GPS denial keeps manual route planning available', (
    tester,
  ) async {
    final location = FakeDeviceLocation()
      ..error = const DeviceLocationException('Localisation refusée');
    final harness = TestAppHarness(location: location);
    addTearDown(harness.dispose);
    await tester.pumpWidget(
      IgnItinerairesApp(dependencies: harness.dependencies),
    );
    await _pumpUi(tester);

    await _selectAddress(
      tester,
      fieldLabel: 'Départ',
      query: 'Hôtel',
      expectedLabel: parisStart.label,
    );
    await _selectAddress(
      tester,
      fieldLabel: 'Arrivée',
      query: 'Bastille',
      expectedLabel: parisDestination.label,
    );
    await tester.tap(find.text('Calculer l’itinéraire'));
    await _pumpUi(tester);

    expect(find.text('10 min · 1.0 km'), findsOneWidget);

    await tester.tap(find.text('Démarrer le guidage'));
    await _pumpUi(tester);
    expect(find.text('Localisation refusée'), findsOneWidget);
  });

  testWidgets('route service errors are explained without losing selections', (
    tester,
  ) async {
    final api = FakeGeoplateforme()
      ..routeError = const GeoplateformeException(
        'Trop de demandes. Réessayez dans quelques secondes.',
        retryAfter: Duration(seconds: 5),
      );
    final harness = TestAppHarness(api: api);
    addTearDown(harness.dispose);
    await tester.pumpWidget(
      IgnItinerairesApp(dependencies: harness.dependencies),
    );
    await _pumpUi(tester);

    await _selectAddress(
      tester,
      fieldLabel: 'Départ',
      query: 'Hôtel',
      expectedLabel: parisStart.label,
    );
    await _selectAddress(
      tester,
      fieldLabel: 'Arrivée',
      query: 'Bastille',
      expectedLabel: parisDestination.label,
    );
    await tester.tap(find.text('Calculer l’itinéraire'));
    await _pumpUi(tester);

    expect(find.textContaining('Trop de demandes'), findsOneWidget);
    expect(find.text(parisStart.label), findsOneWidget);
    expect(find.text(parisDestination.label), findsOneWidget);

    api.routeError = const GeoplateformeException(
      'Connexion impossible. Vérifiez votre accès à Internet.',
    );
    await tester.tap(find.text('Calculer l’itinéraire'));
    await _pumpUi(tester);
    expect(find.textContaining('Connexion impossible'), findsOneWidget);
  });
}

Future<void> _selectAddress(
  WidgetTester tester, {
  required String fieldLabel,
  required String query,
  required String expectedLabel,
}) async {
  final field = find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.labelText == fieldLabel,
  );
  final plannerScroll = find
      .descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(field, 120, scrollable: plannerScroll);
  await tester.enterText(field, query);
  final suggestion = find.widgetWithText(ListTile, expectedLabel);
  for (
    var attempt = 0;
    attempt < 10 && suggestion.evaluate().isEmpty;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(suggestion, findsWidgets);

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.ensureVisible(suggestion.last);
  await tester.pump();
  await tester.tap(suggestion.last);
  await _pumpUi(tester);
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void _pressIconButton(WidgetTester tester, String tooltip) {
  tester
      .widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        ),
      )
      .onPressed!();
}
