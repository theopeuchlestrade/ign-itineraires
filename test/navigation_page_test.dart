import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/data/geoplateforme_api.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/navigation_page.dart';
import 'package:latlong2/latlong.dart';

import 'support/fakes.dart';
import 'support/test_fixtures.dart';

void main() {
  test('keeps the vehicle upright while following the user', () {
    expect(
      navigationMarkerRotationDegrees(
        followingUser: true,
        headingDegrees: 270,
        mapRotationDegrees: 90,
      ),
      0,
    );
    expect(
      navigationMarkerRotationDegrees(
        followingUser: false,
        headingDegrees: 270,
        mapRotationDegrees: 90,
      ),
      180,
    );
  });

  test('updates the followed camera when only heading changes', () {
    final previous = _navigationSession(headingDegrees: 10);
    final current = _navigationSession(headingDegrees: 45);

    expect(shouldUpdateNavigationCamera(previous, current), isTrue);
    expect(
      shouldUpdateNavigationCamera(
        current,
        current.copyWith(followingUser: false),
      ),
      isFalse,
    );
  });

  test('uses maneuver-specific navigation icons', () {
    const roundabout = RouteStep(
      type: 'roundabout',
      modifier: 'right',
      roadName: '',
      distanceMeters: 20,
      points: [],
      exitNumber: 2,
    );
    const slightLeft = RouteStep(
      type: 'turn',
      modifier: 'slight left',
      roadName: '',
      distanceMeters: 20,
      points: [],
    );

    expect(
      navigationInstructionIcon(roundabout),
      Icons.roundabout_right_rounded,
    );
    expect(
      navigationInstructionIcon(slightLeft),
      Icons.turn_slight_left_rounded,
    );
  });

  testWidgets('renders the live map before MapController is ready', (
    tester,
  ) async {
    final position = NavigationPosition(
      point: const LatLng(48.85, 2.35),
      accuracyMeters: 5,
      headingDegrees: 90,
      speedMetersPerSecond: 4,
      timestamp: DateTime(2026),
    );
    final session = NavigationSession(
      status: NavigationStatus.active,
      destination: const Place(
        label: 'Destination',
        latitude: 48.851,
        longitude: 2.36,
      ),
      mode: TravelMode.car,
      voiceEnabled: true,
      route: const RoutePlan(
        points: [LatLng(48.85, 2.35), LatLng(48.851, 2.36)],
        distanceMeters: 800,
        durationSeconds: 300,
        steps: [],
        resourceVersion: 'test',
      ),
      position: position,
      snappedPosition: position.point,
      remainingDistanceMeters: 800,
      remainingDurationSeconds: 300,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: buildLiveNavigationMapForTest(session),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a message when external guidance fails', (tester) async {
    final harness = TestAppHarness()..externalNavigation.launchResult = false;

    await tester.pumpWidget(
      MaterialApp(
        home: NavigationPage(
          destination: parisDestination,
          mode: TravelMode.car,
          dependencies: harness.dependencies,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Ouvrir dans une autre application'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google Maps'));
    await tester.pumpAndSettle();

    expect(harness.externalNavigation.launchCalls, 1);
    expect(find.text('Impossible d’ouvrir le guidage.'), findsOneWidget);

    await harness.dispose();
  });

  testWidgets('offers an actionable retry after a speech error', (
    tester,
  ) async {
    final harness = TestAppHarness();

    await tester.pumpWidget(
      MaterialApp(
        home: NavigationPage(
          destination: parisDestination,
          mode: TravelMode.car,
          dependencies: harness.dependencies,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    harness.speech.errorHandler?.call('not-allowed');
    await tester.pump();

    expect(find.text('Réessayer la voix'), findsOneWidget);
    final beforeRetry = harness.speech.messages.length;
    await tester.tap(find.text('Réessayer la voix'));
    await tester.pump();

    expect(harness.speech.messages, hasLength(beforeRetry + 1));
    await harness.dispose();
  });

  testWidgets('retries navigation after a route service failure', (
    tester,
  ) async {
    final harness = TestAppHarness()
      ..api.routeError = const GeoplateformeException(
        'Connexion impossible',
        kind: GeoplateformeFailureKind.offline,
      );
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: NavigationPage(
          destination: parisDestination,
          mode: TravelMode.car,
          dependencies: harness.dependencies,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Guidage indisponible'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);

    harness.api.routeError = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Guidage indisponible'), findsNothing);
    expect(find.text('500 m'), findsOneWidget);
    expect(harness.api.routeCalls, 2);
  });

  testWidgets('keeps guidance at the top and trip metrics at the bottom', (
    tester,
  ) async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
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

    final instructionCard = find.ancestor(
      of: find.text('500 m'),
      matching: find.byType(Card),
    );
    final metricsCard = find.ancestor(
      of: find.text('Arrivée'),
      matching: find.byType(Card),
    );

    expect(tester.getTopLeft(instructionCard).dy, lessThan(80));
    expect(
      tester.getBottomRight(metricsCard).dy,
      moreOrLessEquals(832, epsilon: 1),
    );
  });
}

NavigationSession _navigationSession({required double headingDegrees}) {
  final position = NavigationPosition(
    point: const LatLng(48.85, 2.35),
    accuracyMeters: 5,
    headingDegrees: headingDegrees,
    speedMetersPerSecond: 4,
    timestamp: DateTime(2026),
  );
  return NavigationSession(
    status: NavigationStatus.active,
    destination: parisDestination,
    mode: TravelMode.car,
    voiceEnabled: true,
    route: urbanRoute,
    position: position,
    snappedPosition: position.point,
    displayHeadingDegrees: headingDegrees,
  );
}
