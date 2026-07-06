import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/data/device_location_service.dart';
import 'package:ign_itineraires/src/features/routing/data/geoplateforme_api.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/routing_controller.dart';

import 'support/fakes.dart';
import 'support/test_fixtures.dart';

void main() {
  late TestAppHarness harness;
  late RoutingController controller;

  setUp(() {
    harness = TestAppHarness();
    controller = RoutingController(
      harness.api,
      harness.location,
      harness.store,
    );
  });

  tearDown(() async {
    controller.dispose();
    await harness.dispose();
  });

  test('initializes with the current position and local data', () async {
    harness.store.favorites = [parisDestination];
    harness.store.historyEnabled = true;
    harness.store.recents = [
      RecentRoute(
        start: parisStart,
        destination: parisDestination,
        mode: TravelMode.car,
        distanceMeters: 1000,
        durationSeconds: 600,
        createdAt: DateTime.utc(2026),
      ),
    ];

    await controller.initialize();

    expect(controller.start, routeStartPosition.asPlace);
    expect(controller.favorites, [parisDestination]);
    expect(controller.recents, hasLength(1));
  });

  test(
    'keeps manual entry available when silent GPS initialization fails',
    () async {
      harness.location.error = const DeviceLocationException('GPS refusé');

      await controller.initialize();

      expect(controller.start, isNull);
      expect(controller.message, isNull);
      expect(controller.locating, isFalse);
    },
  );

  test('search delegates to the address service', () async {
    final results = await controller.search('Bastille');

    expect(results, [parisDestination]);
    expect(harness.api.searchCalls, 1);
  });

  test('calculates without retaining history by default', () async {
    controller
      ..setStart(parisStart)
      ..setDestination(parisDestination);

    await controller.calculate();

    expect(controller.route, urbanRoute);
    expect(harness.api.lastMode, TravelMode.car);
    expect(controller.recents, isEmpty);
    expect(harness.store.recents, isEmpty);
  });

  test('stores and erases recent routes only after opt-in', () async {
    controller
      ..setStart(parisStart)
      ..setDestination(parisDestination);
    await controller.setHistoryEnabled(true);

    await controller.calculate();

    expect(controller.recents, hasLength(1));
    expect(harness.store.recents, hasLength(1));

    await controller.setHistoryEnabled(false);

    expect(controller.recents, isEmpty);
    expect(harness.store.recents, isEmpty);
  });

  test('adds and removes a destination favorite', () async {
    controller.setDestination(parisDestination);

    await controller.toggleDestinationFavorite();
    expect(controller.destinationIsFavorite, isTrue);
    expect(harness.store.favorites, [parisDestination]);

    await controller.toggleDestinationFavorite();
    expect(controller.destinationIsFavorite, isFalse);
    expect(harness.store.favorites, isEmpty);
  });

  test(
    'surfaces route service errors without storing a recent route',
    () async {
      harness.api.routeError = const GeoplateformeException(
        'Service indisponible',
      );
      controller
        ..setStart(parisStart)
        ..setDestination(parisDestination);
      await controller.setHistoryEnabled(true);

      await controller.calculate();

      expect(controller.route, isNull);
      expect(controller.message, 'Service indisponible');
      expect(controller.messageIsError, isTrue);
      expect(harness.store.recents, isEmpty);
    },
  );

  test(
    'requires both endpoints and invalidates a route when mode changes',
    () async {
      await controller.calculate();
      expect(controller.message, 'Choisissez un départ et une arrivée.');

      controller
        ..setStart(parisStart)
        ..setDestination(parisDestination);
      await controller.calculate();
      expect(controller.route, urbanRoute);

      controller.setMode(TravelMode.pedestrian);
      expect(controller.route, isNull);
      expect(controller.mode, TravelMode.pedestrian);
    },
  );

  test('restores a recent route and clears stored recents', () async {
    final recent = RecentRoute(
      start: parisStart,
      destination: parisDestination,
      mode: TravelMode.pedestrian,
      distanceMeters: 1000,
      durationSeconds: 600,
      createdAt: DateTime.utc(2026),
    );
    harness.store.recents = [recent];
    harness.store.historyEnabled = true;
    await controller.initialize();

    controller.restoreRecent(recent);
    expect(controller.start, parisStart);
    expect(controller.destination, parisDestination);
    expect(controller.mode, TravelMode.pedestrian);

    await controller.clearRecents();
    expect(controller.recents, isEmpty);
    expect(harness.store.recents, isEmpty);
  });

  test('deletes stale recents when history was not enabled', () async {
    harness.store.recents = [
      RecentRoute(
        start: parisStart,
        destination: parisDestination,
        mode: TravelMode.car,
        distanceMeters: 1000,
        durationSeconds: 600,
        createdAt: DateTime.utc(2026),
      ),
    ];

    await controller.initialize();

    expect(controller.historyEnabled, isFalse);
    expect(controller.recents, isEmpty);
    expect(harness.store.recents, isEmpty);
  });

  test('ignores a route response after the destination changes', () async {
    await controller.initialize();
    controller.setStart(parisStart);
    controller.setDestination(parisDestination);
    final pending = Completer<RoutePlan>();
    harness.api.pendingRoute = pending;

    final calculation = controller.calculate();
    await Future<void>.delayed(Duration.zero);
    controller.setDestination(reunionDestination);
    pending.complete(urbanRoute);
    await calculation;

    expect(controller.destination, reunionDestination);
    expect(controller.route, isNull);
    expect(controller.calculating, isFalse);
  });
}
