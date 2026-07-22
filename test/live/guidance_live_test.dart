@Tags(['live'])
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ign_itineraires/src/features/routing/data/geoplateforme_api.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_engine.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_policies.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/navigation_controller.dart';

import '../support/fakes.dart';
import '../support/test_fixtures.dart';

void main() {
  late http.Client client;
  late GeoplateformeApi api;

  setUp(() {
    client = http.Client();
    api = GeoplateformeApi(
      client: client,
      requestTimeout: const Duration(seconds: 25),
    );
  });

  tearDown(() => client.close());

  final scenarios = <_LiveScenario>[
    const _LiveScenario(
      name: 'Paris voiture',
      start: parisStart,
      destination: parisDestination,
      mode: TravelMode.car,
    ),
    const _LiveScenario(
      name: 'Paris piéton',
      start: parisStart,
      destination: parisDestination,
      mode: TravelMode.pedestrian,
    ),
    const _LiveScenario(
      name: 'rond-point urbain parisien',
      start: Place(
        label: 'Place Charles-de-Gaulle, Paris',
        latitude: 48.8738,
        longitude: 2.2949,
      ),
      destination: Place(
        label: 'Avenue de Friedland, Paris',
        latitude: 48.8744,
        longitude: 2.3022,
      ),
      mode: TravelMode.car,
    ),
    const _LiveScenario(
      name: 'trajet avec bretelles parisiennes',
      start: Place(
        label: 'Porte Maillot, Paris',
        latitude: 48.8778,
        longitude: 2.2824,
      ),
      destination: Place(
        label: 'Porte de Saint-Cloud, Paris',
        latitude: 48.8380,
        longitude: 2.2568,
      ),
      mode: TravelMode.car,
    ),
    const _LiveScenario(
      name: 'La Réunion piéton',
      start: reunionStart,
      destination: reunionDestination,
      mode: TravelMode.pedestrian,
    ),
  ];

  for (final scenario in scenarios) {
    test('${scenario.name} traverse le moteur jusqu’à l’arrivée', () async {
      final route = await _retry(
        () => api.calculateRoute(
          start: scenario.start,
          destination: scenario.destination,
          mode: scenario.mode,
        ),
      );

      _expectSupportedSteps(route);
      final returnedTypes =
          route.steps.map((step) => step.normalizedType).toSet().toList()
            ..sort();
      // This report intentionally contains no coordinates or addresses.
      // ignore: avoid_print
      print('LIVE_GUIDANCE scenario=${scenario.name} types=$returnedTypes');
      _replayLiveRoute(route, scenario.mode);
    });
  }

  test('un trajet live traverse contrôleur et voix simulée', () async {
    final route = await _retry(
      () => api.calculateRoute(
        start: parisStart,
        destination: parisDestination,
        mode: TravelMode.car,
      ),
    );
    var now = DateTime.now();
    final location = FakeDeviceLocation(
      initialPosition: navigationPosition(
        route.points.first.latitude,
        route.points.first.longitude,
        timestamp: now,
      ),
    );
    final speech = FakeSpeech();
    final wakeLock = FakeWakeLock();
    final controller = NavigationController(
      _FixedRouteGateway(route),
      location,
      MemoryRouteStore(),
      speech,
      wakeLock,
      destination: parisDestination,
      mode: TravelMode.car,
      now: () => now,
    );
    addTearDown(() async {
      controller.dispose();
      await location.close();
    });

    await controller.start();

    expect(controller.session.status, NavigationStatus.active);
    expect(speech.messages, isNotEmpty);
    expect(wakeLock.enabled, isTrue);

    final points = _sample(route.points, maximum: 120);
    for (final point in points.skip(1)) {
      now = now.add(const Duration(seconds: 15));
      location.emit(
        navigationPosition(
          point.latitude,
          point.longitude,
          speedMetersPerSecond: 20,
          timestamp: now,
        ),
      );
      await _flushController();
    }
    for (var index = 0; index < 2; index++) {
      now = now.add(const Duration(seconds: 1));
      location.emit(
        navigationPosition(
          route.points.last.latitude,
          route.points.last.longitude,
          speedMetersPerSecond: 0,
          timestamp: now,
        ),
      );
      await _flushController();
    }

    expect(controller.session.status, NavigationStatus.arrived);
    expect(wakeLock.enabled, isFalse);
    expect(location.activeWatchers, 0);
    expect(
      speech.messages.where(
        (message) => message == 'Vous êtes arrivé à destination.',
      ),
      hasLength(1),
    );
  });
}

void _replayLiveRoute(RoutePlan route, TravelMode mode) {
  final engine = NavigationEngine(route, mode);
  final headings = NavigationHeadingTracker(mode);
  final announcements = GuidanceAnnouncementPlanner();
  final deviation = RouteDeviationPolicy(mode);
  final spoken = <String>{};
  NavigationPosition? previousPosition;
  double? previousProgress;
  var timestamp = DateTime.utc(2026, 1, 1, 12);

  for (final point in _sample(route.points, maximum: 160)) {
    final position = navigationPosition(
      point.latitude,
      point.longitude,
      speedMetersPerSecond: mode == TravelMode.car ? 20 : 1.8,
      timestamp: timestamp,
    );
    final update = engine.update(
      position,
      previousProgressMeters: previousProgress,
      previousPosition: previousPosition,
    );
    if (previousProgress case final progress?) {
      expect(update.progressMeters, greaterThanOrEqualTo(progress));
    }
    final heading = headings.resolve(
      position,
      routeHeadingDegrees: update.routeHeadingDegrees,
      distanceFromRouteMeters: update.distanceFromRouteMeters,
    );
    expect(heading.displayHeadingDegrees, inInclusiveRange(0, 360));
    final announcement = announcements.next(
      update: update,
      route: route,
      mode: mode,
    );
    if (announcement != null) expect(spoken.add(announcement), isTrue);
    deviation.update(update: update, position: position);
    previousPosition = position;
    previousProgress = update.progressMeters;
    timestamp = timestamp.add(const Duration(seconds: 15));
  }

  for (var index = 0; index < 3 && previousPosition != null; index++) {
    final position = navigationPosition(
      route.points.last.latitude,
      route.points.last.longitude,
      accuracyMeters: 5,
      speedMetersPerSecond: 0,
      timestamp: timestamp.add(Duration(seconds: index)),
    );
    final update = engine.update(
      position,
      previousProgressMeters: previousProgress,
      previousPosition: previousPosition,
    );
    deviation.update(update: update, position: position);
    previousProgress = update.progressMeters;
    previousPosition = position;
    if (deviation.hasArrived) return;
  }
  fail('La trace issue de Géoplateforme ne se termine pas.');
}

List<T> _sample<T>(List<T> values, {required int maximum}) {
  if (values.length <= maximum) return values;
  final stride = math.max(1, (values.length / maximum).ceil());
  final sampled = <T>[
    for (var index = 0; index < values.length; index += stride) values[index],
  ];
  if (sampled.last != values.last) sampled.add(values.last);
  return sampled;
}

void _expectSupportedSteps(RoutePlan route) {
  const supported = {
    'depart',
    'arrive',
    'turn',
    'merge',
    'ramp',
    'on ramp',
    'off ramp',
    'fork',
    'end of road',
    'roundabout',
    'rotary',
    'roundabout turn',
    'exit roundabout',
    'exit rotary',
    'new name',
    'continue',
    'notification',
    'use lane',
  };
  expect(route.steps, isNotEmpty);
  expect(
    route.steps
        .map((step) => step.normalizedType)
        .toSet()
        .difference(supported),
    isEmpty,
  );
  expect(
    route.steps.every(
      (step) =>
          step.instruction.isNotEmpty && step.normalizedModifier.isNotEmpty,
    ),
    isTrue,
  );
}

Future<T> _retry<T>(Future<T> Function() action) async {
  Object? lastError;
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      return await action();
    } catch (error) {
      lastError = error;
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }
  throw lastError!;
}

Future<void> _flushController() async {
  for (var turn = 0; turn < 5; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _FixedRouteGateway implements GeoplateformeGateway {
  const _FixedRouteGateway(this.route);

  final RoutePlan route;

  @override
  Future<RoutePlan> calculateRoute({
    required Place start,
    required Place destination,
    required TravelMode mode,
  }) async => route;

  @override
  Future<List<Place>> searchPlaces(String query) async => const [];
}

class _LiveScenario {
  const _LiveScenario({
    required this.name,
    required this.start,
    required this.destination,
    required this.mode,
  });

  final String name;
  final Place start;
  final Place destination;
  final TravelMode mode;
}
