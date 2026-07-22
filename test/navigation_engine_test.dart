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

    test('does not skip a maneuver after a 2.5 meter departure step', () {
      final engine = NavigationEngine(_shortDepartureRoute(), TravelMode.car);

      final initial = engine.update(_position(0, 0));
      final afterTurn = engine.update(
        _position(0, 0.00004),
        previousProgressMeters: initial.progressMeters,
      );
      final backwardJitter = engine.update(
        _position(0, 0.00001),
        previousProgressMeters: afterTurn.progressMeters,
      );

      expect(initial.currentStepIndex, 0);
      expect(initial.upcomingStepIndex, 1);
      expect(initial.distanceToManeuverMeters, closeTo(2.5, 0.2));
      expect(afterTurn.currentStepIndex, 1);
      expect(afterTurn.upcomingStepIndex, 2);
      expect(backwardJitter.upcomingStepIndex, 2);
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

    test('uses the step geometry endpoint as the maneuver anchor', () {
      final engine = NavigationEngine(
        _routeWithInconsistentStepDistances(),
        TravelMode.car,
      );

      final update = engine.update(_position(0, 0));

      expect(update.distanceToManeuverMeters, closeTo(300, 5));
      expect(update.upcomingStepIndex, 1);
    });

    test('accepts a stationary destination fix with delayed progress', () {
      final engine = NavigationEngine(_route(), TravelMode.car);

      final update = engine.update(
        _position(0, 0.01, speedMetersPerSecond: 0),
        previousProgressMeters: 500,
      );

      expect(update.progressMeters, lessThan(950));
      expect(update.rawDistanceToDestinationMeters, lessThan(1));
      expect(update.arrived, isTrue);
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

    test('keeps the numbered roundabout instruction until its exit', () {
      final engine = NavigationEngine(_roundaboutRoute(), TravelMode.car);

      final beforeEntry = engine.update(_position(0, 0.0005));
      final insideRoundabout = engine.update(
        _position(0, 0.0012),
        previousProgressMeters: beforeEntry.progressMeters,
      );

      expect(beforeEntry.upcomingStepIndex, 1);
      expect(insideRoundabout.currentStepIndex, 1);
      expect(insideRoundabout.upcomingStepIndex, 1);
      expect(insideRoundabout.distanceToManeuverMeters, closeTo(60, 15));
    });
  });

  group('NavigationHeadingTracker', () {
    test('derives the driving direction from successive GPS fixes', () {
      final tracker = NavigationHeadingTracker(TravelMode.car);
      final start = _position(
        48.8566,
        2.3522,
        headingDegrees: 0,
        headingAccuracyDegrees: 999,
        timestamp: DateTime(2026, 1, 1, 12),
      );
      final east = _position(
        48.8566,
        2.3524,
        headingDegrees: 0,
        headingAccuracyDegrees: 999,
        timestamp: DateTime(2026, 1, 1, 12, 0, 2),
      );

      expect(
        tracker
            .resolve(
              start,
              routeHeadingDegrees: 180,
              distanceFromRouteMeters: 0,
            )
            .displayHeadingDegrees,
        180,
      );
      final decision = tracker.resolve(
        east,
        routeHeadingDegrees: 180,
        distanceFromRouteMeters: 0,
      );
      expect(decision.displayHeadingDegrees, closeTo(90, 1));
      expect(decision.movementHeadingDegrees, closeTo(90, 1));
      expect(decision.source, NavigationHeadingSource.movement);
    });

    test('does not rotate for sub-accuracy GPS jitter', () {
      final tracker = NavigationHeadingTracker(TravelMode.car);
      final start = _position(
        48.8566,
        2.3522,
        headingDegrees: 90,
        timestamp: DateTime(2026, 1, 1, 12),
      );
      final jitter = _position(
        48.85662,
        2.3522,
        headingDegrees: 270,
        headingAccuracyDegrees: 999,
        timestamp: DateTime(2026, 1, 1, 12, 0, 1),
      );

      expect(
        tracker
            .resolve(start, routeHeadingDegrees: 90, distanceFromRouteMeters: 0)
            .displayHeadingDegrees,
        90,
      );
      expect(
        tracker
            .resolve(jitter, routeHeadingDegrees: 0, distanceFromRouteMeters: 0)
            .displayHeadingDegrees,
        90,
      );
    });

    test('aligns a plausible observed heading to the road tangent', () {
      final tracker = NavigationHeadingTracker(TravelMode.car);
      final decision = tracker.resolve(
        _position(0, 0, headingDegrees: 35),
        routeHeadingDegrees: 90,
        distanceFromRouteMeters: 3,
      );

      expect(decision.displayHeadingDegrees, 90);
      expect(decision.gpsHeadingDegrees, 35);
      expect(decision.angularDifferenceDegrees, 55);
      expect(decision.source, NavigationHeadingSource.routeAligned);
    });

    test('preserves a reliable reverse heading instead of snapping it', () {
      final tracker = NavigationHeadingTracker(TravelMode.car);
      final decision = tracker.resolve(
        _position(0, 0, headingDegrees: 270),
        routeHeadingDegrees: 90,
        distanceFromRouteMeters: 2,
      );

      expect(decision.displayHeadingDegrees, 270);
      expect(decision.angularDifferenceDegrees, 180);
      expect(decision.source, NavigationHeadingSource.gps);
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

    test('replaying the current instruction marks crossed thresholds', () {
      final route = _route();
      final planner = GuidanceAnnouncementPlanner();

      expect(
        planner.replayCurrent(
          stepIndex: 1,
          distanceToManeuverMeters: 45,
          remainingDistanceMeters: 800,
          route: route,
          mode: TravelMode.car,
        ),
        'Tournez à droite sur RUE B',
      );
      expect(
        planner.next(
          update: _guidance(distance: 40),
          route: route,
          mode: TravelMode.car,
        ),
        isNull,
      );
    });

    test('does not replay arrival before the destination', () {
      final route = _route();
      final planner = GuidanceAnnouncementPlanner();

      for (final remaining in [400.0, 20.0]) {
        expect(
          planner.replayCurrent(
            stepIndex: 2,
            distanceToManeuverMeters: remaining,
            remainingDistanceMeters: remaining,
            route: route,
            mode: TravelMode.car,
          ),
          'Continuez vers votre destination',
        );
      }
    });

    test('does not announce arrival before GPS confirmation', () {
      final route = _route();
      final planner = GuidanceAnnouncementPlanner();

      expect(
        planner.next(
          update: _guidance(
            distance: 20,
            currentStepIndex: 1,
            upcomingStepIndex: 2,
          ),
          route: route,
          mode: TravelMode.car,
        ),
        isNull,
      );
    });

    test('repeats the numbered exit once inside a roundabout', () {
      final route = _roundaboutRoute();
      final planner = GuidanceAnnouncementPlanner();

      expect(
        planner.next(
          update: _guidance(
            distance: 45,
            currentStepIndex: 0,
            upcomingStepIndex: 1,
          ),
          route: route,
          mode: TravelMode.car,
        ),
        contains('au rond-point, prenez la 3e sortie'),
      );
      expect(
        planner.next(
          update: _guidance(
            distance: 40,
            currentStepIndex: 1,
            upcomingStepIndex: 1,
          ),
          route: route,
          mode: TravelMode.car,
        ),
        'Prenez maintenant la 3e sortie sur RUE B',
      );
      expect(
        planner.next(
          update: _guidance(
            distance: 20,
            currentStepIndex: 1,
            upcomingStepIndex: 1,
          ),
          route: route,
          mode: TravelMode.car,
        ),
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
  double speedMetersPerSecond = 5,
  DateTime? timestamp,
}) {
  return NavigationPosition(
    point: LatLng(latitude, longitude),
    accuracyMeters: 5,
    headingDegrees: headingDegrees,
    headingAccuracyDegrees: headingAccuracyDegrees,
    speedMetersPerSecond: speedMetersPerSecond,
    timestamp: timestamp ?? DateTime(2026),
  );
}

GuidanceUpdate _guidance({
  required double distance,
  int currentStepIndex = 0,
  int upcomingStepIndex = 1,
}) {
  return GuidanceUpdate(
    snappedPosition: const LatLng(0, 0.002),
    progressMeters: 200,
    distanceFromRouteMeters: 0,
    currentStepIndex: currentStepIndex,
    upcomingStepIndex: upcomingStepIndex,
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

RoutePlan _shortDepartureRoute() {
  return const RoutePlan(
    points: [LatLng(0, 0), LatLng(0, 0.000025), LatLng(0, 0.01)],
    distanceMeters: 1000,
    durationSeconds: 500,
    resourceVersion: 'short-departure',
    steps: [
      RouteStep(
        type: 'depart',
        modifier: 'straight',
        roadName: 'RUE A',
        distanceMeters: 2.5,
        points: [LatLng(0, 0), LatLng(0, 0.000025)],
      ),
      RouteStep(
        type: 'turn',
        modifier: 'left',
        roadName: 'RUE B',
        distanceMeters: 997.5,
        points: [LatLng(0, 0.000025), LatLng(0, 0.01)],
      ),
      RouteStep(
        type: 'arrive',
        modifier: 'straight',
        roadName: '',
        distanceMeters: 0,
        points: [LatLng(0, 0.01), LatLng(0, 0.01)],
      ),
    ],
  );
}

RoutePlan _routeWithInconsistentStepDistances() {
  return const RoutePlan(
    points: [LatLng(0, 0), LatLng(0, 0.003), LatLng(0, 0.01)],
    distanceMeters: 1000,
    durationSeconds: 500,
    resourceVersion: 'geometry-anchors',
    steps: [
      RouteStep(
        type: 'depart',
        modifier: 'straight',
        roadName: 'RUE A',
        distanceMeters: 800,
        points: [LatLng(0, 0), LatLng(0, 0.003)],
      ),
      RouteStep(
        type: 'turn',
        modifier: 'right',
        roadName: 'RUE B',
        distanceMeters: 200,
        points: [LatLng(0, 0.003), LatLng(0, 0.01)],
      ),
      RouteStep(
        type: 'arrive',
        modifier: 'straight',
        roadName: '',
        distanceMeters: 0,
        points: [LatLng(0, 0.01)],
      ),
    ],
  );
}

RoutePlan _roundaboutRoute() {
  return const RoutePlan(
    points: [
      LatLng(0, 0),
      LatLng(0, 0.001),
      LatLng(0, 0.0018),
      LatLng(0, 0.0038),
    ],
    distanceMeters: 380,
    durationSeconds: 120,
    resourceVersion: 'roundabout',
    steps: [
      RouteStep(
        type: 'depart',
        modifier: 'straight',
        roadName: 'RUE A',
        distanceMeters: 100,
        points: [],
      ),
      RouteStep(
        type: 'roundabout',
        modifier: 'right',
        roadName: 'RUE B',
        distanceMeters: 80,
        points: [],
        exitNumber: 3,
      ),
      RouteStep(
        type: 'continue',
        modifier: 'straight',
        roadName: 'RUE B',
        distanceMeters: 200,
        points: [],
      ),
      RouteStep(
        type: 'arrive',
        modifier: 'straight',
        roadName: 'RUE B',
        distanceMeters: 0,
        points: [],
      ),
    ],
  );
}
