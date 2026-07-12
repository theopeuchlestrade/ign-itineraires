import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/data/device_location_service.dart';
import 'package:ign_itineraires/src/features/routing/data/geoplateforme_api.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/navigation_controller.dart';

import 'support/fakes.dart';
import 'support/test_fixtures.dart';

void main() {
  late TestAppHarness harness;
  late NavigationController controller;
  late List<int> retryAttempts;
  var now = routeStartPosition.timestamp;

  setUp(() {
    now = routeStartPosition.timestamp;
    retryAttempts = [];
    harness = TestAppHarness();
    controller = NavigationController(
      harness.api,
      harness.location,
      harness.store,
      harness.speech,
      harness.wakeLock,
      destination: parisDestination,
      mode: TravelMode.car,
      now: () => now,
      streamRetryDelay: (attempt) {
        retryAttempts.add(attempt);
        return Duration.zero;
      },
    );
  });

  tearDown(() async {
    controller.dispose();
    await harness.dispose();
  });

  test('announces arrival and releases foreground resources', () async {
    harness.location.current = navigationPosition(
      48.8569,
      2.3618,
      timestamp: now,
    );
    await controller.start();

    harness.location.emit(arrivalPosition);
    await Future<void>.delayed(Duration.zero);
    harness.location.emit(arrivalPosition);
    await Future<void>.delayed(Duration.zero);

    expect(controller.session.status, NavigationStatus.arrived);
    expect(controller.session.remainingDistanceMeters, 0);
    expect(harness.wakeLock.enabled, isFalse);
    expect(
      harness.speech.messages,
      contains('Vous êtes arrivé à destination.'),
    );
  });

  test('arrival completes even when wake-lock release fails', () async {
    harness.location.current = navigationPosition(
      48.8569,
      2.3618,
      timestamp: now,
    );
    await controller.start();
    harness.wakeLock.disableError = StateError('wake lock unavailable');

    harness.location.emit(arrivalPosition);
    await Future<void>.delayed(Duration.zero);
    harness.location.emit(arrivalPosition);
    await Future<void>.delayed(Duration.zero);

    expect(controller.session.status, NavigationStatus.arrived);
    expect(controller.session.remainingDistanceMeters, 0);
  });

  test('reports an interrupted GPS stream without losing the route', () async {
    await controller.start();

    harness.location.emitError(Exception('GPS stream stopped'));
    await Future<void>.delayed(Duration.zero);

    expect(controller.session.status, NavigationStatus.active);
    expect(controller.session.message, contains('Signal GPS interrompu'));
    expect(controller.session.route, urbanRoute);
  });

  test('backs off repeated GPS stream recovery attempts', () async {
    await controller.start();

    harness.location.emitError(Exception('first interruption'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    harness.location.emitError(Exception('second interruption'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(retryAttempts, [1, 2]);
  });

  test('fails cleanly when fresh GPS is unavailable on resume', () async {
    await controller.start();
    await controller.pause();
    harness.location.error = const DeviceLocationException(
      'Position indisponible',
    );

    await controller.resume();

    expect(controller.session.status, NavigationStatus.error);
    expect(controller.session.message, 'Position indisponible');
  });

  test('allows a new reroute attempt after a failed cooldown period', () async {
    await controller.start();
    harness.api.routeError = const GeoplateformeException('IGN indisponible');

    for (var index = 0; index < 3; index++) {
      now = now.add(const Duration(seconds: 2));
      harness.location.emit(
        navigationPosition(48.8580, 2.3571, timestamp: now),
      );
      await Future<void>.delayed(Duration.zero);
    }
    expect(harness.api.routeCalls, 2);
    expect(controller.session.status, NavigationStatus.active);

    now = now.add(const Duration(seconds: 21));
    for (var index = 0; index < 3; index++) {
      now = now.add(const Duration(seconds: 2));
      harness.location.emit(
        navigationPosition(48.8580, 2.3571, timestamp: now),
      );
      await Future<void>.delayed(Duration.zero);
    }

    expect(harness.api.routeCalls, 3);
    expect(controller.session.route, urbanRoute);
  });

  test('ignores an inaccurate fix before evaluating off-route state', () async {
    await controller.start();

    harness.location.emit(inaccuratePosition);
    await Future<void>.delayed(Duration.zero);

    expect(harness.api.routeCalls, 1);
    expect(controller.session.message, contains('Précision GPS insuffisante'));
  });

  test('manual stop releases GPS, speech and wake lock', () async {
    await controller.start();

    await controller.stop();

    expect(controller.session.status, NavigationStatus.stopped);
    expect(harness.wakeLock.enabled, isFalse);
    expect(harness.speech.stopCalls, greaterThan(0));
  });

  test('pause invalidates an initial route calculation in flight', () async {
    final pending = Completer<RoutePlan>();
    harness.api.pendingRoute = pending;

    final start = controller.start();
    await Future<void>.delayed(Duration.zero);
    expect(harness.api.routeCalls, 1);

    await controller.pause();
    pending.complete(urbanRoute);
    await start;

    expect(controller.session.status, NavigationStatus.paused);
    expect(harness.location.watchCalls, 0);
    expect(harness.wakeLock.enabled, isFalse);
  });

  test('stop invalidates an initial route calculation in flight', () async {
    final pending = Completer<RoutePlan>();
    harness.api.pendingRoute = pending;

    final start = controller.start();
    await Future<void>.delayed(Duration.zero);
    await controller.stop();
    pending.complete(urbanRoute);
    await start;

    expect(controller.session.status, NavigationStatus.stopped);
    expect(harness.location.watchCalls, 0);
    expect(harness.wakeLock.enabled, isFalse);
  });

  test('reduced precision blocks guidance before route calculation', () async {
    harness.location.current = navigationPosition(
      parisStart.latitude,
      parisStart.longitude,
      timestamp: now,
      precision: LocationPrecision.reduced,
    );

    await controller.start();

    expect(controller.session.status, NavigationStatus.error);
    expect(controller.session.signalState, NavigationSignalState.reduced);
    expect(controller.session.message, contains('approximative'));
    expect(harness.api.routeCalls, 0);
  });

  test('degraded signal needs two reliable fixes before resuming', () async {
    await controller.start();
    for (var index = 0; index < 3; index++) {
      harness.location.emit(
        navigationPosition(48.8566, 2.354, accuracyMeters: 80, timestamp: now),
      );
      await Future<void>.delayed(Duration.zero);
    }
    expect(controller.session.signalState, NavigationSignalState.degraded);

    harness.location.emit(navigationPosition(48.8566, 2.354, timestamp: now));
    await Future<void>.delayed(Duration.zero);
    expect(controller.session.signalState, NavigationSignalState.acquiring);

    harness.location.emit(navigationPosition(48.8566, 2.3541, timestamp: now));
    await Future<void>.delayed(Duration.zero);
    expect(controller.session.signalState, NavigationSignalState.reliable);
  });

  test('stale fixes do not move the last reliable position', () async {
    await controller.start();
    final reliablePoint = controller.session.position!.point;

    harness.location.emit(
      navigationPosition(
        48.858,
        2.357,
        timestamp: now.subtract(const Duration(seconds: 10)),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.session.position!.point, reliablePoint);
    expect(controller.session.message, contains('trop ancienne'));
  });

  test('stop invalidates an off-route recalculation in flight', () async {
    await controller.start();
    final pending = Completer<RoutePlan>();
    harness.api.pendingRoute = pending;

    for (var index = 0; index < 3; index++) {
      now = now.add(const Duration(seconds: 2));
      harness.location.emit(
        navigationPosition(48.8580, 2.3571, timestamp: now),
      );
      await Future<void>.delayed(Duration.zero);
    }
    expect(harness.api.routeCalls, 2);

    await controller.stop();
    pending.complete(urbanRoute);
    await Future<void>.delayed(Duration.zero);

    expect(controller.session.status, NavigationStatus.stopped);
    expect(harness.wakeLock.enabled, isFalse);
  });
}
