import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:ign_itineraires/src/features/routing/data/device_location_service.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';

void main() {
  late GeolocatorPlatform original;
  late _FakeGeolocator platform;
  late DeviceLocationService service;

  setUp(() {
    original = GeolocatorPlatform.instance;
    platform = _FakeGeolocator();
    GeolocatorPlatform.instance = platform;
    service = DeviceLocationService();
  });

  tearDown(() {
    GeolocatorPlatform.instance = original;
  });

  test('reports when location services are disabled', () async {
    platform.serviceEnabled = false;

    expect(
      service.currentPosition,
      throwsA(
        isA<DeviceLocationException>().having(
          (error) => error.message,
          'message',
          contains('Activez la localisation'),
        ),
      ),
    );
  });

  test('reports denied and permanently denied permissions', () async {
    platform.permission = LocationPermission.denied;
    platform.requestedPermission = LocationPermission.denied;

    expect(service.currentPosition, throwsA(isA<DeviceLocationException>()));

    platform.permission = LocationPermission.deniedForever;

    expect(
      service.currentPosition,
      throwsA(
        isA<DeviceLocationException>().having(
          (error) => error.recovery,
          'recovery',
          LocationRecovery.openAppSettings,
        ),
      ),
    );
  });

  test('requests permission then maps the current position', () async {
    platform.permission = LocationPermission.denied;
    platform.requestedPermission = LocationPermission.whileInUse;

    final position = await service.currentPosition();

    expect(position.point.latitude, 48.8566);
    expect(position.point.longitude, 2.3522);
    expect(position.accuracyMeters, 4);
    expect(position.headingAccuracyDegrees, 3);
    expect(position.speedAccuracyMetersPerSecond, 1);
    expect(platform.requestCalls, 1);
  });

  test('requests navigation-grade accuracy for active guidance', () async {
    await service.currentPosition(navigationMode: TravelMode.car);

    expect(platform.lastSettings?.accuracy, LocationAccuracy.bestForNavigation);
    expect(platform.lastSettings?.timeLimit, const Duration(seconds: 20));
  });

  test('maps reduced operating-system location precision', () async {
    platform.accuracyStatus = LocationAccuracyStatus.reduced;

    final position = await service.currentPosition();

    expect(position.precision, LocationPrecision.reduced);
  });

  test(
    'refreshes operating-system precision while streaming positions',
    () async {
      var now = DateTime(2026);
      final streamController = StreamController<Position>();
      platform.positionStream = streamController;
      service = DeviceLocationService(
        now: () => now,
        precisionCacheDuration: const Duration(seconds: 1),
      );
      final positions = <NavigationPosition>[];
      final subscription = service
          .watchPositions(TravelMode.car)
          .listen(positions.add);

      streamController.add(_FakeGeolocator.positionAt(now));
      await _flushAsync();
      expect(positions.single.precision, LocationPrecision.precise);

      platform.accuracyStatus = LocationAccuracyStatus.reduced;
      now = now.add(const Duration(seconds: 2));
      streamController.add(_FakeGeolocator.positionAt(now));
      await _flushAsync();

      expect(positions.last.precision, LocationPrecision.reduced);
      expect(platform.locationAccuracyCalls, greaterThanOrEqualTo(2));

      await subscription.cancel();
      await streamController.close();
    },
  );

  test('uses distinct distance filters for walking and driving', () async {
    service.watchPositions(TravelMode.pedestrian).listen((_) {});
    expect(platform.lastSettings?.distanceFilter, 3);

    service.watchPositions(TravelMode.car).listen((_) {});
    expect(platform.lastSettings?.distanceFilter, 5);
  });

  test('turns platform position failures into a domain error', () async {
    platform.positionError = Exception('sensor unavailable');

    expect(
      service.currentPosition,
      throwsA(
        isA<DeviceLocationException>().having(
          (error) => error.message,
          'message',
          contains('n’a pas pu être déterminée'),
        ),
      ),
    );
  });

  test('treats browser heading accuracy as unavailable', () {
    expect(normalizedHeadingAccuracy(0, isWeb: true), 999);
    expect(normalizedHeadingAccuracy(3, isWeb: false), 3);
    expect(normalizedHeadingAccuracy(double.nan, isWeb: false), 999);
  });
}

class _FakeGeolocator extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  Object? positionError;
  int requestCalls = 0;
  int locationAccuracyCalls = 0;
  LocationSettings? lastSettings;
  LocationAccuracyStatus accuracyStatus = LocationAccuracyStatus.precise;
  StreamController<Position>? positionStream;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestCalls++;
    return requestedPermission;
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async {
    locationAccuracyCalls++;
    return accuracyStatus;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    lastSettings = locationSettings;
    final error = positionError;
    if (error != null) throw error;
    return _position;
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    lastSettings = locationSettings;
    return positionStream?.stream ?? Stream.value(_position);
  }

  static Position positionAt(DateTime timestamp) => Position(
    latitude: 48.8566,
    longitude: 2.3522,
    timestamp: timestamp,
    accuracy: 4,
    altitude: 35,
    altitudeAccuracy: 2,
    heading: 90,
    headingAccuracy: 3,
    speed: 2,
    speedAccuracy: 1,
  );

  static final Position _position = positionAt(DateTime.now());
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
