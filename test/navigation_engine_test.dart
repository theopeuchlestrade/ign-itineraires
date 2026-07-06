import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_engine.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('NavigationEngine', () {
    test('projects a GPS position and selects the upcoming instruction', () {
      final route = _route();
      final engine = NavigationEngine(route, TravelMode.car);

      final update = engine.update(_position(0, 0.0049));

      expect(update.progressMeters, closeTo(490, 15));
      expect(update.currentStepIndex, 0);
      expect(update.upcomingStepIndex, 1);
      expect(update.distanceToManeuverMeters, closeTo(10, 15));
      expect(update.distanceFromRouteMeters, lessThan(1));
    });

    test('keeps route progress monotonic when GPS jumps backwards', () {
      final engine = NavigationEngine(_route(), TravelMode.car);

      final update = engine.update(
        _position(0, 0.002),
        previousProgressMeters: 700,
      );

      expect(update.progressMeters, 700);
      expect(update.remainingDistanceMeters, 300);
    });

    test('reports distance from route for off-route detection', () {
      final engine = NavigationEngine(_route(), TravelMode.pedestrian);

      final update = engine.update(_position(0.001, 0.004));

      expect(update.distanceFromRouteMeters, greaterThan(100));
    });

    test('uses distinct pedestrian and car arrival thresholds', () {
      final route = _route();
      final nearDestination = _position(0.000225, 0.01);

      final car = NavigationEngine(
        route,
        TravelMode.car,
      ).update(nearDestination, previousProgressMeters: 950);
      final pedestrian = NavigationEngine(
        route,
        TravelMode.pedestrian,
      ).update(nearDestination, previousProgressMeters: 950);

      expect(car.arrived, isTrue);
      expect(pedestrian.arrived, isFalse);
    });

    test('does not move progress backwards after a U-turn GPS sequence', () {
      final engine = NavigationEngine(_route(), TravelMode.car);
      final outbound = engine.update(_position(0, 0.007));
      final turnedBack = engine.update(
        _position(0, 0.004),
        previousProgressMeters: outbound.progressMeters,
      );

      expect(turnedBack.progressMeters, outbound.progressMeters);
    });

    test('keeps the closest forward segment near a crossing', () {
      const crossingRoute = RoutePlan(
        points: [
          LatLng(0, 0),
          LatLng(0.001, 0.001),
          LatLng(0, 0.001),
          LatLng(0.001, 0),
        ],
        distanceMeters: 500,
        durationSeconds: 300,
        steps: [],
        resourceVersion: 'crossing',
      );
      final engine = NavigationEngine(crossingRoute, TravelMode.pedestrian);

      final update = engine.update(
        _position(0.0005, 0.0005),
        previousProgressMeters: 300,
      );

      expect(update.progressMeters, greaterThanOrEqualTo(300));
    });

    test('limits an implausible forward GPS jump', () {
      final engine = NavigationEngine(_route(), TravelMode.car);
      final previous = _position(0, 0.002, timestamp: DateTime(2026, 1, 1, 12));
      final update = engine.update(
        _position(0, 0.009, timestamp: DateTime(2026, 1, 1, 12, 0, 1)),
        previousProgressMeters: 200,
        previousPosition: previous,
      );

      expect(update.progressMeters, lessThanOrEqualTo(320));
    });

    test('detects a reliable reverse heading on the route', () {
      final engine = NavigationEngine(_route(), TravelMode.car);
      final update = engine.update(
        _position(0, 0.004, headingDegrees: 270, headingAccuracyDegrees: 5),
      );

      expect(update.reverseDirection, isTrue);
      expect(update.routeHeadingDegrees, closeTo(90, 1));
    });

    test('ignores an unreliable heading while matching', () {
      final engine = NavigationEngine(_route(), TravelMode.car);
      final update = engine.update(
        _position(0, 0.004, headingDegrees: 270, headingAccuracyDegrees: 90),
      );

      expect(update.reverseDirection, isFalse);
    });
  });

  group('GuidanceAnnouncementPlanner', () {
    test('announces far and near thresholds only once', () {
      final route = _route();
      final planner = GuidanceAnnouncementPlanner();
      final far = _guidance(distance: 250);
      final near = _guidance(distance: 45);

      expect(planner.initial(route), 'Partez tout droit sur RUE A');
      expect(
        planner.next(update: far, route: route, mode: TravelMode.car),
        contains('250 mètres'),
      );
      expect(
        planner.next(update: far, route: route, mode: TravelMode.car),
        isNull,
      );
      expect(
        planner.next(update: near, route: route, mode: TravelMode.car),
        contains('45 mètres'),
      );
      expect(
        planner.next(update: near, route: route, mode: TravelMode.car),
        isNull,
      );
    });
  });
}

NavigationPosition _position(
  double latitude,
  double longitude, {
  double headingDegrees = 90,
  double headingAccuracyDegrees = 5,
  DateTime? timestamp,
}) {
  return NavigationPosition(
    point: LatLng(latitude, longitude),
    accuracyMeters: 5,
    headingDegrees: headingDegrees,
    headingAccuracyDegrees: headingAccuracyDegrees,
    speedMetersPerSecond: 5,
    timestamp: timestamp ?? DateTime(2026),
  );
}

GuidanceUpdate _guidance({required double distance}) {
  return GuidanceUpdate(
    snappedPosition: const LatLng(0, 0.002),
    progressMeters: 200,
    distanceFromRouteMeters: 0,
    currentStepIndex: 0,
    upcomingStepIndex: 1,
    distanceToManeuverMeters: distance,
    remainingDistanceMeters: 800,
    remainingDurationSeconds: 400,
    arrived: false,
  );
}

RoutePlan _route() {
  return const RoutePlan(
    points: [LatLng(0, 0), LatLng(0, 0.005), LatLng(0, 0.01)],
    distanceMeters: 1000,
    durationSeconds: 500,
    resourceVersion: 'test',
    steps: [
      RouteStep(
        type: 'depart',
        modifier: 'straight',
        roadName: 'RUE A',
        distanceMeters: 500,
        points: [LatLng(0, 0), LatLng(0, 0.005)],
      ),
      RouteStep(
        type: 'turn',
        modifier: 'right',
        roadName: 'RUE B',
        distanceMeters: 500,
        points: [LatLng(0, 0.005), LatLng(0, 0.01)],
      ),
      RouteStep(
        type: 'arrive',
        modifier: 'right',
        roadName: 'RUE B',
        distanceMeters: 0,
        points: [LatLng(0, 0.01), LatLng(0, 0.01)],
      ),
    ],
  );
}
