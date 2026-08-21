import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_policies.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('RouteDeviationPolicy', () {
    test('confirms a sustained off-route deviation before rerouting', () {
      final policy = RouteDeviationPolicy(TravelMode.car);
      final start = DateTime.utc(2026);

      policy.update(
        update: _guidance(distanceFromRouteMeters: 80),
        position: _position(start),
      );
      policy.update(
        update: _guidance(distanceFromRouteMeters: 80),
        position: _position(start.add(const Duration(seconds: 1))),
      );
      expect(
        policy.shouldReroute(start.add(const Duration(seconds: 1))),
        isFalse,
      );

      policy.update(
        update: _guidance(distanceFromRouteMeters: 80),
        position: _position(start.add(const Duration(seconds: 2))),
      );

      expect(
        policy.shouldReroute(start.add(const Duration(seconds: 2))),
        isTrue,
      );
    });

    test('does not mistake GPS uncertainty for leaving the route', () {
      final policy = RouteDeviationPolicy(TravelMode.car);
      final start = DateTime.utc(2026);

      for (var index = 0; index < 4; index++) {
        final timestamp = start.add(Duration(seconds: index * 2));
        policy.update(
          update: _guidance(distanceFromRouteMeters: 45),
          position: _position(timestamp, accuracyMeters: 25),
        );
      }

      expect(
        policy.shouldReroute(start.add(const Duration(seconds: 6))),
        isFalse,
      );
    });

    test('reroutes after three reliable fixes in the reverse direction', () {
      final policy = RouteDeviationPolicy(TravelMode.car);
      final start = DateTime.utc(2026);

      for (var index = 0; index < 3; index++) {
        policy.update(
          update: _guidance(reverseDirection: true),
          position: _position(start.add(Duration(seconds: index))),
        );
      }

      expect(
        policy.shouldReroute(start.add(const Duration(seconds: 2))),
        isTrue,
      );
    });
  });

  group('ReroutePolicy', () {
    test('allows a follow-up after eight seconds of continued deviation', () {
      final policy = ReroutePolicy();
      final start = DateTime.utc(2026);

      expect(policy.markAttempt(start, force: false), isTrue);
      expect(
        policy.markAttempt(start.add(const Duration(seconds: 7)), force: false),
        isFalse,
      );
      expect(
        policy.markAttempt(start.add(const Duration(seconds: 8)), force: false),
        isTrue,
      );
    });

    test('keeps a twenty-second backoff after a failed recalculation', () {
      final policy = ReroutePolicy();
      final start = DateTime.utc(2026);

      expect(policy.markAttempt(start, force: false), isTrue);
      policy.markFailure(start);

      expect(
        policy.markAttempt(
          start.add(const Duration(seconds: 19)),
          force: false,
        ),
        isFalse,
      );
      expect(
        policy.markAttempt(
          start.add(const Duration(seconds: 20)),
          force: false,
        ),
        isTrue,
      );
    });

    test('honors a longer retry delay returned by the service', () {
      final policy = ReroutePolicy();
      final start = DateTime.utc(2026);

      expect(policy.markAttempt(start, force: false), isTrue);
      policy.markFailure(start, retryAfter: const Duration(seconds: 30));

      expect(
        policy.markAttempt(
          start.add(const Duration(seconds: 29)),
          force: false,
        ),
        isFalse,
      );
      expect(
        policy.markAttempt(
          start.add(const Duration(seconds: 30)),
          force: false,
        ),
        isTrue,
      );
    });
  });
}

NavigationPosition _position(DateTime timestamp, {double accuracyMeters = 5}) {
  return NavigationPosition(
    point: const LatLng(48.8566, 2.3522),
    accuracyMeters: accuracyMeters,
    headingDegrees: 90,
    speedMetersPerSecond: 5,
    timestamp: timestamp,
  );
}

GuidanceUpdate _guidance({
  double distanceFromRouteMeters = 0,
  bool reverseDirection = false,
}) {
  return GuidanceUpdate(
    snappedPosition: const LatLng(48.8566, 2.3522),
    progressMeters: 0,
    distanceFromRouteMeters: distanceFromRouteMeters,
    currentStepIndex: 0,
    upcomingStepIndex: 0,
    distanceToManeuverMeters: 100,
    remainingDistanceMeters: 1000,
    remainingDurationSeconds: 600,
    arrived: false,
    reverseDirection: reverseDirection,
  );
}
