import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/data/device_location_service.dart';
import 'package:ign_itineraires/src/features/routing/data/geoplateforme_api.dart';
import 'package:ign_itineraires/src/features/routing/data/local_route_store.dart';
import 'package:ign_itineraires/src/features/routing/data/navigation_services.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/navigation_controller.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('starts from live GPS, enables wake lock and speaks', () async {
    final harness = _Harness();

    await harness.controller.start();

    expect(harness.api.callCount, 1);
    expect(
      harness.api.lastStart,
      const Place.current(latitude: 0, longitude: 0),
    );
    expect(harness.controller.session.status, NavigationStatus.active);
    expect(harness.wakeLock.enabled, isTrue);
    expect(harness.speech.messages, contains('Partez tout droit sur RUE A'));
    await harness.dispose();
  });

  test('reroutes after three consecutive off-route fixes', () async {
    final harness = _Harness();
    await harness.controller.start();

    for (var index = 1; index <= 3; index++) {
      harness.advance(const Duration(seconds: 2));
      harness.location.add(
        _position(0.001, index * 0.002, timestamp: harness.now),
      );
      await Future<void>.delayed(Duration.zero);
    }
    await Future<void>.delayed(Duration.zero);

    expect(harness.api.callCount, 2);
    expect(harness.speech.messages, contains('Itinéraire recalculé.'));
    await harness.dispose();
  });

  test('enforces the twenty second reroute cooldown', () async {
    final harness = _Harness();
    await harness.controller.start();

    for (var cycle = 0; cycle < 2; cycle++) {
      for (var index = 1; index <= 3; index++) {
        harness.advance(const Duration(seconds: 2));
        harness.location.add(
          _position(0.001, index * 0.002, timestamp: harness.now),
        );
        await Future<void>.delayed(Duration.zero);
      }
    }
    await Future<void>.delayed(Duration.zero);

    expect(harness.api.callCount, 2);
    await harness.dispose();
  });

  test('keeps the old route when rerouting fails', () async {
    final harness = _Harness()..api.failOnCall = 2;
    await harness.controller.start();
    final originalRoute = harness.controller.session.route;

    for (var index = 1; index <= 3; index++) {
      harness.advance(const Duration(seconds: 2));
      harness.location.add(
        _position(0.001, index * 0.002, timestamp: harness.now),
      );
      await Future<void>.delayed(Duration.zero);
    }
    await Future<void>.delayed(Duration.zero);

    expect(harness.controller.session.status, NavigationStatus.active);
    expect(harness.controller.session.route, same(originalRoute));
    expect(harness.controller.session.message, contains('ancien trajet'));
    await harness.dispose();
  });

  test('ignores GPS fixes less accurate than fifty meters', () async {
    final harness = _Harness();
    await harness.controller.start();

    harness.location.add(
      NavigationPosition(
        point: const LatLng(0.001, 0.004),
        accuracyMeters: 75,
        headingDegrees: 0,
        speedMetersPerSecond: 0,
        timestamp: DateTime(2026),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(harness.api.callCount, 1);
    expect(harness.controller.session.message, contains('Précision GPS'));
    await harness.dispose();
  });

  test('pauses and resumes foreground services', () async {
    final harness = _Harness();
    await harness.controller.start();

    await harness.controller.pause();
    expect(harness.controller.session.status, NavigationStatus.paused);
    expect(harness.wakeLock.enabled, isFalse);

    await harness.controller.resume();
    expect(harness.api.callCount, 2);
    expect(harness.controller.session.status, NavigationStatus.active);
    expect(harness.wakeLock.enabled, isTrue);
    await harness.dispose();
  });

  test('persists voice preference and stops speech when muted', () async {
    final harness = _Harness();
    await harness.controller.start();

    await harness.controller.toggleVoice();

    expect(harness.controller.session.voiceEnabled, isFalse);
    expect(harness.store.voiceEnabled, isFalse);
    expect(harness.speech.stopCount, greaterThan(0));
    await harness.dispose();
  });

  test('keeps the session voice choice when persistence fails', () async {
    final harness = _Harness();
    await harness.controller.start();
    harness.store.saveVoiceError = StateError('disk full');

    await harness.controller.toggleVoice();

    expect(harness.controller.session.voiceEnabled, isFalse);
    expect(harness.controller.session.message, contains('cette session'));
    await harness.dispose();
  });

  test(
    'falls back to visual guidance when browser speech is unavailable',
    () async {
      final harness = _Harness();
      await harness.controller.start();

      harness.speech.errorHandler?.call('not-allowed');

      expect(harness.controller.session.voiceEnabled, isFalse);
      expect(harness.controller.session.message, contains('guidage visuel'));
      await harness.dispose();
    },
  );
}

class _Harness {
  _Harness()
    : api = _FakeApi(),
      location = _FakeLocation(),
      store = _FakeStore(),
      speech = _FakeSpeech(),
      wakeLock = _FakeWakeLock() {
    controller = NavigationController(
      api,
      location,
      store,
      speech,
      wakeLock,
      destination: const Place(
        label: 'Destination',
        latitude: 0,
        longitude: 0.01,
      ),
      mode: TravelMode.car,
      now: () => now,
    );
  }

  final _FakeApi api;
  final _FakeLocation location;
  final _FakeStore store;
  final _FakeSpeech speech;
  final _FakeWakeLock wakeLock;
  DateTime now = DateTime(2026);
  late final NavigationController controller;

  void advance(Duration duration) => now = now.add(duration);

  Future<void> dispose() async {
    controller.dispose();
    await location.close();
  }
}

class _FakeApi implements GeoplateformeGateway {
  int callCount = 0;
  Place? lastStart;
  int? failOnCall;

  @override
  Future<RoutePlan> calculateRoute({
    required Place start,
    required Place destination,
    required TravelMode mode,
  }) async {
    callCount++;
    if (callCount == failOnCall) {
      throw const GeoplateformeException('Recalcul indisponible.');
    }
    lastStart = start;
    return _route();
  }

  @override
  Future<List<Place>> searchPlaces(String query) async => const [];
}

class _FakeLocation implements DeviceLocationGateway {
  final StreamController<NavigationPosition> _positions =
      StreamController.broadcast();
  NavigationPosition current = _position(0, 0);

  void add(NavigationPosition position) {
    current = position;
    _positions.add(position);
  }

  Future<void> close() => _positions.close();

  @override
  Future<Place> currentPlace() async => current.asPlace;

  @override
  Future<NavigationPosition> currentPosition({
    TravelMode? navigationMode,
  }) async => current;

  @override
  Stream<NavigationPosition> watchPositions(TravelMode mode) =>
      _positions.stream;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> openAppSettings() async => true;
}

class _FakeStore implements LocalRouteStore {
  bool voiceEnabled = true;
  Object? saveVoiceError;

  @override
  Future<void> clearRecents() async {}

  @override
  Future<List<Place>> loadFavorites() async => const [];

  @override
  Future<bool> loadHistoryEnabled() async => false;

  @override
  Future<List<RecentRoute>> loadRecents() async => const [];

  @override
  Future<bool> loadVoiceEnabled() async => voiceEnabled;

  @override
  Future<void> saveFavorites(List<Place> favorites) async {}

  @override
  Future<void> saveHistoryEnabled(bool enabled) async {}

  @override
  Future<void> saveRecents(List<RecentRoute> recents) async {}

  @override
  Future<void> saveVoiceEnabled(bool enabled) async {
    if (saveVoiceError case final error?) throw error;
    voiceEnabled = enabled;
  }
}

class _FakeSpeech implements SpeechGateway {
  final List<String> messages = [];
  int stopCount = 0;
  ValueChanged<String>? errorHandler;

  @override
  void setErrorHandler(ValueChanged<String> handler) {
    errorHandler = handler;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) async {
    messages.add(text);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class _FakeWakeLock implements WakeLockGateway {
  bool enabled = false;

  @override
  Future<void> disable() async {
    enabled = false;
  }

  @override
  Future<void> enable() async {
    enabled = true;
  }
}

NavigationPosition _position(
  double latitude,
  double longitude, {
  DateTime? timestamp,
}) {
  return NavigationPosition(
    point: LatLng(latitude, longitude),
    accuracyMeters: 5,
    headingDegrees: 90,
    speedMetersPerSecond: 5,
    timestamp: timestamp ?? DateTime(2026),
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
        roadName: '',
        distanceMeters: 0,
        points: [LatLng(0, 0.01), LatLng(0, 0.01)],
      ),
    ],
  );
}
