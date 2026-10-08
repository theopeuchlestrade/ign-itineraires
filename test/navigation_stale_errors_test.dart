import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/data/device_location_service.dart';
import 'package:ign_itineraires/src/features/routing/data/geoplateforme_api.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/navigation_controller.dart';

import 'support/fakes.dart';
import 'support/test_fixtures.dart';

class _DelayedLocation extends FakeDeviceLocation {
  Completer<NavigationPosition>? gate;

  @override
  Future<NavigationPosition> currentPosition({TravelMode? navigationMode}) {
    return gate?.future ??
        super.currentPosition(navigationMode: navigationMode);
  }
}

class _DelayedWakeLock extends FakeWakeLock {
  Completer<void>? gate;

  @override
  Future<void> enable() async {
    await gate?.future;
    await super.enable();
  }
}

void main() {
  late TestAppHarness harness;
  late NavigationController controller;
  late _DelayedLocation location;
  late _DelayedWakeLock wakeLock;
  var now = routeStartPosition.timestamp;

  setUp(() {
    now = routeStartPosition.timestamp;
    location = _DelayedLocation();
    wakeLock = _DelayedWakeLock();
    harness = TestAppHarness(location: location, wakeLock: wakeLock);
    controller = NavigationController(
      harness.api,
      location,
      harness.store,
      harness.speech,
      wakeLock,
      destination: parisDestination,
      mode: TravelMode.car,
      now: () => now,
    );
  });

  tearDown(() async {
    controller.dispose();
    await harness.dispose();
  });

  Future<void> leaveForeground(bool stop) =>
      stop ? controller.stop() : controller.pause();

  Future<void> triggerReroute() async {
    for (var index = 0; index < 3; index++) {
      now = now.add(const Duration(seconds: 2));
      location.emit(navigationPosition(48.8580, 2.3571, timestamp: now));
      await Future<void>.delayed(Duration.zero);
    }
    expect(harness.api.routeCalls, 2);
    expect(controller.session.status, NavigationStatus.rerouting);
  }

  for (final stop in [false, true]) {
    final action = stop ? 'stop' : 'pause';
    final expected = stop ? NavigationStatus.stopped : NavigationStatus.paused;
    for (final typed in [false, true]) {
      final kind = typed ? 'gateway' : 'unexpected';
      test('$action survives a late $kind initial route error', () async {
        final pending = Completer<RoutePlan>();
        harness.api.pendingRoute = pending;
        final starting = controller.start();
        await Future<void>.delayed(Duration.zero);
        expect(harness.api.routeCalls, 1);
        await leaveForeground(stop);
        final message = controller.session.message;
        pending.completeError(
          typed
              ? const GeoplateformeException('Old route error')
              : StateError('Old unexpected error'),
        );
        await starting;

        expect(controller.session.status, expected);
        expect(controller.session.message, message);
        expect(location.activeWatchers, 0);
        expect(wakeLock.enabled, isFalse);
      });

      test('$action survives a late $kind initial location error', () async {
        final pending = Completer<NavigationPosition>();
        location.gate = pending;
        final starting = controller.start();
        await Future<void>.delayed(Duration.zero);
        expect(controller.session.status, NavigationStatus.acquiringPosition);
        await leaveForeground(stop);
        final message = controller.session.message;
        pending.completeError(
          typed
              ? const DeviceLocationException(
                  'Old location error',
                  recovery: LocationRecovery.openAppSettings,
                )
              : StateError('Old unexpected error'),
        );
        await starting;

        expect(controller.session.status, expected);
        expect(controller.session.message, message);
        expect(controller.session.locationRecovery, isNull);
        expect(harness.api.routeCalls, 0);
      });

      test(
        '$action survives a late $kind off-route recalculation error',
        () async {
          await controller.start();
          final pending = Completer<RoutePlan>();
          harness.api.pendingRoute = pending;
          await triggerReroute();
          await leaveForeground(stop);
          final message = controller.session.message;
          pending.completeError(
            typed
                ? const GeoplateformeException('Old reroute error')
                : StateError('Old unexpected error'),
          );
          await Future<void>.delayed(Duration.zero);

          expect(controller.session.status, expected);
          expect(controller.session.message, message);
          expect(location.activeWatchers, 0);
          expect(wakeLock.enabled, isFalse);
        },
      );
    }

    test('$action survives a late wake-lock activation failure', () async {
      final pending = Completer<void>();
      wakeLock.gate = pending;
      final starting = controller.start();
      await Future<void>.delayed(Duration.zero);
      expect(controller.session.status, NavigationStatus.active);
      await leaveForeground(stop);
      final message = controller.session.message;
      pending.completeError(StateError('Old wake-lock error'));
      await starting;

      expect(controller.session.status, expected);
      expect(controller.session.message, message);
      expect(harness.speech.messages, isEmpty);
      expect(location.watchCalls, 0);
    });
  }

  test(
    'a late initial route error does not overwrite resumed guidance',
    () async {
      final pending = Completer<RoutePlan>();
      harness.api.pendingRoute = pending;
      final starting = controller.start();
      await Future<void>.delayed(Duration.zero);
      await controller.pause();
      harness.api.pendingRoute = null;
      await controller.resume();
      expect(controller.session.status, NavigationStatus.active);
      final session = controller.session;
      pending.completeError(const GeoplateformeException('Old route error'));
      await starting;

      expect(controller.session, same(session));
      expect(location.activeWatchers, 1);
      expect(wakeLock.enabled, isTrue);
    },
  );

  test('a late reroute error does not overwrite resumed guidance', () async {
    await controller.start();
    final pending = Completer<RoutePlan>();
    harness.api.pendingRoute = pending;
    await triggerReroute();
    await controller.pause();
    harness.api.pendingRoute = null;
    await controller.resume();
    expect(controller.session.status, NavigationStatus.active);
    final session = controller.session;
    pending.completeError(const GeoplateformeException('Old reroute error'));
    await Future<void>.delayed(Duration.zero);

    expect(controller.session, same(session));
    expect(location.activeWatchers, 1);
    expect(wakeLock.enabled, isTrue);
  });
}
