import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_engine.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_policies.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:latlong2/latlong.dart';

import 'support/guidance_scenario_runner.dart';
import 'support/test_fixtures.dart';

void main() {
  const runner = GuidanceScenarioRunner();
  const oracle = GuidanceScenarioOracle();

  test('replays nearby urban maneuvers through arrival', () {
    final start = DateTime.utc(2026, 1, 1, 12);
    final scenario = GuidanceScenario(
      name: 'virages urbains rapprochés',
      route: urbanRoute,
      mode: TravelMode.car,
      frames: [
        GuidanceScenarioFrame(
          position: _position(48.8566, 2.3522, start),
          expectedCurrentStep: 0,
          expectedUpcomingStep: 1,
          expectedDistanceToManeuverMeters: 499,
          expectedDisplayHeadingDegrees: 90,
          expectedHeadingSource: NavigationHeadingSource.routeAligned,
        ),
        GuidanceScenarioFrame(
          position: _position(
            48.8566,
            2.3562,
            start.add(const Duration(seconds: 5)),
            speed: 20,
          ),
          expectedCurrentStep: 0,
          expectedUpcomingStep: 1,
          expectedDistanceToManeuverMeters: 100,
          expectedDisplayHeadingDegrees: 90,
        ),
        GuidanceScenarioFrame(
          position: _position(
            parisDestination.latitude,
            parisDestination.longitude,
            start.add(const Duration(seconds: 10)),
            speed: 0,
          ),
        ),
        GuidanceScenarioFrame(
          position: _position(
            parisDestination.latitude,
            parisDestination.longitude,
            start.add(const Duration(seconds: 11)),
            speed: 0,
          ),
          expectedArrival: true,
        ),
      ],
    );

    final report = runner.run(scenario);
    oracle.verify(scenario, report);
    expect(
      report.announcements,
      contains(contains('tournez à droite sur RUE SAINT-ANTOINE')),
    );
  });

  test(
    'keeps real heading and requests rerouting after three reverse fixes',
    () {
      final start = DateTime.utc(2026, 1, 1, 12);
      final frames = List.generate(
        3,
        (index) => GuidanceScenarioFrame(
          position: _position(
            48.8566,
            2.3542,
            start.add(Duration(seconds: index * 2)),
            heading: 270,
          ),
          expectedDisplayHeadingDegrees: 270,
          expectedHeadingSource: NavigationHeadingSource.gps,
          expectedReroute: index == 2,
        ),
      );
      final scenario = GuidanceScenario(
        name: 'mauvais sens',
        route: urbanRoute,
        mode: TravelMode.car,
        frames: frames,
      );

      oracle.verify(scenario, runner.run(scenario));
    },
  );

  test('replays fork, ramp, merge and U-turn instructions in order', () {
    final start = DateTime.utc(2026, 1, 1, 12);
    final route = _maneuverFamilyRoute();
    final scenario = GuidanceScenario(
      name: 'embranchement bretelle insertion demi-tour',
      route: route,
      mode: TravelMode.car,
      frames: [
        for (var index = 0; index < 5; index++)
          GuidanceScenarioFrame(
            position: _position(
              48.8566,
              2.3522 + index * 0.001,
              start.add(Duration(seconds: index * 5)),
              speed: 20,
            ),
            expectedCurrentStep: index,
            expectedUpcomingStep: index + 1,
            expectedDistanceToManeuverMeters: 100,
          ),
      ],
    );

    final report = runner.run(scenario);
    oracle.verify(scenario, report);
    expect(report.announcements[0], contains('embranchement'));
    expect(report.announcements[1], contains('bretelle'));
    expect(report.announcements[2], contains('insérez-vous'));
    expect(report.announcements[3], contains('demi-tour'));
  });

  test('survives GPS noise, a parallel road and an implausible jump', () {
    const scenarios = <_TraceScenario>[
      _TraceScenario(
        name: 'bruit GPS urbain',
        coordinates: [
          (48.85660, 2.35220),
          (48.85662, 2.35320),
          (48.85658, 2.35420),
          (48.85661, 2.35520),
          (48.85660, 2.35620),
        ],
      ),
      _TraceScenario(
        name: 'route parallèle temporaire',
        coordinates: [
          (48.85660, 2.35220),
          (48.85678, 2.35320),
          (48.85679, 2.35420),
          (48.85660, 2.35520),
          (48.85660, 2.35620),
        ],
      ),
      _TraceScenario(
        name: 'positions en arrière',
        coordinates: [
          (48.85660, 2.35420),
          (48.85660, 2.35520),
          (48.85660, 2.35460),
          (48.85660, 2.35410),
          (48.85660, 2.35620),
        ],
      ),
      _TraceScenario(
        name: 'saut après perte de signal',
        coordinates: [
          (48.85660, 2.35220),
          (48.85660, 2.35320),
          (48.85690, 2.36220),
        ],
      ),
    ];

    for (final scenario in scenarios) {
      final engine = NavigationEngine(urbanRoute, TravelMode.car);
      var timestamp = DateTime.utc(2026, 1, 1, 12);
      NavigationPosition? previousPosition;
      double? previousProgress;
      for (final (latitude, longitude) in scenario.coordinates) {
        final position = _position(latitude, longitude, timestamp);
        final update = engine.update(
          position,
          previousProgressMeters: previousProgress,
          previousPosition: previousPosition,
        );
        if (previousProgress != null) {
          expect(
            update.progressMeters,
            greaterThanOrEqualTo(previousProgress),
            reason: scenario.name,
          );
          expect(
            update.progressMeters - previousProgress,
            lessThanOrEqualTo(120.01),
            reason: scenario.name,
          );
        }
        previousProgress = update.progressMeters;
        previousPosition = position;
        timestamp = timestamp.add(const Duration(seconds: 1));
      }
    }
  });

  test('matches the forward branch at a crossing', () {
    const route = RoutePlan(
      points: [
        LatLng(48.8600, 2.3300),
        LatLng(48.8610, 2.3310),
        LatLng(48.8600, 2.3310),
        LatLng(48.8610, 2.3300),
      ],
      distanceMeters: 500,
      durationSeconds: 300,
      steps: [],
      resourceVersion: 'synthetic-public-crossing',
    );
    final engine = NavigationEngine(route, TravelMode.pedestrian);
    final update = engine.update(
      _position(48.8605, 2.3305, DateTime.utc(2026), heading: 315),
      previousProgressMeters: 300,
    );

    expect(update.progressMeters, greaterThanOrEqualTo(300));
  });

  test('requires two precise or three acceptable arrival fixes', () {
    final precise = RouteDeviationPolicy(TravelMode.car);
    final acceptable = RouteDeviationPolicy(TravelMode.car);
    final time = DateTime.utc(2026);
    final arrival = _arrivalUpdate();

    for (var index = 0; index < 2; index++) {
      final position = _position(
        parisDestination.latitude,
        parisDestination.longitude,
        time.add(Duration(seconds: index)),
        accuracy: 20,
      );
      precise.update(update: arrival, position: position);
      expect(precise.hasArrived, index == 1);
    }
    for (var index = 0; index < 3; index++) {
      final position = _position(
        parisDestination.latitude,
        parisDestination.longitude,
        time.add(Duration(seconds: index)),
        accuracy: 35,
      );
      acceptable.update(update: arrival, position: position);
      expect(acceptable.hasArrived, index == 2);
    }
  });

  test('rejects 35 metre pedestrian fixes for arrival', () {
    final policy = RouteDeviationPolicy(TravelMode.pedestrian);
    final position = _position(
      reunionDestination.latitude,
      reunionDestination.longitude,
      DateTime.utc(2026),
      accuracy: 35,
    );

    for (var index = 0; index < 3; index++) {
      policy.update(update: _arrivalUpdate(), position: position);
    }

    expect(policy.hasArrived, isFalse);
  });
}

NavigationPosition _position(
  double latitude,
  double longitude,
  DateTime timestamp, {
  double accuracy = 5,
  double heading = 90,
  double speed = 5,
}) {
  return navigationPosition(
    latitude,
    longitude,
    accuracyMeters: accuracy,
    headingDegrees: heading,
    speedMetersPerSecond: speed,
    timestamp: timestamp,
  );
}

GuidanceUpdate _arrivalUpdate() => const GuidanceUpdate(
  snappedPosition: LatLng(48.8569, 2.3622),
  progressMeters: 1000,
  distanceFromRouteMeters: 0,
  currentStepIndex: 2,
  upcomingStepIndex: 2,
  distanceToManeuverMeters: 0,
  remainingDistanceMeters: 0,
  remainingDurationSeconds: 0,
  arrived: true,
);

RoutePlan _maneuverFamilyRoute() {
  final points = [
    for (var index = 0; index < 6; index++)
      LatLng(48.8566, 2.3522 + index * 0.001),
  ];
  const maneuvers = [
    ('depart', 'straight', 'RUE A'),
    ('fork', 'keep-left', 'RUE B'),
    ('on-ramp', 'right', 'BRETELLE C'),
    ('merge', 'slight-right', 'VOIE D'),
    ('turn', 'u_turn', 'RUE E'),
  ];
  return RoutePlan(
    points: points,
    distanceMeters: 500,
    durationSeconds: 120,
    resourceVersion: 'synthetic-public-maneuvers',
    steps: [
      for (var index = 0; index < maneuvers.length; index++)
        RouteStep(
          type: maneuvers[index].$1,
          modifier: maneuvers[index].$2,
          roadName: maneuvers[index].$3,
          distanceMeters: 100,
          points: [points[index], points[index + 1]],
        ),
      RouteStep(
        type: 'arrive',
        modifier: 'straight',
        roadName: '',
        distanceMeters: 0,
        points: [points.last],
      ),
    ],
  );
}

class _TraceScenario {
  const _TraceScenario({required this.name, required this.coordinates});

  final String name;
  final List<(double, double)> coordinates;
}
