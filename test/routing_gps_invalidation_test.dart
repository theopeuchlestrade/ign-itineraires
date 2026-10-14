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
    controller.setStart(reunionDestination);
    controller.setDestination(parisDestination);
  });

  tearDown(() async {
    controller.dispose();
    await harness.dispose();
  });

  for (final fails in [false, true]) {
    test(
      'GPS departure invalidates a late route ${fails ? 'error' : 'result'}',
      () async {
        final pending = Completer<RoutePlan>();
        harness.api.pendingRoute = pending;
        final calculation = controller.calculate();
        expect(controller.calculating, isTrue);

        await controller.useCurrentLocation();
        expect(controller.start, harness.location.current.asPlace);
        expect(controller.calculating, isFalse);
        final gpsMessage = controller.message;
        if (fails) {
          pending.completeError(
            const GeoplateformeException('Old route failed'),
          );
        } else {
          pending.complete(urbanRoute);
        }
        await calculation;

        expect(controller.route, isNull);
        expect(controller.message, gpsMessage);
        expect(controller.routeRetryAvailable, isFalse);

        harness.api.pendingRoute = null;
        await controller.calculate();
        expect(harness.api.lastStart, harness.location.current.asPlace);
        expect(controller.route, urbanRoute);
      },
    );
  }

  test('GPS failure preserves a valid route calculation in flight', () async {
    final pending = Completer<RoutePlan>();
    harness.api.pendingRoute = pending;
    final calculation = controller.calculate();
    harness.location.error = const DeviceLocationException('GPS unavailable');

    await controller.useCurrentLocation();
    expect(controller.start, reunionDestination);
    expect(controller.calculating, isTrue);
    pending.complete(urbanRoute);
    await calculation;

    expect(controller.route, urbanRoute);
    expect(controller.calculating, isFalse);
  });
}
