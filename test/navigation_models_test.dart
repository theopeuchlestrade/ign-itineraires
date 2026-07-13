import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';

import 'support/test_fixtures.dart';

void main() {
  test('formats remaining navigation metrics', () {
    final session = NavigationSession(
      status: NavigationStatus.active,
      destination: parisDestination,
      mode: TravelMode.car,
      voiceEnabled: true,
      route: urbanRoute,
      position: routeStartPosition,
      remainingDistanceMeters: 1250,
      remainingDurationSeconds: 3900,
      distanceToManeuverMeters: 80,
    );

    expect(session.formattedDistanceToManeuver, '80 m');
    expect(session.formattedRemainingDistance, '1.3 km');
    expect(session.formattedRemainingDuration, '1 h 5');
    expect(session.upcomingStep?.roadName, 'RUE DE RIVOLI');
  });

  test('copyWith changes explicit nullable and navigation values', () {
    final initial = NavigationSession(
      status: NavigationStatus.active,
      destination: parisDestination,
      mode: TravelMode.pedestrian,
      voiceEnabled: true,
      message: 'ancien',
    );

    final updated = initial.copyWith(
      status: NavigationStatus.paused,
      voiceEnabled: false,
      followingUser: false,
      speechRetryAvailable: true,
      message: null,
    );

    expect(updated.status, NavigationStatus.paused);
    expect(updated.voiceEnabled, isFalse);
    expect(updated.followingUser, isFalse);
    expect(updated.speechRetryAvailable, isTrue);
    expect(updated.message, isNull);
  });

  test('navigation position converts to an anonymous current place', () {
    final place = routeStartPosition.asPlace;

    expect(place.label, 'Ma position');
    expect(place.latitude, parisStart.latitude);
    expect(place.longitude, parisStart.longitude);
  });
}
