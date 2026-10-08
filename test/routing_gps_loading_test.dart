import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/data/device_location_service.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/routing_controller.dart';

import 'support/fakes.dart';
import 'support/test_fixtures.dart';

class _DelayedLocation extends FakeDeviceLocation {
  Completer<Place> pendingPlace = Completer<Place>();

  @override
  Future<Place> currentPlace() => pendingPlace.future;
}

void main() {
  for (final fails in [false, true]) {
    test(
      'manual departure clears GPS loading before late ${fails ? 'error' : 'fix'}',
      () async {
        final location = _DelayedLocation();
        final harness = TestAppHarness(location: location);
        final controller = RoutingController(
          harness.api,
          location,
          harness.store,
        );
        addTearDown(() async {
          controller.dispose();
          await harness.dispose();
        });

        final locating = controller.useCurrentLocation();
        expect(controller.locating, isTrue);
        controller.setStart(parisDestination);
        expect(controller.locating, isFalse);
        if (fails) {
          location.pendingPlace.completeError(
            const DeviceLocationException('Old GPS error'),
          );
        } else {
          location.pendingPlace.complete(parisStart);
        }
        await locating;

        expect(controller.locating, isFalse);
        expect(controller.start, parisDestination);
        expect(controller.message, isNull);
      },
    );
  }

  test('an obsolete GPS fix does not stop a new location request', () async {
    final location = _DelayedLocation();
    final harness = TestAppHarness(location: location);
    final controller = RoutingController(harness.api, location, harness.store);
    addTearDown(() async {
      controller.dispose();
      await harness.dispose();
    });
    final oldFix = location.pendingPlace;
    final first = controller.useCurrentLocation();
    controller.setStart(parisDestination);
    location.pendingPlace = Completer<Place>();
    final second = controller.useCurrentLocation();
    oldFix.complete(parisStart);
    await first;

    expect(controller.locating, isTrue);
    expect(controller.start, parisDestination);
    location.pendingPlace.complete(reunionDestination);
    await second;
    expect(controller.locating, isFalse);
    expect(controller.start, reunionDestination);
  });
}
