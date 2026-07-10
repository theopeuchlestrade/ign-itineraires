import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/navigation_page.dart';
import 'package:latlong2/latlong.dart';

import 'support/fakes.dart';
import 'support/test_fixtures.dart';

void main() {
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
}
