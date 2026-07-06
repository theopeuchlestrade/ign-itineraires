import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/navigation_page.dart';
import 'package:latlong2/latlong.dart';

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
}
